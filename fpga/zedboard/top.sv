
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



module top(
    // System clock.
    input  logic        sysclk,
    
    // PMODs.
    input  logic        pmod_a0,
    output logic        pmod_a1,
    input  logic        pmod_a2,
    input  logic        pmod_a3,
    input  logic        pmod_a4,
    input  logic        pmod_a5,
    input  logic        pmod_a6,
    input  logic        pmod_a7,
    
    // Top buttons.
    input  logic        btn_u,
    input  logic        btn_d,
    input  logic        btn_l,
    input  logic        btn_r,
    input  logic        btn_c,
    
    // Top LEDs.
    output logic[7:0]   led,
    // Top switches.
    input  logic[7:0]   sw
);
    genvar x;
    `include "boa_fileio.svh"
    
    // Reduce system clock from 100MHz to 25MHz.
    logic clktmp, clk;
    always @(posedge sysclk) clktmp <= !clktmp;
    always @(posedge sysclk) clk <= clk ^ clktmp;
    
    logic rst  = 1;
    logic shdn = 0;
    
    logic txd, rxd;
    logic btnd_c, btnd_u, btnd_d, btnd_l, btnd_r;
    always @(posedge clk) begin
        pmod_a1 <= txd;
        rxd     <= pmod_a0;
        btnd_u  <= btn_u;
        btnd_d  <= btn_d;
        btnd_l  <= btn_l;
        btnd_r  <= btn_r;
        btnd_c  <= btn_c;
    end
    
    logic rtc_clk;
    param_clk_div#(25000000, 1000000) rtc_div(clk || shdn, rtc_clk);
    
    // GPIO.
    logic[31:0]  gpio_out;
    logic[31:0]  gpio_oe;
    logic[31:0]  gpio_in;
    
    assign gpio_in[11:0]  = gpio_out[11:0];
    assign gpio_in[31:12] = gpio_out[31:12];
    
    // Hardware random number generation.
    logic[127:0] randomness;
    logic hyperspeed_clk;
    lfsr128 lfsr(hyperspeed_clk, randomness);
    param_pll#(100000000, 7, 1) rng_pll(sysclk, hyperspeed_clk);
    
    // External memory interfaces.
    boa_mem_bus#(12) xmp_bus();
    boa_mem_bus#(31) extrom_bus();
    boa_mem_bus#(19) extram_bus();
    boa_mem_bus#(28) uncached_bus();
    
    // External peripherals.
    // Extmem size device.
    boa_peri_readable#('h600) xm_size(clk, rst, xmp_bus, 0);
    
    // External memory bus stubs.
    assign extrom_bus.ready     = 1;
    assign extrom_bus.rdata     = 32'hffff_ffff;
    assign extram_bus.ready     = 1;
    assign extram_bus.rdata     = 32'hffff_ffff;
    assign uncached_bus.ready   = 1;
    assign uncached_bus.rdata   = 32'hffff_ffff;
    
    // Fence signals.
    logic fence_rl, fence_aq, fence_i;
    
    pmu_bus pmb();
    main#(
        .rom_file({boa_parentdir(`__FILE__), "/../../prog/bootloader/build/rom.mem"}),
        .uart_div(1302),
        .pmp_depth(16),
        .pmp_grain(12),
        .is_simulator(0),
        .div_latency(5),
        .div_distr("end"),
        .mul_latency(1)
    ) main(
        clk || shdn, rtc_clk, rst!=0,
        txd, rxd,
        gpio_out, gpio_oe, gpio_in,
        randomness,
        xmp_bus, extrom_bus, extram_bus, uncached_bus,
        fence_rl, fence_aq, fence_i,
        pmb
    );
    
    // Power management.
    always @(posedge clk) begin
        if (pmb.shdn) begin
            shdn <= 1;
        end
        if (pmb.rst || btnd_c) begin
            rst  <= 1;
            shdn <= 0;
        end else begin
            rst  <= 0;
        end
    end
    
    // Debug.
    assign led[0] = !txd;
    assign led[1] = !rxd;
    assign led[2] = rst;
    assign led[3] = shdn;
    assign led[4] = gpio_out[8];
endmodule
