
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`include "boa_defines.svh"



// Boa atomic memory operation interface.
// Latency: 1 clock cycle.
interface boa_amo_bus#(
    // Address bus size, at least 8.
    parameter alen = 32
);
    // CPU -> MEM: Request reservation for atomic memory operation.
    logic           req;
    // CPU -> MEM: Reservation address.
    logic[alen-1:2] addr;
    // MEM -> CPU: Reservation valid.
    logic           valid;
    
    // Directions from CPU perspective.
    modport CPU (output req, addr, input valid);
    // Directions from MEM perspective.
    modport MEM (output valid, input req, addr);
endinterface

// Boa atomic memory operation terminator.
module boa_amo_term(
    boa_amo_bus.MEM mem
);
    assign mem.valid = mem.req;
endmodule


// Single reservation boa atomic memory operation controller.
module boa_amo_ctl_1#(
    // Address bus size, at least 8.
    parameter alen = 32,
    // Number of CPUs, 2+.
    parameter cpus      = 2,
    // Number of memory buses to watch, 2+.
    parameter watchers  = 2,
    // Arbitration strategy.
    parameter arbiter   = `BOA_ARBITER_RR
)(
    // CPU clock.
    input  logic        clk,
    // Synchronous reset.
    input  logic        rst,
    
    // CPU AMO ports.
    boa_amo_bus.MEM     amo[cpus],
    // WATCH MEM ports.
    boa_mem_bus.WATCH   watch[watchers]
);
    genvar x;
    
    // Reservation address.
    logic[alen-1:2] addr;
    // Reservation valid.
    logic           valid;
    
    // Reservation requests.
    logic[cpus-1:0] req;
    // Reservation request addresses.
    logic[alen-1:0] req_addr[cpus];
    // Current reservation.
    logic[cpus-1:0] cur;
    // Next reservation.
    logic[cpus-1:0] next;
    
    // Arbitration.
    generate
        for (x = 0; x < cpus; x = x + 1) begin
            assign req[x]      = amo[x].req;
            assign req_addr[x] = amo[x].addr;
        end
        if (arbiter == `BOA_ARBITER_RR) begin: arbiter_rr
            boa_arbiter_rr#(cpus) arbiter(clk, rst, req, cur, next);
        end else if (arbiter == `BOA_ARBITER_STATIC) begin: arbiter_static
            boa_arbiter_static#(cpus) arbiter(clk, rst, req, cur, next);
        end
    endgenerate
    boa_sel_enc#(cpus, alen) enc(next, req_addr, addr);
    
    // Matching write access detected.
    logic[watchers-1:0] wmatch_mask;
    // Matching write access detected.
    logic               wmatch;
    // Memory bus watch.
    assign wmatch = wmatch_mask != 0;
    generate
        for (x = 0; x < watchers; x = x + 1) begin
            assign wmatch_mask[x] = watch[x].we != 0 && watch[x].addr == addr;
        end
    endgenerate
    
    // AMO fulfilling logic.
    logic[cpus-1:0] valid_mask;
    assign valid = valid_mask != 0;
    generate
        for (x = 0; x < cpus; x = x + 1) begin
            assign amo[x].valid  = req[x] && next[x] && !wmatch;
            assign valid_mask[x] = amo[x].valid;
        end
    endgenerate
    
    // Latch arbitration result.
    always @(posedge clk) begin
        if (rst) begin
            cur     <= 1;
        end else if (valid) begin
            cur     <= next;
        end
    end
endmodule



// Standard Boa memory interface.
// Latency: 1 clock cycle.
interface boa_mem_bus#(
    // Address bus size, at least 8.
    parameter alen = 32,
    // Data bus size, 32 or 64.
    parameter dlen = 32,
    // Number of write enables.
    localparam wes = dlen/8
);
    // CPU -> MEM: Read enable.
    logic           re;
    // CPU -> MEM: Write enable.
    logic[wes-1:0]  we;
    // CPU -> MEM: Address.
    logic[alen-1:2] addr;
    // CPU -> MEM: Write data.
    logic[dlen-1:0] wdata;
    // MEM -> CPU: Ready, must be 1 if not selected.
    logic           ready;
    // MEM -> CPU: Read data.
    logic[dlen-1:0] rdata;
    
    // Directions from CPU perspective.
    modport CPU   (output re, we, addr, wdata, input ready, rdata);
    // Directions from MEM perspective.
    modport MEM   (output ready, rdata, input re, we, addr, wdata);
    // Directions from WATCH perspective.
    modport WATCH (input re, we, addr, wdata, ready, rdata);
endinterface

// Boa memory bus connector.
module boa_mem_connector(
    boa_mem_bus.CPU cpu,
    boa_mem_bus.MEM mem
);
    assign cpu.re       = mem.re;
    assign cpu.we       = mem.we;
    assign cpu.addr     = mem.addr;
    assign cpu.wdata    = mem.wdata;
    assign mem.ready    = cpu.ready;
    assign mem.rdata    = cpu.rdata;
