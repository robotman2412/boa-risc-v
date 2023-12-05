/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

`timescale 1ns/1ps



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
module boa_peri_pmu(
    // CPU clock.
    input  logic    clk,
    // Synchronous reset.
    input  logic    rst,
    
    // Peripheral bus.
    boa_mem_bus.MEM bus,
    // Power management bus.
    pmu_bus.CPU     pmb
);
    assign pmb.rst  = bus.we[0] && bus.wdata[0];
    assign pmb.shdn = bus.we[0] && bus.wdata[1];
endmodule
