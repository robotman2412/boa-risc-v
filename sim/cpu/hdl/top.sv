/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

`timescale 1ns/1ps



module top(
    input logic clk
);
    wire rst = 0;
    
    // Program bus.
    boa_mem_bus pbus();
    rom prom(clk, pbus);
    // Dummy data bus.
    boa_mem_bus dbus();
    block_ram ram(clk, dbus);
    
    // The CPU.
    boa32_cpu#(.entrypoint(0)) cpu(
        clk, rst,
        pbus, dbus,
        16'h0000
    );
endmodule

module rom(
    input logic clk,
    boa_mem_bus.MEM bus
);
    `include "rom.svh"
    logic[$clog2(rom_len)-1:0] addr;
    always @(posedge clk) begin
        addr <= bus.addr[$clog2(rom_len)+1:2];
    end
    always @(negedge clk) begin
        bus.ready <= 1;
        bus.rdata <= rom[addr];
    end
endmodule