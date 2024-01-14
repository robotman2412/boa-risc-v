
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps

`include "boa_defines.svh"



module main#(
    // ROM image file.
    parameter string  rom_file          = "",
    // UART buffer size.
    parameter integer uart_buf          = 16,
    // Default UART clock divider.
    parameter integer uart_div          = 1250,
    // Whether we're running in the simulator.
    parameter bit     is_simulator      = 0,
    
    // Number of address bits for the internal memory, at least 16.
    parameter integer bram_alen         = 16,
    // Maximum number of address bits for the external ROM.
    parameter integer extrom_alen       = 16,
    // Maximum number of address bits for the external RAM.
    parameter integer extram_alen       = 16,
    // Number of address bits used in the instruction and data caches.
    localparam        cache_alen        = (extrom_alen > extram_alen ? extrom_alen : extram_alen) + 1,
    
    // Number of ways for the instruction cache.
    parameter integer icache_ways       = 2,
    // Number of lines for the instruction cache.
    parameter integer icache_lines      = 32,
    // Number of 4-byte words per instruction cache line.
    parameter integer icache_line_size  = 16,
    
    // Number of ways for the data cache.
    parameter integer dcache_ways       = 2,
    // Number of lines for the data cache.
    parameter integer dcache_lines      = 32,
    // Number of 4-byte words per data cache line.
    parameter integer dcache_line_size  = 16
)(
    // CPU clock.
    input  logic        clk,
    // Timekeeping clock.
    input  logic        rtc_clk,
    // Synchronous reset.
    input  logic        rst,
    
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
    
    // A 32-bit quantity of randomness.
    input  logic[31:0]  randomness,
    
    // Additional MMIO bus.
    boa_mem_bus.CPU     xmp_bus,
    // External ROM bus.
    boa_mem_bus.CPU     extrom_bus,
    // External RAM bus.
    boa_mem_bus.CPU     extram_bus,
    
    // Perform a release data fence.
    output logic    fence_rl,
    // Perform an acquire data fence.
    output logic    fence_aq,
    // Perform an acquire instruction fence.
    output logic    fence_i,
    
    // Power management unit interface.
    pmu_bus.CPU         pmb
);
    `include "boa_fileio.svh"
    
    // Memory buses.
    boa_mem_bus cpu_ibus();
    boa_mem_bus cpu_dbus();
    boa_mem_bus cache_ibus();
    boa_mem_bus cache_dbus();
    boa_mem_bus xm_ibus();
    boa_mem_bus xm_dbus();
    boa_mem_bus ibus[3]();
    boa_mem_bus dbus[4]();
    boa_mem_bus#(12) peri_bus[14]();
    
    // Atomics signals.
    logic       amo_rmw;
    boa_amo_bus amo_bus();
    
    // Program ROM.
    dp_block_ram#(10, rom_file, 1) rom(clk, ibus[0], dbus[0]);
    // RAM.
    dp_block_ram#(bram_alen-2, "", 0) ram(clk, ibus[1], dbus[1]);
    // Instruction cache.
    logic icache_flush_r, icache_flushing_r, icache_flushing_w, icache_stall;
    boa_cache#(cache_alen, icache_line_size, icache_lines, icache_ways, 0) icache (
        clk, rst,
        icache_flush_r || fence_i, 0, 0, 0,
        icache_flushing_r, icache_flushing_w, icache_stall,
        cache_ibus, xm_ibus
    );
    // Data cache.
    logic dcache_flush_r, dcache_flush_w, dcache_flushing_r, dcache_flushing_w;
    boa_cache#(cache_alen, dcache_line_size, dcache_lines, dcache_ways, 1) dcache (
        clk, rst,
        dcache_flush_r, dcache_flush_w, 0, 0,
        dcache_flushing_r, dcache_flushing_w, 0,
        cache_dbus, xm_dbus
    );
    
    // External memory connections.
    boa_mem_cmap#(31, 1, cache_alen-1) icmap(ibus[2], cache_ibus);
    boa_mem_cmap#(31, 1, cache_alen-1) dcmap(dbus[2], cache_dbus);
    boa_mem_bus#(cache_alen) cache_buses[2]();
    boa_mem_bus#(cache_alen) xm_buses[2]();
    boa_mem_connector cxconn0(cache_buses[0], xm_ibus);
    boa_mem_connector cxconn1(cache_buses[1], xm_dbus);
    boa_mem_connector cxconn2(extrom_bus, xm_buses[0]);
    boa_mem_connector cxconn3(extram_bus, xm_buses[1]);
    boa_mem_xbar#(
        cache_alen, 32, 2, 2, `BOA_ARBITER_STATIC
    ) xbar (
        clk, rst,
        cache_buses, xm_buses,
        {32'h8000_0000, 32'hc000_0000},
        {extrom_alen,   extram_alen}
    );
    
    // Cache flushing logic.
    assign dcache_flush_r = fence_aq;
    assign dcache_flush_w = fence_aq || fence_rl;
    assign icache_flush_r = fence_i;
    assign icache_stall   = dcache_flushing_w;
    
    // UART.
    logic rx_full, tx_empty;
    boa_peri_uart#(.addr('h000), .tx_depth(uart_buf), .rx_depth(uart_buf), .init_div(uart_div)) uart(
        clk, rst, peri_bus[0], txd, rxd, tx_empty, rx_full
    );
    // PMU interface.
    boa_peri_pmu #(.addr('h100)) pmu(clk, rst, peri_bus[1], pmb);
    // GPIO.
    logic[7:0] gpio_ext_sig;
    logic[7:0] gpio_ext_oe;
    boa_peri_gpio#(.addr('h200), .num_ext(8)) gpio(clk, rst, peri_bus[2], gpio_ext_sig, gpio_ext_oe, gpio_out, gpio_oe, gpio_in);
    // Hardware RNG.
    boa_peri_readable#(.addr('h300)) rng(clk, rst, peri_bus[3], randomness);
    // PWM generators.
    assign gpio_ext_oe[7:0] = 8'hff;
    boa_peri_pwm#(.addr('h480)) pwm0gen(clk, clk, rst, peri_bus[4+0], gpio_ext_sig[0]);
    boa_peri_pwm#(.addr('h490)) pwm1gen(clk, clk, rst, peri_bus[4+1], gpio_ext_sig[1]);
    boa_peri_pwm#(.addr('h4a0)) pwm2gen(clk, clk, rst, peri_bus[4+2], gpio_ext_sig[2]);
    boa_peri_pwm#(.addr('h4b0)) pwm3gen(clk, clk, rst, peri_bus[4+3], gpio_ext_sig[3]);
    boa_peri_pwm#(.addr('h4c0)) pwm4gen(clk, clk, rst, peri_bus[4+4], gpio_ext_sig[4]);
    boa_peri_pwm#(.addr('h4d0)) pwm5gen(clk, clk, rst, peri_bus[4+5], gpio_ext_sig[5]);
    boa_peri_pwm#(.addr('h4e0)) pwm6gen(clk, clk, rst, peri_bus[4+6], gpio_ext_sig[6]);
    boa_peri_pwm#(.addr('h4f0)) pwm7gen(clk, clk, rst, peri_bus[4+7], gpio_ext_sig[7]);
    // Is simulator?
    boa_peri_readable#(.addr('h310)) is_sim(clk, rst, peri_bus[12], is_simulator);
    // External MMIO bus.
    boa_mem_connector xmp_conn(xmp_bus, peri_bus[13]);
    
    // Memory interconnects.
    boa_mem_mux#(.mems(3)) imux(clk, rst, cpu_ibus, ibus, {32'h4000_0000, 32'h5000_0000, 32'h8000_0000},                {12, bram_alen, 31});
    boa_mem_mux#(.mems(4)) dmux(clk, rst, cpu_dbus, dbus, {32'h4000_0000, 32'h5000_0000, 32'h8000_0000, 32'h2000_0000}, {12, bram_alen, 31, 12});
    boa_mem_overlay#(.mems(14)) ovl(dbus[3], peri_bus);
    
    // CPU.
    logic[31:16] irq;
    boa32_cpu#(
        .entrypoint(32'h4000_0000),
        .cpummio(32'h3000_0000),
        .hartid(0),
        .debug(0)
    ) cpu (
        clk, rtc_clk, rst,
        cpu_ibus, cpu_dbus,
        fence_rl, fence_aq, fence_i,
        amo_rmw, amo_bus,
        irq
    );
    
    // Interrupts.
    assign irq[16] = tx_empty;
    assign irq[17] = rx_full;
    assign irq[31:18] = 0;
endmodule
