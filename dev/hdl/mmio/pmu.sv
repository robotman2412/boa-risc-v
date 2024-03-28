
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`default_nettype none



// Power management bus.
interface pmu_bus();
    // CPU->PMU: System reset.
    logic   rst;
    // CPU->PMU: System shutdown.
    logic   shdn;
    
    // Signals as seen from CPU perspective.
    modport CPU (output rst, shdn);
    // Signals as seen from PMU perspective.
    modport PMU (input  rst, shdn);
endinterface

// Power management unit.
module boa_peri_pmu#(
    // Base address to respond to.
    parameter addr      = 32'h8000_0000
)(
    // CPU clock.
    input  wire     clk,
    // Synchronous reset.
    input  wire     rst,
    
    // Peripheral bus.
    boa_mem_bus.MEM bus,
    // Power management bus.
    pmu_bus.CPU     pmb
);
    assign pmb.rst   = bus.addr<<2 == addr && bus.we[0] && bus.wdata[0];
    assign pmb.shdn  = bus.addr<<2 == addr && bus.we[0] && bus.wdata[1];
    assign bus.ready = 1;
    assign bus.rdata = 0;
endmodule
