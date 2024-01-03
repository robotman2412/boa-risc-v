
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
    
    // Number of bits required to address a 4-byte word in a line.
    localparam lswidth      = $clog2(line_size);
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
    
    // Access buffer.
    logic           ab_re;
    logic[3:0]      ab_we;
    logic[alen-1:2] ab_addr;
    logic[31:0]     ab_wdata;
    always @(posedge clk) begin
        ab_re       <= rst ? 0 : bus.re;
        ab_we       <= rst ? 0 : bus.we;
        ab_addr     <= bus.addr;
        ab_wdata    <= bus.wdata;
    end
    
    // Tag storage.
    logic                   tag_we;
    logic[lwidth-1:0]       tag_waddr;
    logic[twidth*ways-1:0]  tag_wdata;
    logic[lwidth-1:0]       tag_raddr;
    logic[twidth*ways-1:0]  tag_rdata;
    raw_sdp_block_ram#(lwidth, 1, twidth*ways+wwidth, "", 1) tag_ram(
        clk, tag_we, tag_waddr, tag_wdata, tag_raddr, tag_rdata
    );
    
    // Tag read data.
    logic                   rtag_valid[ways];
    logic                   rtag_dirty[ways];
    logic[alen-1:tgrain]    rtag_addr [ways];
    logic[wwidth-1:0]       rtag_wnext;
    assign rtag_wnext = tag_rdata[twidth*ways+wwidth-1:twidth*ways];
    generate
        for (x = 0; x < ways; x = x + 1) begin
            assign rtag_valid[x]                = tag_rdata[twidth*x+alen-tgrain+wwidth+1];
            assign rtag_dirty[x]                = tag_rdata[twidth*x+alen-tgrain+wwidth];
            assign rtag_addr[x][alen-1:tgrain]  = tag_rdata[twidth*x+alen-tgrain-1:twidth*x];
        end
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
            assign tag_wdata[twidth*x+alen-tgrain-1:twidth*x]   = wtag_addr[x][alen-1:tgrain];
        end
    endgenerate
    
    // Tag decoder.
    logic               tag_found;
    logic[ways-1:0]     tag_fmask;
    logic               masked_tag_valid;
    logic               masked_tag_dirty;
    logic               tag_valid;
    logic               tag_dirty;
    logic[wwidth-1:0]   tag_way;
    generate
        for (x = 0; x < ways; x = x + 1) begin
            assign tag_fmask[x]     = rtag_addr[x][alen-1:tgrain] == ab_addr[alen-1:tgrain];
            assign masked_tag_valid = tag_fmask[x] && rtag_valid[x];
            assign masked_tag_dirty = tag_fmask[x] && rtag_dirty[x];
        end
    endgenerate
    always @(*) begin
        integer i;
        tag_way   = 0;
        tag_valid = 0;
        tag_dirty = 0;
        for (i = 0; i < ways; i = i + 1) begin
            tag_way   |= tag_fmask[i] ? i : 0;
            tag_valid |= masked_tag_valid;
            tag_dirty |= masked_tag_dirty;
        end
    end
    
    
    // Data storage.
    logic               cache_we;
    logic[lwidth-1:0]   cache_waddr;
    logic[32*ways-1:0]  cache_wdata;
    logic[lwidth-1:0]   cache_raddr;
    logic[32*ways-1:0]  cache_rdata;
    raw_sdp_block_ram#(lwidth+lswidth, 4*ways, 8, "", 1) cache_ram(
        clk, cache_we, cache_waddr, cache_wdata, cache_raddr, cache_rdata
    );
    
    // Read data.
    logic[31:0] rcache_rdata[ways];
    generate
        for (x = 0; x < ways; x = x + 1) begin
            assign rcache_rdata[x] = cache_rdata[32*x+31:32*x];
        end
    endgenerate
    
    
    // Cache state machine.
    always @(posedge clk) begin
    end
    
    // Cache RAM access logic.
    always @(*) begin
        if (xm_bus.re || xm_bus.we) begin
            // Accessing extmem, cache is busy.
            bus.ready = 0;
            bus.rdata = 'bx;
        end else if ((ab_re || ab_we) && tag_valid) begin
            // Resident access.
            bus.ready = 1;
            bus.rdata = rcache_rdata[tag_way];
        end else if ((ab_re || ab_we) && !tag_valid) begin
            // Non-resident access.
            bus.ready = 0;
            bus.rdata = 'bx;
        end else begin
            // Not accessing.
            bus.ready = 1;
            bus.rdata = 'bx;
        end
    end
endmodule
