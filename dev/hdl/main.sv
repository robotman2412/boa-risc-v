/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

`timescale 1ns/1ps



module main(
    // CPU clock.
    input  wire clk,
    // Synchronous reset.
    input  wire rst
);
    `include "boa_fileio.svh"
    
    // Memory buses.
    boa_mem_bus pbus();
    boa_mem_bus dbus();
    boa_mem_bus mux_a_bus[2]();
    boa_mem_bus mux_b_bus[2]();
    
    // Program ROM.
    dp_block_ram#(10, {boa_parentdir(`__FILE__), "/../build/rom.mem"}, 0) rom(clk, mux_a_bus[0], mux_b_bus[0]);
    // RAM.
    dp_block_ram#(10, "", 0) ram(clk, mux_a_bus[1], mux_b_bus[1]);
    
    // Memory interconnects.
    boa_mem_mux mux_a(clk, rst, pbus, mux_a_bus, {'h000, 'h400}, {10, 10});
    boa_mem_mux mux_b(clk, rst, dbus, mux_b_bus, {'h000, 'h400}, {10, 10});
    
    // CPU.
    boa32_cpu#(0, 0) cpu(clk, rst, pbus, dbus, 0);
endmodule
