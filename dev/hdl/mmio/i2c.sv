
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`default_nettype none



// Simple I²C master peripheral.
module boa_peri_i2c#(
    // Base address to respond to.
    parameter addr          = 32'h8000_0000
)(
    // Peripheral bus clock.
    input  wire         clk,
    // Synchronous reset.
    input  wire         rst,
    // Peripheral bus interface.
    boa_mem_bus.MEM     bus,
    
    // I²C clock: at most 50% of peripheral bus clock.
    input  wire         i2c_clk,
    // SCL pulldown enable.
    output logic        scl_pd,
    // SDA pulldown enable.
    output logic        sda_pd,
    // SDA input.
    input  wire         sda_in
);
endmodule
