
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



module top(
    input logic clk
);
    wire rst = 0;
    
    logic[31:0] div = 0;
    always @(posedge clk) div <= div + 1;
    
    // Program bus.
    boa_mem_bus pbus();
    rom prom(clk, pbus);
    // Dummy data bus.
    boa_mem_bus dbus();
    block_ram ram(clk, dbus);
    
    // The CPU.
    boa32_cpu#(.hartid(32'hdeadbeef), .entrypoint(0), .debug(1)) cpu(
        clk, rst,
        pbus, dbus,
        div >= 10 && div < 13 ? 16'h8001 : 16'h0000
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
