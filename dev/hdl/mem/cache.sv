
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps

// TODO: change the write logic to be combinatorial and create a new state machine for extmem accesses.



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
    localparam lswidth      = $clog2(line_size),
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
    genvar x, y;
    
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
        ab_we       <= rst ? 0 : bus.we && writeable;
        ab_addr     <= bus.addr;
        ab_wdata    <= bus.wdata;
    end
    
    // Tag storage.
    logic                           tag_we;
    logic[lwidth-1:0]               tag_waddr;
    logic[twidth*ways+wwidth-1:0]   tag_wdata;
    logic[lwidth-1:0]               tag_raddr;
    logic[twidth*ways+wwidth-1:0]   tag_rdata;
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
            assign rtag_valid[x]                = tag_rdata[twidth*x+alen-tgrain-1+2];
            assign rtag_dirty[x]                = tag_rdata[twidth*x+alen-tgrain-1+1];
            assign rtag_addr[x][alen-1:tgrain]  = tag_rdata[twidth*x+alen-tgrain-1:twidth*x];
        end
    endgenerate
    
    // Tag write data.
    logic                   wtag_valid[ways];
    logic                   wtag_dirty[ways];
    logic[alen-1:tgrain]    wtag_addr [ways];
    logic[wwidth-1:0]       wtag_wnext;
    assign tag_wdata[twidth*ways+wwidth-1:twidth*ways] = wtag_wnext;
    generate
        for (x = 0; x < ways; x = x + 1) begin
            assign tag_wdata[twidth*x+alen-tgrain-1+2]        = wtag_valid[x];
            assign tag_wdata[twidth*x+alen-tgrain-1+1]        = wtag_dirty[x];
            assign tag_wdata[twidth*x+alen-tgrain-1:twidth*x] = wtag_addr[x][alen-1:tgrain];
        end
    endgenerate
    
    // Tag decoder.
    logic[ways-1:0]     masked_tag_valid;
    logic[ways-1:0]     masked_tag_dirty;
    logic               tag_valid;
    logic               tag_dirty;
    logic[wwidth-1:0]   tag_way;
    generate
        for (x = 0; x < ways; x = x + 1) begin
            assign masked_tag_valid[x] = rtag_valid[x] && (rtag_addr[x][alen-1:tgrain] == ab_addr[alen-1:tgrain]);
            assign masked_tag_dirty[x] = masked_tag_valid[x] && rtag_dirty[x];
        end
    endgenerate
    always @(*) begin
        integer i;
        tag_way = 0;
        for (i = 0; i < ways; i = i + 1) begin
            tag_way |= masked_tag_valid[i] ? i : 0;
        end
    end
    assign tag_valid = masked_tag_valid != 0;
    assign tag_dirty = masked_tag_dirty != 0;
    
    // Tag encoder.
    logic                   etag_way;
    logic                   etag_valid;
    logic                   etag_dirty;
    logic[alen-tgrain-1:0]  etag_addr;
    generate
        for (x = 0; x < ways; x = x + 1) begin
            assign wtag_valid[x] = (etag_way == x) ? etag_valid : rtag_valid[x];
            assign wtag_dirty[x] = (etag_way == x) ? etag_dirty : rtag_dirty[x];
            assign wtag_addr [x] = (etag_way == x) ? etag_addr  : rtag_addr [x];
        end
    endgenerate
    
    
    // Data storage.
    logic[4*ways-1:0]           cache_we;
    logic[lwidth+lswidth-1:0]   cache_waddr;
    logic[32*ways-1:0]          cache_wdata;
    logic[lwidth+lswidth-1:0]   cache_raddr;
    logic[32*ways-1:0]          cache_rdata;
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
    
    // Write data.
    logic[3:0]          wcache_we;
    logic[wwidth-1:0]   wcache_way;
    logic[31:0]         wcache_wdata;
    generate
        for (x = 0; x < ways; x = x + 1) begin
            assign cache_wdata[32*x+31:32*x] = wcache_wdata;
            assign cache_we[x*4+3:x*4]       = (wcache_way == x) && wcache_we[x] ? 4'b1111 : 4'b0000;
        end
    endgenerate
    
    
    // Copying from extmem to cache.
    logic xm_to_cache;
    // Copying from cache to extmem.
    logic cache_to_xm;
    
    // Address being synced with extmem.
    logic[alen-1:2]             xm_addr;
    // Address being synced with cache.
    logic[lwidth+lswidth-1:0]   cm_addr;
    // Cache way being synced with extmem.
    logic[wwidth-1:0]           xm_way;
    
    // Next address in sequential extmem access.
    logic[alen-1:2]             xm_next_addr;
    assign xm_next_addr[alen-1:agrain]              = xm_addr[alen-1:agrain];
    assign xm_next_addr[agrain-1:2]                 = xm_addr[agrain-1:2] + 1;
    // Next address in sequential cachemem access.
    logic[lwidth+lswidth-1:0]   cm_next_addr;
    assign cm_next_addr[lwidth+lswidth-1:lswidth]   = cm_addr[lwidth+lswidth-1:lswidth];
    assign cm_next_addr[lswidth-1:0]                = cm_addr[lswidth-1:0] + 1;
    // Initial extmem address for extmem to cache copy.
    logic[alen-1:2]             xm_init_raddr;
    assign xm_init_raddr[alen-1:agrain]             = bus.addr[alen-1:agrain];
    assign xm_init_raddr[agrain-1:2]                = 0;
    // Initial extmem address for cache to extmem copy.
    logic[alen-1:2]             xm_init_waddr;
    assign xm_init_waddr[alen-1:agrain]             = ab_addr[alen-1:agrain];
    assign xm_init_waddr[agrain-1:2]                = 0;
    // Initial cache address for cache to extmem copy.
    logic[lwidth+lswidth-1:0]   cm_init_raddr;
    assign cm_init_raddr[lwidth+lswidth-1:lswidth]  = bus.addr[alen-1:agrain];
    assign cm_init_raddr[lswidth-1:0]               = 0;
    // Initial cache address for extmem to cache copy.
    logic[lwidth+lswidth-1:0]   cm_init_waddr;
    assign cm_init_waddr[lwidth+lswidth-1:lswidth]  = ab_addr[alen-1:agrain];
    assign cm_init_waddr[lswidth-1:0]               = 0;
    
    // Cache state machine.
    always @(posedge clk) begin
        if (xm_to_cache) begin
            // Reading a cache line.
            xm_to_cache <= xm_addr[agrain-1:2] != 0;
            cache_to_xm <= 0;
            xm_addr     <= (xm_addr[agrain-1:2] != 0) ? xm_next_addr : xm_init_raddr;
            cm_addr     <= cm_next_addr;
        end else if (cache_to_xm) begin
            // Flushing a dirty cache line.
            xm_to_cache <= 0;
            cache_to_xm <= cm_addr[lswidth-1:0] != 0;
            xm_addr     <= xm_next_addr;
            cm_addr     <= (cm_addr[lswidth-1:0] != 0) ? cm_next_addr : cm_init_raddr;
        end else if ((ab_re || ab_we) && !tag_valid) begin
            // Non-resident access.
            xm_to_cache <= !rtag_dirty[rtag_wnext];
            cache_to_xm <= rtag_dirty[rtag_wnext];
            xm_way      <= rtag_wnext;
            xm_addr     <= rtag_dirty[rtag_wnext] ? xm_init_waddr : xm_next_addr;
            cm_addr     <= rtag_dirty[rtag_wnext] ? cm_next_addr  : cm_init_waddr;
        end else begin
            // Cache is idle.
            xm_to_cache <= 0;
            cache_to_xm <= 0;
            xm_way      <= 'bx;
            xm_addr     <= xm_init_raddr;
            cm_addr     <= cm_init_raddr;
        end
    end
    
    // Cache RAM write access logic.
    always @(*) begin
        if (xm_to_cache) begin
            // Reading a cache line.
            xm_bus.re                   = xm_addr[agrain-1:2] != 0;
            xm_bus.we                   = 0;
            xm_bus.addr                 = xm_addr;
            xm_bus.wdata                = 'bx;
            // Writing to cache memory.
            wcache_we                   = 4'b1111;
            wcache_way                  = xm_way;
            wcache_wdata                = xm_bus.rdata;
            cache_waddr                 = cm_addr;
            // Tag was already written.
            tag_we                      = 0;
            tag_waddr                   = 'bx;
            etag_way                    = 'bx;
            wtag_wnext                  = 'bx;
            etag_valid                  = 'bx;
            etag_dirty                  = 'bx;
            etag_addr                   = 'bx;
        end else if (cache_to_xm) begin
            // Flushing a dirty cache line.
            xm_bus.re                   = 0;
            xm_bus.we                   = 4'b1111;
            xm_bus.addr                 = xm_addr;
            xm_bus.wdata                = rcache_rdata[xm_way];
            // Cache write is idle.
            wcache_we                   = 0;
            wcache_way                  = 'bx;
            wcache_wdata                = 'bx;
            cache_waddr                 = 'bx;
            // Tag was already written.
            tag_we                      = 0;
            tag_waddr                   = 'bx;
            etag_way                    = 'bx;
            wtag_wnext                  = 'bx;
            etag_valid                  = 'bx;
            etag_dirty                  = 'bx;
            etag_addr                   = 'bx;
        end else if (ab_we && tag_valid) begin
            // Resident write access.
            // Extmem is idle.
            xm_bus.re                   = 0;
            xm_bus.we                   = 0;
            xm_bus.addr                 = 'bx;
            xm_bus.wdata                = 'bx;
            // Writing to cache memory.
            wcache_we                   = 4'b1111;
            wcache_way                  = tag_way;
            wcache_wdata                = ab_wdata;
            cache_waddr                 = ab_addr[tgrain-1:2];
            // Marking tag as dirty.
            tag_we                      = 1;
            tag_waddr                   = ab_addr[agrain+lwidth-1:agrain];
            etag_way                    = tag_way;
            wtag_wnext                  = rtag_wnext;
            etag_valid                  = 1;
            etag_dirty                  = 1;
            etag_addr                   = ab_addr[alen-1:tgrain];
        end else if ((ab_re || ab_we) && !tag_valid && rtag_dirty[rtag_wnext]) begin
            // Non-resident access; dirty tag needs flushing.
            // Extmem is idle.
            xm_bus.re                   = 0;
            xm_bus.we                   = 0;
            xm_bus.addr                 = 'bx;
            xm_bus.wdata                = 'bx;
            // Cache memory is idle.
            wcache_we                   = 0;
            wcache_way                  = 'bx;
            wcache_wdata                = 'bx;
            cache_waddr                 = 'bx;
            // Marking tag as clean.
            tag_we                      = 1;
            tag_waddr                   = ab_addr[agrain+lwidth-1:agrain];
            etag_way                    = rtag_wnext;
            wtag_wnext                  = rtag_wnext;
            etag_valid                  = 1;
            etag_dirty                  = 0;
            etag_addr                   = rtag_addr[rtag_wnext];
        end else if ((ab_re || ab_we) && !tag_valid && !rtag_dirty[rtag_wnext]) begin
            // Non-resident access; clean tag evicted.
            // Initiate extmem read.
            xm_bus.re                   = 1;
            xm_bus.we                   = 0;
            xm_bus.addr                 = xm_init_raddr;
            xm_bus.wdata                = 'bx;
            // Cache memory is idle.
            wcache_we                   = 0;
            wcache_way                  = 'bx;
            wcache_wdata                = 'bx;
            cache_waddr                 = 'bx;
            // Create new cache tag.
            tag_we                      = 1;
            tag_waddr                   = ab_addr[agrain+lwidth-1:agrain];
            etag_way                    = rtag_wnext;
            wtag_wnext                  = rtag_wnext + 1;
            etag_valid                  = 1;
            etag_dirty                  = 0;
            etag_addr                   = ab_addr[alen-1:tgrain];
        end else begin
            // Cache is idle.
            // Extmem is idle.
            xm_bus.re                   = 0;
            xm_bus.we                   = 0;
            xm_bus.addr                 = 'bx;
            xm_bus.wdata                = 'bx;
            // Cache memory is idle.
            wcache_we                   = 0;
            wcache_way                  = 'bx;
            wcache_wdata                = 'bx;
            cache_waddr                 = 'bx;
            // Tag memory is idle.
            tag_we                      = 0;
            tag_waddr                   = 'bx;
            etag_way                    = 'bx;
            wtag_wnext                  = 'bx;
            etag_valid                  = 'bx;
            etag_dirty                  = 'bx;
            etag_addr                   = 'bx;
        end
    end
    
    // Cache RAM read access logic.
    always @(*) begin
        if (xm_bus.re || xm_bus.we) begin
            // Accessing extmem, cache is busy.
            bus.ready = 0;
            bus.rdata = 'bx;
            // Tag read prepared an access.
            tag_raddr = bus.addr[agrain+lwidth-1:agrain];
        end else if ((ab_re || ab_we) && tag_valid) begin
            // Resident access.
            bus.ready = !cache_to_xm && !xm_to_cache;
            bus.rdata = rcache_rdata[tag_way];
            // Tag read prepared next access.
            tag_raddr = bus.addr[agrain+lwidth-1:agrain];
        end else if ((ab_re || ab_we) && !tag_valid) begin
            // Non-resident access.
            bus.ready = 0;
            bus.rdata = 'bx;
            // Tag read prepared next access.
            tag_raddr = bus.addr[agrain+lwidth-1:agrain];
        end else begin
            // Not accessing.
            bus.ready = 1;
            bus.rdata = 'bx;
            // Tag read prepared an access.
            tag_raddr = bus.addr[agrain+lwidth-1:agrain];
        end
        if (cache_to_xm && cm_addr[lswidth-1:0] != 0) begin
            // Copying from cache to extmem.
            cache_raddr = cm_addr;
        end else if ((ab_re || ab_we) && !tag_valid && rtag_dirty[rtag_wnext]) begin
            // Non-resident access; dirty tag needs flushing.
            cache_raddr = cm_addr;
        end else begin
            // Reading from cache.
            cache_raddr = bus.addr[tgrain-1:2];
        end
    end
endmodule
