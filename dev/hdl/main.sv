
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



module main#(
    // ROM image file.
    parameter string  rom_file      = "",
    // UART buffer size.
    parameter integer uart_buf      = 16,
    // Default UART clock divider.
    parameter integer uart_div      = 1250,
    // Whether we're running in the simulator.
    parameter bit     is_simulator  = 0
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
    // External program bus.
    boa_mem_bus.CPU     xmi_bus,
    // External data bus.
    boa_mem_bus.CPU     xmd_bus,
    
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
    boa_mem_bus pbus();
    boa_mem_bus dbus();
    boa_mem_bus mux_a_bus[3]();
    boa_mem_bus mux_b_bus[4]();
    boa_mem_bus#(.alen(12)) peri_bus[14]();
    
    // Program ROM.
    dp_block_ram#(10, rom_file, 1) rom(clk, mux_a_bus[0], mux_b_bus[0]);
    // RAM.
    dp_block_ram#(14, "", 0) ram(clk, mux_a_bus[1], mux_b_bus[1]);
    // External memory.
    boa_mem_connector xmi_conn(xmi_bus, mux_a_bus[2]);
    boa_mem_connector xmd_conn(xmd_bus, mux_b_bus[2]);
    
    // UART.
    logic rx_full, tx_empty;
    boa_peri_uart#(.addr('h000), .tx_depth(uart_buf), .rx_depth(uart_buf), .init_div(uart_div)) uart(
        clk, rst, peri_bus[0], txd, rxd, tx_empty, rx_full
    );
    // PMU interface.
    boa_peri_pmu #(.addr('h100)) pmu (clk, rst, peri_bus[1], pmb);
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
    boa_mem_mux#(.mems(3)) mux_a(clk, rst, pbus, mux_a_bus, {32'h4000_1000, 32'h4001_0000, 32'h8000_0000},                {12, 16, 24});
    boa_mem_mux#(.mems(4)) mux_b(clk, rst, dbus, mux_b_bus, {32'h4000_1000, 32'h4001_0000, 32'h8000_0000, 32'h2000_0000}, {12, 16, 24, 12});
    boa_mem_overlay#(.mems(14)) ovl(mux_b_bus[3], peri_bus);
    
    // CPU.
    logic[31:16] irq;
    boa32_cpu#(
        .entrypoint(32'h40001000),
        .cpummio(32'hff000000),
        .hartid(0),
        .debug(0)
    ) cpu (
        clk, rtc_clk, rst,
        pbus, dbus,
        fence_rl, fence_aq, fence_i,
        irq
    );
    
    // Interrupts.
    assign irq[16] = tx_empty;
    assign irq[17] = rx_full;
    assign irq[31:18] = 0;
endmodule
