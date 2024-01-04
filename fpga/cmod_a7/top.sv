
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps

module top(
    input  logic      clk,
    output logic      tx,
    input  logic      rx,
    input  logic[1:0] btn,
    output logic      led_r,
    output logic      led_g,
    output logic      led_b,
    inout  logic[7:0] pmod
);
    genvar x;
    `include "boa_fileio.svh"
    
    localparam rst_len = 3;
    
    logic[$clog2(rst_len)-1:0] rst = rst_len;
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
    
    logic[31:0]  gpio_out;
    logic[31:0]  gpio_oe;
    logic[31:0]  gpio_in;
    
    assign gpio_in[10:0]  = gpio_out[10:0];
    assign gpio_in[11]    = btnd[1];
    assign gpio_in[31:12] = gpio_out[31:12];
    assign led_r = !gpio_out[8];
    assign led_g = !gpio_out[9];
    assign led_b = !gpio_out[10];
    
    logic[127:0] randomness;
    logic hyperspeed_clk;
    lfsr128 lfsr(hyperspeed_clk, randomness);
    // assign hyperspeed_clk = clk;
    param_pll#(12000000, 48, 4) rng_pll(clk, hyperspeed_clk);
    
    pmu_bus pmb();
    main#(
        .rom_file({boa_parentdir(`__FILE__), "/../../prog/bootloader/build/rom.mem"}),
        .uart_div(625),
        .is_simulator(0)
    ) main(
        clk || shdn, rtc_clk, rst!=0,
        txd, rxd,
        gpio_out, gpio_oe, gpio_in,
        randomness,
        pmb
    );
    
    always @(posedge clk) begin
        if (pmb.shdn) begin
            shdn <= 1;
        end
        if (pmb.rst || btnd[0]) begin
            rst  <= rst_len;
            shdn <= 0;
        end else if (rst) begin
            rst  <= rst - 1;
        end
    end
    
    assign pmod[0] = txd;
    assign pmod[1] = rxd;
    assign pmod[3] = clk;
    assign pmod[4] = rst;
    assign pmod[5] = shdn;
    assign pmod[6] = hyperspeed_clk;
endmodule