endmodule

// Boa memory bus terminator.
module boa_mem_term(
    boa_mem_bus.MEM mem
);
    assign mem.ready    = 1;
    assign mem.rdata    = 'bx;
endmodule

// Boa memory clock domain crossing: MEM is faster than CPU.
// MEM clock must be a synchronized integer multiple of CPU clock.
module boa_mem_faster#(
    // Multiplier ratio from mem_clk to cpu_clk.
    parameter   integer clk_div = 2
)(
    // CPU clock.
    input  logic    cpu_clk,
    // CPU port.
    boa_mem_bus.MEM cpu_port,
    // MEM clock.
    input  logic    mem_clk,
    // MEM port.
    boa_mem_bus.CPU mem_port
);
endmodule

// Boa center remapper.
// Used to remap address spaces that have unused center bits.
module boa_mem_cmap#(
    // Bit position of high-order address bits.
    parameter integer bpos_hi = 31,
    // Number of high-order address bits.
    parameter integer alen_hi = 1,
    // Number of low-order address bits.
    parameter integer alen_lo = 7
)(
    // Address space to remap.
    boa_mem_bus.MEM mem,
    // Remapped address space.
    boa_mem_bus.CPU cpu
);
    assign cpu.re       = mem.re;
    assign cpu.we       = mem.we;
    assign cpu.addr[alen_lo-1:2]                = mem.addr[alen_lo-1:2];
    assign cpu.addr[alen_lo+alen_hi-1:alen_lo]  = mem.addr[bpos_hi+alen_hi-1:bpos_hi];
    assign cpu.wdata    = mem.wdata;
    assign mem.ready    = cpu.ready;
    assign mem.rdata    = cpu.rdata;
endmodule


// Boa address selector.
// Used to map memories into a larger address space without mirorring.
module mem_mem_amap(
    // CPU clock.
    input  logic                clk,
    // Synchrounous reset.
    input  logic                rst,
    
    // Address space to remap.
    boa_mem_bus.MEM             mem,
    // Remapped address space.
    boa_mem_bus.CPU             cpu,
    
    // Base address.
    logic[cpu.alen-1:0]         addr,
    // Number of address bits to ignore.
    logic[$clog2(cpu.alen)-1:0] pos
);
    wire [cpu.alen-1:0] mask        = 64'b1 << pos;
    wire                sel         = (mem.addr & ~mask) == (addr & ~mask);
    logic               psel;
    assign              cpu.re      = sel ? mem.re : 0;
    assign              cpu.we      = sel ? mem.we : 0;
    assign              cpu.addr    = mem.addr;
    assign              cpu.wdata   = mem.wdata;
    assign              mem.ready   = psel && cpu.ready;
    assign              mem.rdata   = cpu.rdata;
    
    always @(posedge clk) begin
        psel <= !rst && sel;
    end
endmodule


// Boa memory overlay.
// Used for memories that detect their own addresses.
module boa_mem_overlay#(
    // Data bus size, 32 or 64.
    parameter dlen = 32,
    // Number of MEM ports, at least 2.
    parameter mems = 2,
    // Number of write enables.
    localparam wes = dlen/8
)(
    // CPU port.
    boa_mem_bus.MEM         cpu,
    // MEM ports.
    boa_mem_bus.CPU         mem[mems]
);
    genvar x;
    logic           ready_mask[mems];
    logic[dlen-1:0] rdata_mask[mems];
    generate
        for (x = 0; x < mems; x = x + 1) begin
            assign mem[x].re     = cpu.re;
            assign mem[x].we     = cpu.we;
            assign mem[x].addr   = cpu.addr;
            assign mem[x].wdata  = cpu.wdata;
            assign ready_mask[x] = mem[x].ready;
            assign rdata_mask[x] = mem[x].rdata;
        end
    endgenerate
    always_comb begin
        integer i;
        cpu.ready = 1;
        cpu.rdata = 0;
        for (i = 0; i < mems; i = i + 1) begin
            cpu.ready &= ready_mask[i];
            cpu.rdata |= rdata_mask[i];
        end
    end
endmodule


