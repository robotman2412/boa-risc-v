
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



module main#(
    // ROM image file.
    parameter string  rom_file = "",
    // UART buffer size.
    parameter integer uart_buf = 16
)(
    // CPU clock.
    input  logic        clk,
    // Timekeeping clock.
    input  logic        rtc_clk,
    // Synchronous reset.
    input  logic        rst,
    
    // UART clock.
    input  logic        uart_clk,
    // UART send data.
    output logic        txd,
    // UART receive data.
    input  logic        rxd,
    
    // GPIO outputs.
    output logic[31:0]  gpio_out,
    // GPIO output enables.
    output logic[31:0]  gpio_oe,
    // GPIO inputs.
    input  logic[31:0]  gpio_in,
    
    // Power management unit interface.
    pmu_bus.CPU pmb
);
    `include "boa_fileio.svh"
    
    // Memory buses.
    boa_mem_bus pbus();
    boa_mem_bus dbus();
    boa_mem_bus mux_a_bus[2]();
    boa_mem_bus mux_b_bus[3]();
    boa_mem_bus#(.alen(12)) peri_bus[3]();
    
    // Program ROM.
    dp_block_ram#(10, rom_file, 1) rom(clk, mux_a_bus[0], mux_b_bus[0]);
    // RAM.
    dp_block_ram#(14, "", 0) ram(clk, mux_a_bus[1], mux_b_bus[1]);
    
    // UART.
    logic rx_full, tx_empty;
    boa_peri_uart#(.addr('h000), .tx_depth(uart_buf), .rx_depth(uart_buf)) uart(
        clk, rst, peri_bus[0], uart_clk, txd, rxd, tx_empty, rx_full
    );
    // PMU interface.
    boa_peri_pmu #(.addr('h100)) pmu (clk, rst, peri_bus[1], pmb);
    // GPIO.
    boa_peri_gpio#(.addr('h200)) gpio(clk, rst, peri_bus[2], clk, 1, gpio_out, gpio_oe, gpio_in);
    
    // Memory interconnects.
    boa_mem_mux#(.mems(2)) mux_a(clk, rst, pbus, mux_a_bus, {32'h40001000, 32'h40010000},               {12, 16});
    boa_mem_mux#(.mems(3)) mux_b(clk, rst, dbus, mux_b_bus, {32'h40001000, 32'h40010000, 32'h80000000}, {12, 16, 12});
    boa_mem_overlay#(.mems(3)) ovl(mux_b_bus[2], peri_bus);
    
    // CPU.
    logic[31:16] irq;
    boa32_cpu#(32'h40001000, 32'hff000000, 0, 0) cpu(clk, rtc_clk, rst, pbus, dbus, irq);
    
    // Interrupts.
    assign irq[16] = tx_empty;
    assign irq[17] = rx_full;
    assign irq[31:18] = 0;
endmodule
