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
    input  wire rst,
    // UART clock.
    input  wire uart_clk,
    // UART send data.
    output wire txd,
    // UART receive data.
    input  wire rxd
);
    `include "boa_fileio.svh"
    
    // Memory buses.
    boa_mem_bus pbus();
    boa_mem_bus dbus();
    boa_mem_bus mux_a_bus[2]();
    boa_mem_bus mux_b_bus[3]();
    
    // Program ROM.
    dp_block_ram#(10, {boa_parentdir(`__FILE__), "/../build/rom.mem"}, 1) rom(clk, mux_a_bus[0], mux_b_bus[0]);
    // RAM.
    dp_block_ram#(10, "", 0) ram(clk, mux_a_bus[1], mux_b_bus[1]);
    // UART.
    logic rx_full, tx_empty;
    boa_peri_uart uart(clk, rst, mux_b_bus[2], uart_clk, txd, rxd, tx_empty, rx_full);
    
    // Memory interconnects.
    boa_mem_mux mux_a(clk, rst, pbus, mux_a_bus, {'h000, 'h400}, {10, 10});
    boa_mem_mux#(.mems(3)) mux_b(clk, rst, dbus, mux_b_bus, {'h000, 'h400, 'h800}, {10, 10, 10});
    
    // CPU.
    logic[31:16] irq;
    boa32_cpu#(0, 0) cpu(clk, rst, pbus, dbus, irq);
    
    // Interrupts.
    assign irq[16] = tx_empty;
    assign irq[17] = rx_full;
    assign irq[31:18] = 0;
endmodule