// Standard Boa memory multiplexer.
module boa_mem_mux#(
    // Address bus size, at least 8.
    parameter  alen     = 32,
    // Data bus size, 32 or 64.
    parameter  dlen     = 32,
    // Number of MEM ports, at least 2.
    parameter  mems     = 2,
    // Number of write enables.
    localparam wes      = dlen/8,
    // Number of bits in the exponent.
    localparam elen     = $clog2(alen)
)(
    // CPU clock.
    input  logic            clk,
    // Synchronous reset.
    input  logic            rst,
    
    // CPU port.
    boa_mem_bus.MEM         cpu,
    // MEM ports.
    boa_mem_bus.CPU         mem[mems],
    
    // MEM port addresses, naturally aligned.
    input  logic[alen-1:0]  addr[mems],
    // MEM port size in log2(size_bytes).
    input  logic[elen-1:0]  size[mems]
);
    genvar x;
    
    // Memory selection logic.
    logic[mems-1:0] sel;
    logic[mems-1:0] r_sel;
    always @(posedge clk) r_sel <= sel;
    generate
        for (x = 0; x < mems; x = x + 1) begin
            wire[alen-1:2]  tmp     = (64'b1 << (size[x]-2)) - 1;
            assign          sel[x]  = (cpu.addr | tmp) == (addr[x][alen-1:2] | tmp);
        end
    endgenerate
    
    // Memory connection logic.
    generate
        for (x = 0; x < mems; x = x + 1) begin
            assign mem[x].re    = sel[x] ? cpu.re : 0;
            assign mem[x].we    = sel[x] ? cpu.we : 0;
            assign mem[x].addr  = cpu.addr;
            assign mem[x].wdata = cpu.wdata;
        end
    endgenerate
    logic           ready_mask[mems];
    logic[dlen-1:0] rdata_mask[mems];
    generate
        for (x = 0; x < mems; x = x + 1) begin
            assign ready_mask[x] = r_sel[x] ? mem[x].ready : 0;
            assign rdata_mask[x] = r_sel[x] ? mem[x].rdata : 0;
        end
    endgenerate
    always @(*) begin
        integer i;
        if (r_sel == 0) begin
            // Nothing selected.
            cpu.ready = 1;
            cpu.rdata = 'bx;
            
        end else begin
            // Multiplex the memory.
            cpu.ready = 0;
            cpu.rdata = 0;
            for (i = 0; i < mems; i = i + 1) begin
                cpu.ready |= ready_mask[i];
                cpu.rdata |= rdata_mask[i];
            end
        end
    end
endmodule


// Round-robin arbiter.
module boa_arbiter_rr#(
    // Number of ports, at least 2.
    parameter ports = 2
)(
    // Latch the current arbiter value.
    input  logic            clk,
    // Synchronous reset.
    input  logic            rst,
    
    // Requests.
    input  logic[ports-1:0] req,
    // Current arbitration result.
    input  logic[ports-1:0] cur,
    // Next arbitration result.
    output logic[ports-1:0] next
);
    genvar i;
    
    logic hold;
    
    always @(posedge clk) begin
        if (rst) begin
            hold <= 0;
        end else begin
            hold <= req != 0;
        end
    end
    
    /* verilator lint_off UNOPTFLAT */
    logic[ports*2-1:0] arbiter;
    assign arbiter[0] = 0;
    assign arbiter[ports] = cur[ports-1]
            || (arbiter[ports-1] && !req[ports-1]);
    generate
        for (i = 1; i < ports; i = i + 1) begin
            assign arbiter[i] = cur[i-1]
                    || (arbiter[i-1] && !req[i-1]);
            assign arbiter[i+ports] = cur[i-1]
                    || (arbiter[i+ports-1] && !req[i-1]);
        end
    endgenerate
    /* verilator lint_on UNOPTFLAT */
    
    generate
        for (i = 0; i < ports; i = i + 1) begin
            assign next[i] = hold ? cur[i] : (arbiter[i] || arbiter[i+ports]) && req[i];
        end
    endgenerate
endmodule

// Static prioritization arbiter.
module boa_arbiter_static#(
    // Number of ports, at least 2.
    parameter ports = 2
)(
    // Latch the current arbiter value.
    input  logic            clk,
    // Synchronous reset.
    input  logic            rst,
    
    // Requests.
    input  logic[ports-1:0] req,
    // Current arbitration result.
    input  logic[ports-1:0] cur,
    // Next arbitration result.
    output logic[ports-1:0] next
);
    genvar x;
    
    logic hold;
    
    always @(posedge clk) begin
        if (rst) begin
            hold <= 0;
        end else begin
            hold <= req != 0;
        end
    end
    
    generate
        assign next[0] = req == cur ? cur[0] : req[0];
        for (x = 1; x < ports; x = x + 1) begin
            assign next[x] = hold ? cur[x] : req[x] && req[x-1:0] == 0;
        end
    endgenerate
endmodule

