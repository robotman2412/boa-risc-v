
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Single GPIO pin output.
module gpio_pin#(
    // Configuration register address.
    parameter addr      = 32'h8000_0000,
    // Number of external signals for GPIO matrix, 1 to 65536.
    parameter num_ext   = 1
)(
    // Peripheral bus clock.
    input  logic                clk,
    // Synchronous reset.
    input  logic                rst,
    // Peripheral bus interface.
    boa_mem_bus.MEM             bus,
    
    // External signals for GPIO matrix.
    input  logic[num_ext-1:0]   ext,
    
    // Output.
    output logic                pin_out,
    // Output enable.
    output logic                pin_oe,
);
endmodule

// Simple GPIO matrix peripheral.
module boa_peri_gpio#(
    // Base address to respond to.
    parameter addr      = 32'h8000_0000,
    // Number of GPIO pins, 2 to bus.dlen.
    parameter pins      = 32,
    // Number of external signals for GPIO matrix, 1 to 65536.
    parameter num_ext   = 1
)(
    // Peripheral bus clock.
    input  logic                clk,
    // Synchronous reset.
    input  logic                rst,
    // Peripheral bus interface.
    boa_mem_bus.MEM             bus,
    
    // External signals for GPIO matrix.
    input  logic[num_ext-1:0]   ext,
    
    // Outputs.
    output logic[pins-1:0]      pin_out,
    // Output enable.
    output logic[pins-1:0]      pin_oe,
    // Inputs.
    input  logic[pins-1:0]      pin_in
);
    // Basic output register.
    logic[pins-1:0] out_reg;
endmodule
