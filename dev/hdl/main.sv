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
    
    boa_mem_bus cbus[2]();
    boa_mem_bus rbus();
    
    // Program ROM.
    block_ram#(8, {boa_parentdir(`__FILE__), "/../build/rom.mem"}, 1) rom(clk, rbus);
    // RAM.
    // block_ram#(8, "", 0) ram(clk, dbus);
    
    boa_mem_demux mux(clk, rst, cbus, rbus);
    
    // CPU.
    boa32_cpu#(0, 0) cpu(clk, rst, cbus[0], cbus[1], 0);
endmodule
