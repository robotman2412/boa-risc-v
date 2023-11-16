/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

`timescale 1ns/1ps
`include "boa_defines.svh"



// Configurable block memory on a boa memory bus.
module block_ram#(
    // Log2 of number of 32-bit words.
    parameter int    abits      = 8,
    // Initialization file, if any.
    parameter string init_file  = "",
    // ROM mode; writes will be rejected in ROM mode.
    parameter bit    is_rom     = 0
)(
    // Memory clock.
    input  logic    clk,
    // Memory bus.
    boa_mem_bus.MEM bus
);
    // Raw block RAM storage.
    raw_block_ram#(abits, 4, 8, 0, init_file) bram_inst(clk, bus.we, bus.addr[abits+1:2], bus.wdata, bus.rdata);
    assign bus.ready = 1;
endmodule
