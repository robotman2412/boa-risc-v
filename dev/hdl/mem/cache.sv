
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

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
    // If flush_w is 0, writes are discarded.
    input  logic            flush_r,
    // Flush cached writes and mark as clean.
    input  logic            flush_w,
    
    // Precise invalidation enable.
    input  logic            pi_en,
    // Precise invalidation address.
    input  logic[alen-1:2]  pi_addr,
    
    // Currently flushing the cache.
    output logic            flushing_r,
    // Currently flushing writes.
    output logic            flushing_w,
    // Stall any access requests.
    input  logic            stall,
    
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
    logic           ab_stall;
    always @(posedge clk) begin
        ab_re       <= rst               ? 0 : bus.re;
        ab_we       <= rst || !writeable ? 0 : bus.we;
        ab_addr     <= bus.addr;
        ab_wdata    <= bus.wdata;
        ab_stall    <= stall;
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
    logic[alen-1:tgrain]    dtag_addr;
    logic[ways-1:0]         masked_tag_valid;
    logic[ways-1:0]         masked_tag_dirty;
    logic                   tag_valid;
    logic                   tag_dirty;
    logic[wwidth-1:0]       tag_way;
    generate
        for (x = 0; x < ways; x = x + 1) begin
            assign masked_tag_valid[x] = rtag_valid[x] && (rtag_addr[x][alen-1:tgrain] == dtag_addr[alen-1:tgrain]);
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
    assign dtag_addr = (fl_r || fl_w) && fl_pi ? fl_addr[alen-1:tgrain] : ab_addr[alen-1:tgrain];
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
            assign cache_we[x*4+3:x*4]       = (wcache_way == x) ? wcache_we : 4'b0000;
        end
    endgenerate
    
    
    // Flushing cached reads.
    logic               fl_r;
    // Flushing cached writes.
    logic               fl_w;
    // Doing a precise invalidation.
    logic               fl_pi;
    // Line to flush next.
    logic[lwidth-1:0]   fl_line;
    // Way to flush next.
    logic[wwidth-1:0]   fl_way;
    // Precise invalidation address.
    logic[alen-1:2]     fl_addr;
    // This is the last invalidation operation.
    wire                fl_end = fl_pi || (fl_way == ways-1 && fl_line == lines-1);
    
    // Copying from extmem to cache.
    logic xm_to_cache;
    // Copying from cache to extmem.
    logic cache_to_xm;
    // Was copying from cache to extmem.
    logic pcache_to_xm;
    
    // Address being synced with extmem.
    logic[alen-1:2]             xm_addr;
    // Address being synced with cache.
    logic[lwidth+lswidth-1:0]   cm_addr;
    // Previous extmem address.
    logic[alen-1:2]             xm_paddr;
    // Previous cache address.
    logic[lwidth+lswidth-1:0]   cm_paddr;
    // Cache way being synced with extmem.
    logic[wwidth-1:0]           xm_way;
    // Previous extmem write data.
    logic[31:0]                 xm_pwdata;
    
    // Next address in sequential extmem access.
    logic[alen-1:2]             xm_next_addr;
    assign xm_next_addr[alen-1:agrain]              = xm_bus.addr[alen-1:agrain];
    assign xm_next_addr[agrain-1:2]                 = xm_addr[agrain-1:2] + 1;
    // Next address in sequential cachemem access.
    logic[lwidth+lswidth-1:0]   cm_next_addr;
    assign cm_next_addr[lwidth+lswidth-1:lswidth]   = cache_raddr[lwidth+lswidth-1:lswidth];
    assign cm_next_addr[lswidth-1:0]                = cm_addr[lswidth-1:0] + 1;
    // Initial extmem address for extmem to cache copy.
    logic[alen-1:2]             xm_init_raddr;
    assign xm_init_raddr[alen-1:agrain]             = bus.addr[alen-1:agrain];
    assign xm_init_raddr[agrain-1:2]                = 0;
    // Initial extmem address for cache to extmem copy.
    logic[alen-1:2]             xm_init_waddr;
    assign xm_init_waddr[alen-1:tgrain]             = rtag_addr[rtag_wnext][alen-1:tgrain];
    assign xm_init_waddr[tgrain-1:lswidth+2]        = ab_addr[tgrain-1:lswidth+2];
    assign xm_init_waddr[lswidth+1:2]               = 0;
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
        pcache_to_xm <= cache_to_xm || (pcache_to_xm && !xm_bus.ready);
        if (rst && (!fl_r || fl_w || fl_pi)) begin
            // Invalidate the entire cache after a reset.
            fl_r    <= 1;
            fl_w    <= 0;
            fl_pi   <= 0;
            fl_line <= 'bx;
            fl_way  <= 'bx;
            fl_addr <= 'bx;
        end else if (fl_r || fl_w) begin
            // Performing an invalidation.
        end else if (pi_en && (flush_r || flush_w)) begin
            // Start a precise invalidation.
            fl_r    <= flush_r;
            fl_w    <= flush_w;
            fl_pi   <= 1;
            fl_line <= 'bx;
            fl_way  <= 'bx;
            fl_addr <= pi_addr;
        end else if (flush_r || flush_w && writeable) begin
            // Start an imprecise invalidation.
            fl_r    <= flush_r;
            fl_w    <= flush_w;
            fl_pi   <= 0;
            fl_line <= 0;
            fl_way  <= 0;
            fl_addr <= 'bx;
        end
        if (!xm_bus.ready && xm_to_cache) begin
            // Waiting on extmem read.
        end else if (!xm_bus.ready && (cache_to_xm || (pcache_to_xm && !xm_bus.ready))) begin
            // Waiting on extmem write.
        end else if (xm_to_cache) begin
            // Reading a cache line.
            xm_to_cache <= xm_addr[agrain-1:2] != 0;
            cache_to_xm <= 0;
            xm_addr     <= (xm_addr[agrain-1:2] != 0) ? xm_next_addr : xm_init_raddr;
            cm_addr     <= cm_next_addr;
            xm_paddr    <= xm_bus.addr;
            cm_paddr    <= cache_raddr;
        end else if (writeable && cache_to_xm) begin
            // Flushing a dirty cache line.
            xm_to_cache <= 0;
            cache_to_xm <= cm_addr[lswidth-1:0] != 0;
            xm_addr     <= xm_next_addr;
            cm_addr     <= (cm_addr[lswidth-1:0] != 0) ? cm_next_addr : cm_init_raddr;
            xm_paddr    <= xm_bus.addr;
            cm_paddr    <= cache_raddr;
            xm_pwdata   <= xm_bus.wdata;
        end else if (fl_r || fl_w) begin
            // Cache invalidation.
            if (fl_end) begin
                fl_r    <= 0;
                fl_w    <= 0;
            end
            if (fl_way == ways-1) begin
                fl_line <= fl_line + 1;
            end
            fl_way <= fl_way + 1;
            if (fl_w && (fl_pi ? rtag_dirty[tag_way] : rtag_dirty[fl_way])) begin
                xm_to_cache <= 0;
                cache_to_xm <= 1;
                xm_way      <= fl_pi ? tag_way : fl_way;
                xm_addr     <= xm_init_waddr;
                cm_addr     <= cm_next_addr;
            end
            xm_paddr    <= xm_bus.addr;
            cm_paddr    <= cache_raddr;
        end else if ((ab_re || ab_we != 0) && !tag_valid && !ab_stall) begin
            // Non-resident access.
            xm_to_cache <= !rtag_dirty[rtag_wnext];
            cache_to_xm <= rtag_dirty[rtag_wnext];
            xm_way      <= rtag_wnext;
            xm_addr     <= rtag_dirty[rtag_wnext] ? xm_init_waddr : xm_next_addr;
            cm_addr     <= rtag_dirty[rtag_wnext] ? cm_next_addr  : cm_init_waddr;
            xm_paddr    <= xm_bus.addr;
            cm_paddr    <= cache_raddr;
        end else begin
            // Cache is idle.
            xm_to_cache <= 0;
            cache_to_xm <= 0;
            xm_way      <= 'bx;
            xm_addr     <= xm_init_raddr;
            cm_addr     <= cm_init_raddr;
            xm_paddr    <= xm_bus.addr;
            cm_paddr    <= cache_raddr;
        end
    end
    
    // Cache RAM write access logic.
    always @(*) begin
        // Default state:
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
        if (xm_to_cache) begin
            // Reading a cache line.
            xm_bus.re                   = !xm_bus.ready || (xm_addr[agrain-1:2] != 0);
            xm_bus.addr                 = xm_bus.ready ? xm_addr : xm_paddr;
            // Writing to cache memory.
            wcache_we                   = xm_bus.ready ? 4'b1111 : 4'b0000;
            wcache_way                  = xm_way;
            wcache_wdata                = xm_bus.rdata;
            cache_waddr                 = cm_addr;
        end else if (cache_to_xm || (!xm_bus.ready && pcache_to_xm)) begin
            // Flushing a dirty cache line.
            xm_bus.we                   = 4'b1111;
            xm_bus.addr                 = xm_bus.ready ? xm_addr : xm_paddr;
            xm_bus.wdata                = xm_bus.ready ? rcache_rdata[xm_way] : xm_pwdata;
        end else if (fl_r || fl_w) begin
            // Cache invalidation.
            // Change tag flags.
            tag_we                      = fl_pi ? tag_valid : 1;
            tag_waddr                   = fl_pi ? fl_addr[agrain+lwidth-1:agrain] : fl_line;
            etag_way                    = fl_pi ? tag_way : fl_way;
            wtag_wnext                  = rtag_wnext;
            etag_valid                  = !fl_r;
            etag_dirty                  = 0;
            etag_addr                   = rtag_addr[etag_way];
        end else if (ab_we != 0 && tag_valid) begin
            // Resident write access.
            // Writing to cache memory.
            wcache_we                   = ab_we;
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
        end else if ((ab_re || ab_we != 0) && !tag_valid && rtag_dirty[rtag_wnext]) begin
            // Non-resident access; dirty tag needs flushing.
            // Marking tag as clean.
            tag_we                      = 1;
            tag_waddr                   = ab_addr[agrain+lwidth-1:agrain];
            etag_way                    = rtag_wnext;
            wtag_wnext                  = rtag_wnext;
            etag_valid                  = 1;
            etag_dirty                  = 0;
            etag_addr                   = rtag_addr[etag_way];
        end else if ((ab_re || ab_we != 0) && !tag_valid && !rtag_dirty[rtag_wnext]) begin
            // Non-resident access; clean tag evicted.
            // Initiate extmem read.
            xm_bus.re                   = 1;
            xm_bus.addr                 = xm_init_raddr;
            // Create new cache tag.
            tag_we                      = 1;
            tag_waddr                   = ab_addr[agrain+lwidth-1:agrain];
            etag_way                    = rtag_wnext;
            wtag_wnext                  = rtag_wnext + 1;
            etag_valid                  = 1;
            etag_dirty                  = 0;
            etag_addr                   = ab_addr[alen-1:tgrain];
        end
    end
    
    // Cache RAM read access logic.
    assign flushing_r = fl_r;
    assign flushing_w = fl_w;
    always @(*) begin
        if (fl_r || fl_w) begin
            // Cache invalidation.
            bus.ready = !ab_re && ab_we == 0;
            bus.rdata = 'bx;
            if (fl_end) begin
                // Tag read prepared for an access.
                tag_raddr = bus.addr[agrain+lwidth-1:agrain];
            end else begin
                // Tag read prepared for another invalidation.
                tag_raddr = (fl_way == ways-1) + fl_line;
            end
        end else if (xm_to_cache || cache_to_xm) begin
            // Accessing extmem, cache is busy.
            bus.ready = !ab_re && ab_we == 0;
            bus.rdata = 'bx;
            // Tag read prepared an access.
            tag_raddr = bus.addr[agrain+lwidth-1:agrain];
        end else if ((ab_re || ab_we != 0) && tag_valid) begin
            // Resident access.
            bus.ready = !ab_stall;
            bus.rdata = rcache_rdata[tag_way];
            // Tag read prepared for next access.
            tag_raddr = bus.addr[agrain+lwidth-1:agrain];
        end else if ((ab_re || ab_we != 0) && !tag_valid) begin
            // Non-resident access.
            bus.ready = 0;
            bus.rdata = 'bx;
            // Tag read prepared for next access.
            tag_raddr = bus.addr[agrain+lwidth-1:agrain];
        end else begin
            // Not accessing.
            bus.ready = 1;
            bus.rdata = 'bx;
            // Tag read prepared for an access.
            tag_raddr = bus.addr[agrain+lwidth-1:agrain];
        end
        if (pcache_to_xm && !xm_bus.ready) begin
            // Waiting for extmem.
            cache_raddr = cm_paddr;
        end else if (cache_to_xm && cm_addr[lswidth-1:0] != 0) begin
            // Copying from cache to extmem.
            cache_raddr = xm_bus.ready ? cm_addr : cm_paddr;
        end else if (fl_w && rtag_dirty[fl_pi ? tag_way : fl_way]) begin
            // Cache invalidation; dirty tag needs flushing.
            cache_raddr = fl_pi ? fl_addr : fl_line;
        end else if ((ab_re || ab_we != 0) && !tag_valid && rtag_dirty[rtag_wnext]) begin
            // Non-resident access; dirty tag needs flushing.
            cache_raddr = cm_addr;
        end else begin
            // Reading from cache.
            cache_raddr = bus.addr[tgrain-1:2];
        end
    end
endmodule
