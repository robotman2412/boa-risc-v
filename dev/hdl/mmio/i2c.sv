
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Simple I²C master peripheral.
module boa_peri_i2c#(
    // Base address to respond to.
    parameter addr          = 32'h8000_0000
)(
    // Peripheral bus clock.
    input  logic        clk,
    // Synchronous reset.
    input  logic        rst,
    // Peripheral bus interface.
    boa_mem_bus.MEM     bus,
    
    // I²C clock: at most 50% of peripheral bus clock.
    input  logic        i2c_clk,
    // SCL pulldown enable.
    output logic        scl_pd,
    // SDA pulldown enable.
    output logic        sda_pd,
    // SDA input.
    input  logic        sda_in
);
endmodule
