
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



module main#(
    // ROM image file.
    parameter string rom_file = ""
)(
    // CPU clock.
    input  wire clk,
    // Timekeeping clock.
    input  wire rtc_clk,
    // Synchronous reset.
    input  wire rst,
    
    // UART clock.
    input  wire uart_clk,
    // UART send data.
    output wire txd,
    // UART receive data.
    input  wire rxd,
    
    // Power management unit interface.
    pmu_bus.CPU pmb
);
    `include "boa_fileio.svh"
    
    // Memory buses.
    boa_mem_bus pbus();
    boa_mem_bus dbus();
    boa_mem_bus mux_a_bus[2]();
    boa_mem_bus mux_b_bus[3]();
    boa_mem_bus peri_bus[2]();
    
    // Program ROM.
    dp_block_ram#(10, rom_file, 1) rom(clk, mux_a_bus[0], mux_b_bus[0]);
    // RAM.
    dp_block_ram#(14, "", 0) ram(clk, mux_a_bus[1], mux_b_bus[1]);
    // UART.
    logic rx_full, tx_empty;
    boa_peri_uart uart(clk, rst, peri_bus[0], uart_clk, txd, rxd, tx_empty, rx_full);
    // PMU interface.
    boa_peri_pmu  pmu(clk, rst, peri_bus[1], pmb);
    
    // Memory interconnects.
    boa_mem_mux#(.mems(2)) mux_a(clk, rst, pbus, mux_a_bus, {32'h40001000, 32'h40010000},               {12, 16});
    boa_mem_mux#(.mems(3)) mux_b(clk, rst, dbus, mux_b_bus, {32'h40001000, 32'h40010000, 32'h80000000}, {12, 16, 12});
    boa_mem_mux#(.mems(2)) mux_p(clk, rst, mux_b_bus[2], peri_bus, {32'h80000000, 32'h80000100}, {8, 8});
    
    // CPU.
    logic[31:16] irq;
    boa32_cpu#(32'h40001000, 32'hff000000, 0, 0) cpu(clk, rtc_clk, rst, pbus, dbus, irq);
    
    // Interrupts.
    assign irq[16] = tx_empty;
    assign irq[17] = rx_full;
    assign irq[31:18] = 0;
endmodule
