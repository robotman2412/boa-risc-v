
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Simple GPIO peripheral.
module boa_peri_gpio#(
    parameter addr = 32'h8000_0000
)(
    // Peripheral bus clock.
    input  logic        clk,
    // Global reset.
    input  logic        rst,
    // Peripheral bus interface.
    boa_mem_bus.MEM     bus,
    
    // Outputs.
    output logic[31:0]  pin_out,
    // Output enable.
    output logic[31:0]  pin_oe,
    // Inputs.
    input  logic[31:0]  pin_in
);
endmodule
