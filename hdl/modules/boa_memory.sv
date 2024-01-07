
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
    boa_amo_bus.MEM mem,
);
    assign mem.valid = 1;
endmodule


// Single reservation boa atomic memory operation controller.
module boa_amo_ctl_1#(
    // Number of CPUs, 2+.
    parameter cpus      = 2,
    // Arbitration strategy.
    parameter arbiter   = `BOA_ARBITER_RR
)(
    // CPU clock.
    input  logic    clk,
    // Synchronous reset.
    input  logic    rst,
    
    // CPU AMO ports.
    boa_amo_bus.MEM amo[cpus]
);
    // Address bus size, at least 8.
    localparam alen = amo[0].alen;
    
    // Reservation address.
    logic[alen-1:2] addr;
    // Next reservation address.
    logic[alen-1:2] next_addr;
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
            assign req[x]      = cpu[x].req;
            assign req_addr[x] = cpu[x].addr;
        end
        if (arbiter == `BOA_ARBITER_RR) begin: arbiter_rr
            boa_arbiter_rr#(cpus) arbiter(clk, rst, req, cur, next);
        end else if (arbiter == `BOA_ARBITER_STATIC) begin: arbiter_static
            boa_arbiter_static#(cpus) arbiter(clk, rst, req, cur, next);
        end
    endgenerate
    boa_sel_enc#(cpus, alen) enc(next, req_addr, next_addr);
    
    // Latch arbitration result.
    always @(posedge clk) begin
        if (rst) begin
            cur <= 1;
        end else if (next != 0) begin
            cur   <= next;
            valid <= 1;
            addr  <= next_addr;
        end else begin
            valid <= 0;
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
    modport CPU (output re, we, addr, wdata, input ready, rdata);
    // Directions from MEM perspective.
    modport MEM (output ready, rdata, input re, we, addr, wdata);
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
                    || (arbiter[i-1] && !req[i-1]);
        end
    endgenerate
    /* verilator lint_on UNOPTFLAT */
    
    generate
        for (i = 0; i < ports; i = i + 1) begin
            assign next[i] = (arbiter[i] || arbiter[i+ports]) && req[i];
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
    generate
        assign next[0] = req[0];
        for (x = 1; x < ports; x = x + 1) begin
            assign next[x] = req == cur ? cur[x] : req[x] && req[x-1:0] == 0;
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
    logic           masked_we[cpus];
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
