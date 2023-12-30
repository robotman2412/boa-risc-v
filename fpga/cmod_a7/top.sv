
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

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
    
    logic[1:0] rst = 3;
    logic shdn = 0;
    
    logic txd, rxd;
    logic[1:0] btnd;
    always @(posedge clk) begin
        tx   <= txd;
        rxd  <= rx;
        btnd <= btn;
    end
    
    logic uart_clk;
    param_clk_div#(12000000, 9600*4) uart_div(clk || shdn, uart_clk);
    logic rtc_clk;
    param_clk_div#(12000000, 1000000) rtc_div(clk || shdn, rtc_clk);
    
    logic[31:0]  gpio_out;
    logic[31:0]  gpio_oe;
    logic[31:0]  gpio_in;
    
    // assign gpio_in[31:8] = gpio_out[31:8];
    assign gpio_in[31:0] = gpio_out[31:0];
    // generate
    //     for (x = 0; x < 8; x = x + 1) begin
    //         assign pmod[x] = gpio_oe[x] ? gpio_out[x] : 'bz;
    //     end
    // endgenerate
    assign led_r = !gpio_out[8];
    assign led_g = !gpio_out[9];
    assign led_b = !gpio_out[10];
    // assign gpio_in[7:0]  = pmod;
    
    pmu_bus pmb();
    main#(.rom_file({boa_parentdir(`__FILE__), "/../../prog/bootloader/build/rom.mem"})) main(clk || shdn, rtc_clk, rst!=0, uart_clk, txd, rxd, gpio_out, gpio_oe, gpio_in, pmb);
    
    always @(posedge clk) begin
        if (pmb.shdn) begin
            shdn <= 1;
        end
        if (pmb.rst || btnd[0]) begin
            rst <= 3;
            shdn <= 0;
        end else if (rst) begin
            rst <= rst - 1;
        end
    end
    
    assign pmod[0] = txd;
    assign pmod[1] = rxd;
    assign pmod[2] = uart_clk;
    assign pmod[3] = clk;
    assign pmod[4] = rst;
    assign pmod[5] = shdn;
endmodule
