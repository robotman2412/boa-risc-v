
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Configurable cache intended for larger memories with longer access times.
// Does not support coherency; it should not be used redundantly with other caches.
module boa_cache#(
    // Number of address bits.
    parameter alen          = 24,
    // Size of a cache line in 4-byte words.
    parameter line_size     = 16,
    // Number of cache lines per way.
    parameter lines         = 32,
    // Number of cache ways.
    parameter ways          = 2,
    
    // Whether this cache supports write access.
    parameter writeable     = 1,
    
    // Granularity of addresses.
    localparam agrain       = $clog2(line_size)+2,
    // Granularity of addresses in a cache entry.
    localparam tgrain       = agrain + $clog2(lines),
    // Number of bits required to address a way.
    localparam wwidth       = $clog2(ways),
    // Number of bits required to address a line.
    localparam lwidth       = $clog2(lines),
    // Number of bits required to store a cache tag.
    localparam twidth       = alen-tgrain+2
)(
    // CPU clock.
    input  logic            clk,
    // Synchronous reset.
    input  logic            rst,
    
    // Flush the entire cache.
    input  logic            flush,
    // Flush cached writes and mark as clean.
    input  logic            w_flush,
    // Perform an acquire fence.
    input  logic            fence_aq,
    // Perform a release fence.
    input  logic            fence_rl,
    
    // Prefetch hint enable.
    input  logic            pf_en,
    // Prefetch hint address.
    input  logic[alen-1:2]  pf_addr,
    
    // Cache interface.
    boa_mem_bus.MEM         bus,
    // External memory interface.
    boa_mem_bus.CPU         xm_bus
);
    genvar x;
    
    // A tag has an address to map to external memory and a few flags.
    // The address truncates the bottom `tgrain` bits from an `alen`-bit address.
    // The valid flag indicates the cache entry contains valid data.
    // The dirty flag indicates the cache entry was written to but not flushed.
    // In addition to a number of ways, a cache line also contains the index of the "oldest" way.
    // This index is incremented every time a line is fetched from extmem and used as an index for which way to evict.
    
    // Tag storage.
    logic                   tag_we;
    logic[lwidth-1:0]       tag_addr;
    logic[twidth*ways-1:0]  tag_wdata;
    logic[twidth*ways-1:0]  tag_rdata;
    raw_block_ram#($clog2(lines), 1, twidth*ways+wwidth) tag_ram(
        clk, tag_we, tag_addr, tag_wdata, tag_rdata
    );
    
    // Tag read data.
    logic                   rtag_valid[ways];
    logic                   rtag_dirty[ways];
    logic[alen-tgrain-1:0]  rtag_addr [ways];
    logic[wwidth-1:0]       rtag_wnext;
    generate
        for (x = 0; x < ways; x = x + 1) begin
            assign rtag_valid[x] = tag_rdata[twidth*x+alen-tgrain+wwidth+1];
            assign rtag_dirty[x] = tag_rdata[twidth*x+alen-tgrain+wwidth];
            assign rtag_addr[x]  = tag_rdata[twidth*x+alen-tgrain-1:twidth*x];
        end
        assign rtag_wnext = tag_rdata[twidth*ways+wwidth-1:twidth*ways];
    endgenerate
    
    // Tag write data.
    logic                   wtag_valid[ways];
    logic                   wtag_dirty[ways];
    logic[alen-tgrain-1:0]  wtag_addr [ways];
    logic[wwidth-1:0]       wtag_wnext;
    assign tag_wdata[twidth*ways+wwidth-1:twidth*ways] = wtag_wnext;
    generate
        for (x = 0; x < ways; x = x + 1) begin
            assign tag_wdata[twidth*x+alen-tgrain+wwidth+1]     = wtag_valid[x];
            assign tag_wdata[twidth*x+alen-tgrain+wwidth]       = wtag_dirty[x];
            assign tag_wdata[twidth*x+alen-tgrain-1:twidth*x]   = wtag_addr[x] ;
        end
    endgenerate
    
    
    // Data storage.
    raw_block_ram#($clog2(lines), line_size*4*ways) data_ram();
    
    
    // Selected cache line.
    logic[lwidth-1:0]   ce_line;
    // Currently updating a cache entry.
    logic               ce_we;
    // Selected cache way to update.
    logic[wwidth-1:0]   ce_wway;
    // New valid bit.
    logic               ce_wvalid;
    // New dirty bit.
    logic               ce_wdirty;
    // New address.
    logic               ce_waddr;
    // Cache write data logic.
    assign wtag_wnext = rtag_wnext+1;
    generate
        for (x = 0; x < ways; x = x + 1) begin
            assign wtag_valid[x] = (rtag_wnext == x) ?  : rtag_valid[x];
        end
    endgenerate
    
    
    // Currently reading from extmem.
    logic               xm_read;
    // Currently writing to extmem.
    logic               xm_write;
    // Current memory access address.
    logic[alen-1:2]     xm_addr;
    // Cache way associated.
    logic[wwidth-1:0]   xm_way;
    
    
    // Access buffer.
    logic               ab_re;
    logic[3:0]          ab_we;
    logic[alen-1:2]     ab_addr;
    logic[31:0]         ab_wdata;
    always @(posedge clk) begin
        ab_re       <= !rst && bus.re;
        ab_we       <= !rst ? bus.we : 0;
        ab_addr     <= bus.addr;
        ab_wdata    <= bus.wdata;
    end
    
    
    // Control logic.
    
endmodule