// Standard Boa memory demultiplexer.
module boa_mem_demux#(
    // Address bus size, at least 8.
    parameter  alen     = 32,
    // Data bus size, 32 or 64.
    parameter  dlen     = 32,
    // Number of CPU ports, at least 2.
    parameter  cpus     = 2,
    // Arbitration method.
    parameter  arbiter  = `BOA_ARBITER_RR,
    // Number of write enables.
    localparam wes      = dlen/8
)(
    // CPU clock.
    input  logic    clk,
    // Synchronous reset.
    input  logic    rst,
    
    // CPU ports.
    boa_mem_bus.MEM cpu[cpus],
    // MEM port.
    boa_mem_bus.CPU mem
);
    genvar x;
    
    // Access requests.
    logic[cpus-1:0] req;
    // Current arbitration result.
    logic[cpus-1:0] cur = 1;
    // Next arbitration result.
    logic[cpus-1:0] next;
    // CPU that has custody next cycle.
    logic[cpus-1:0] next_cpu;
    
    // Arbitration.
    assign next_cpu = (cur & req) ? cur : next;
    generate
        for (x = 0; x < cpus; x = x + 1) begin
            assign req[x] = cpu[x].re || cpu[x].we;
        end
        if (arbiter == `BOA_ARBITER_RR) begin: arbiter_rr
            boa_arbiter_rr#(cpus) arbiter(clk, rst, req, cur, next);
        end else if (arbiter == `BOA_ARBITER_STATIC) begin: arbiter_static
            boa_arbiter_static#(cpus) arbiter(clk, rst, req, cur, next);
        end
    endgenerate
    
    // Latch arbitration result.
    always @(posedge clk) begin
        if (rst) begin
            cur <= 1;
        end else if (next_cpu != 0) begin
            cur <= next_cpu;
        end
    end
    
    // Memory connection logic.
    logic           masked_re[cpus];
    logic[3:0]      masked_we[cpus];
    logic[alen-1:0] masked_addr[cpus];
    logic[dlen-1:0] masked_wdata[cpus];
    generate
        for (x = 0; x < cpus; x = x + 1) begin
            assign masked_re[x]     = next_cpu[x] ? cpu[x].re    : 0;
            assign masked_we[x]     = next_cpu[x] ? cpu[x].we    : 0;
            assign masked_addr[x]   = next_cpu[x] ? cpu[x].addr  : 0;
            assign masked_wdata[x]  = next_cpu[x] ? cpu[x].wdata : 0;
        end
    endgenerate
    always @(*) begin
        integer i;
        mem.re      = 0;
        mem.we      = 0;
        mem.addr    = 0;
        mem.wdata   = 0;
        for (i = 0; i < cpus; i = i + 1) begin
            mem.re    |= masked_re[i];
            mem.we    |= masked_we[i];
            mem.addr  |= masked_addr[i];
            mem.wdata |= masked_wdata[i];
        end
    end
    generate
        for (x = 0; x < cpus; x = x + 1) begin
            assign cpu[x].ready = cur[x] && mem.ready;
            assign cpu[x].rdata = mem.rdata;
        end
    endgenerate
endmodule


// Standard Boa memory crossbar.
module boa_mem_xbar#(
    // Address bus size, at least 8.
    parameter  alen     = 32,
    // Data bus size, 32 or 64.
    parameter  dlen     = 32,
    // Number of CPU ports, at least 2.
    parameter  cpus     = 2,
    // Number of MEM ports, at least 2.
    parameter  mems     = 2,
    // Arbitration method.
    parameter  arbiter  = `BOA_ARBITER_RR,
    // Number of write enables.
    localparam wes      = dlen/8,
    // Number of bits in the exponent.
    localparam elen     = $clog2(alen)
)(
    // CPU clock.
    input  logic    clk,
    // Synchronous reset.
    input  logic    rst,
    
    // CPU ports.
    boa_mem_bus.MEM cpu[cpus],
    // MEM port.
    boa_mem_bus.CPU mem[mems],
    
    // MEM port addresses, naturally aligned.
    input  logic[alen-1:0]  addr[mems],
    // MEM port size in log2(size_bytes).
    input  logic[elen-1:0]  size[mems]
);
    genvar x, y;
    
    boa_mem_bus#(alen) grid[cpus*mems]();
    
    generate
        // CPU to grid connection.
        for (y = 0; y < cpus; y = y + 1) begin
            boa_mem_bus#(alen, dlen) col[mems]();
            boa_mem_mux#(alen, dlen, mems) mux(clk, rst, cpu[y], col, addr, size);
            for (x = 0; x < mems; x = x + 1) begin
                boa_mem_connector conn(col[x], grid[x*cpus+y]);
            end
        end
        // Grid to memory connection.
        for (x = 0; x < mems; x = x + 1) begin
            boa_mem_bus#(alen, dlen) row[cpus]();
            boa_mem_demux#(alen, dlen, cpus, arbiter) demux(clk, rst, row, mem[x]);
            for (y = 0; y < cpus; y = y + 1) begin
                boa_mem_connector conn(grid[x*cpus+y], row[y]);
            end
        end
    endgenerate
endmodule
