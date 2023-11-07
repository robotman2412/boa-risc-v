/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

`include "boa_defines.sv"



// Standard Boa memory interface.
interface boa_mem_bus#(
    // Address bus size, at least 8.
    parameter alen = 32,
    // Data bus size, 32 or 64.
    parameter dlen = 32
);
    // CPU -> MEM: Read enable.
    logic           re;
    // CPU -> MEM: Write enable.
    logic           we;
    // CPU -> MEM: Address.
    logic[alen-1:2] addr;
    // CPU -> MEM: Write data.
    logic[dlen-1:0] wdata;
    // MEM -> CPU: Ready.
    logic           ready;
    // MEM -> CPU: Read data.
    logic[dlen-1:0] rdata;
    
    // Directions from CPU perspective.
    modport CPU (output re, we, addr, wdata, input ready, rdata);
    // Directions from MEM perspective.
    modport MEM (output ready, rdata, input re, we, addr, wdata);
endinterface
