
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`default_nettype none
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
    
    // Divider latency.
    parameter integer div_latency       = 2,
    // Divider distribution, "begin", "end", "center" or "all".
    parameter integer div_distr         = "center",
    // Multiplier latency.
    parameter integer mul_latency       = 1,
    // Enable additional latch in IF branch address.
    parameter bit     if_branch_reg     = 0,
    // Enable additional latch for RMW AMOs.
    parameter bit     rmw_amo_reg       = 0,
    
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
    parameter integer dcache_line_size  = 16,
    
    // Number of PMP entries, 0, 16 or 64.
    parameter integer pmp_depth         = 16,
    // Granularity in bits of PMP entries, 2-30.
    parameter integer pmp_grain         = 2
)(
    // CPU clock.
    input  wire         clk,
    // Timekeeping clock.
    input  wire         rtc_clk,
    // Synchronous reset.
    input  wire         rst,
    
    // UART send data.
    output logic        txd,
    // UART receive data.
    input  wire         rxd,
    
    // GPIO outputs.
    output logic[31:0]  gpio_out,
    // GPIO output enables.
    output logic[31:0]  gpio_oe,
    // GPIO inputs.
    input  wire [31:0]  gpio_in,
    
    // A 32-bit quantity of randomness.
    input  wire [31:0]  randomness,
    
    // External MMIO bus.
    boa_mem_bus.CPU     xmp_bus,
    // External ROM bus.
    boa_mem_bus.CPU     extrom_bus,
    // External RAM bus.
    boa_mem_bus.CPU     extram_bus,
    // Additional uncached bus.
    boa_mem_bus.CPU     uncached_bus,
    
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
    boa_mem_bus ibus[4]();
    boa_mem_bus dbus[5]();
    boa_mem_bus#(12) peri_bus[10]();
    
    // Atomics signals.
    logic        amo_rmw;
    boa_amo_bus  amo_bus();
    boa_amo_term amo_term(amo_bus);
    
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
    boa_mem_cmap#(31, 1, cache_alen-1) icmap(ibus[3], cache_ibus);
    boa_mem_cmap#(31, 1, cache_alen-1) dcmap(dbus[3], cache_dbus);
    boa_mem_bus ucbus[2]();
    boa_mem_connector uxconn0(ucbus[0], ibus[2]);
    boa_mem_connector uxconn1(ucbus[1], dbus[2]);
    boa_mem_demux#(28) uxdmx(clk, rst, ucbus, uncached_bus);
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
    logic[3:0] gpio_ext_sig;
    logic[3:0] gpio_ext_oe;
    boa_peri_gpio#(.addr('h200), .num_ext(4)) gpio(clk, rst, peri_bus[2], gpio_ext_sig, gpio_ext_oe, gpio_out, gpio_oe, gpio_in);
    // Hardware RNG.
    boa_peri_readable#(.addr('h300)) rng(clk, rst, peri_bus[3], randomness);
    // PWM generators.
    assign gpio_ext_oe[3:0] = 8'hff;
    boa_peri_pwm#(.addr('h480)) pwm0gen(clk, clk, rst, peri_bus[4], gpio_ext_sig[0]);
    boa_peri_pwm#(.addr('h490)) pwm1gen(clk, clk, rst, peri_bus[5], gpio_ext_sig[1]);
    boa_peri_pwm#(.addr('h4a0)) pwm2gen(clk, clk, rst, peri_bus[6], gpio_ext_sig[2]);
    boa_peri_pwm#(.addr('h4b0)) pwm3gen(clk, clk, rst, peri_bus[7], gpio_ext_sig[3]);
    // Is simulator?
    boa_peri_readable#(.addr('h310)) is_sim(clk, rst, peri_bus[8], is_simulator);
    // External MMIO bus.
    boa_mem_connector xmp_conn(xmp_bus, peri_bus[9]);
    
    // Memory interconnects.
    boa_mem_mux#(.mems(4)) imux(clk, rst, cpu_ibus, ibus, {32'h4000_0000, 32'h5000_0000, 32'h7000_0000, 32'h8000_0000},                {12, bram_alen, 28, 31});
    boa_mem_mux#(.mems(5)) dmux(clk, rst, cpu_dbus, dbus, {32'h4000_0000, 32'h5000_0000, 32'h7000_0000, 32'h8000_0000, 32'h2000_0000}, {12, bram_alen, 28, 31, 12});
    boa_mem_overlay#(.mems(10)) ovl(dbus[4], peri_bus);
    
    // CPU.
    logic[31:16] irq;
    boa32_cpu#(
        .entrypoint(32'h4000_0000),
        .cpummio(32'h3000_0000),
        .hartid(0),
        .debug(0),
        .pmp_depth(pmp_depth),
        .pmp_grain(pmp_grain),
        .div_latency(div_latency),
        .div_distr(div_distr),
        .mul_latency(mul_latency),
        .if_branch_reg(if_branch_reg),
        .rmw_amo_reg(rmw_amo_reg)
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
