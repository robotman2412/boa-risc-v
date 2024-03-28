
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`default_nettype none



module top(
    // System clock.
    input  wire         clk,
    // UART send data.
    output logic        tx,
    // UART receive data.
    input  wire         rx,
    
    // Top buttons.
    input  wire [1:0]   btn,
    // LED red component.
    output logic        led_r,
    // LED green component.
    output logic        led_g,
    // LED blue component.
    output logic        led_b,
    
    // Top PMOD port.
    inout  logic[7:0]   pmod,
    
    // SRAM read enable.
    output logic        sram_oe_n,
    // SRAM write enable.
    output logic        sram_we_n,
    // SRAM chip select.
    output logic        sram_ce_n,
    // SRAM address.
    output logic[18:0]  sram_addr,
    // SRAM data.
    inout  logic[7:0]   sram_data
);
    genvar x;
    `include "boa_fileio.svh"
    
    logic rst  = 1;
    logic shdn = 0;
    
    logic txd, rxd;
    logic[1:0] btnd;
    always @(posedge clk) begin
        tx   <= txd;
        rxd  <= rx;
        btnd <= btn;
    end
    
    logic rtc_clk;
    param_clk_div#(12000000, 1000000) rtc_div(clk || shdn, rtc_clk);
    
    // GPIO.
    logic[31:0]  gpio_out;
    logic[31:0]  gpio_oe;
    logic[31:0]  gpio_in;
    
    assign gpio_in[10:0]  = gpio_out[10:0];
    assign gpio_in[11]    = btnd[1];
    assign gpio_in[31:12] = gpio_out[31:12];
    assign led_r = !gpio_out[8];
    assign led_g = !gpio_out[9];
    assign led_b = !gpio_out[10];
    
    // Hardware random number generation.
    logic[127:0] randomness;
    logic hyperspeed_clk;
    lfsr128 lfsr(hyperspeed_clk, randomness);
    param_pll#(12000000, 48, 4) rng_pll(clk, hyperspeed_clk);
    
    // External memory interfaces.
    boa_mem_bus#(12) xmp_bus();
    boa_mem_bus#(31) extrom_bus();
    boa_mem_bus#(19) extram_bus();
    boa_mem_bus#(28) uncached_bus();
    
    // External peripherals.
    // Extmem size device.
    boa_peri_readable#('h600) xm_size(clk, rst, xmp_bus, 32'b1 << 19);
    
    // External memory bus stubs.
    assign extrom_bus.ready     = 1;
    assign extrom_bus.rdata     = 32'hffff_ffff;
    assign uncached_bus.ready   = 1;
    assign uncached_bus.rdata   = 32'hffff_ffff;
    
    // External RAM interface.
    logic       sram_re;
    logic       sram_we;
    logic[7:0]  sram_rdata;
    logic[7:0]  sram_wdata;
    assign sram_oe_n    = !(sram_re && !sram_we);
    assign sram_we_n    = !sram_we;
    assign sram_ce_n    = 0;
    assign sram_rdata   = sram_data;
    assign sram_data    = sram_we ? sram_wdata : 'bz;
    boa_extmem_sram#(19) sram_ctl(clk, rst, extram_bus, sram_re, sram_we, sram_addr, sram_wdata, sram_rdata);
    
    // Fence signals.
    logic fence_rl, fence_aq, fence_i;
    
    pmu_bus pmb();
    main#(
        .rom_file({boa_parentdir(`__FILE__), "/../../prog/bootloader/build/rom.mem"}),
        .uart_div(625),
        .pmp_depth(16),
        .pmp_grain(12),
        .is_simulator(0)
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
        if (pmb.rst || btnd[0]) begin
            rst  <= 1;
            shdn <= 0;
        end else begin
            rst  <= 0;
        end
    end
    
    assign pmod[0] = txd;
    assign pmod[1] = rxd;
    assign pmod[3] = clk;
    assign pmod[4] = rst;
    assign pmod[5] = shdn;
    assign pmod[6] = hyperspeed_clk;
endmodule
