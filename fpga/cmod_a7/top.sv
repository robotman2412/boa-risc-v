
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps

module top(
    input  logic      clk,
    output logic      tx,
    input  logic      rx,
    input  logic[1:0] btn,
    output logic[7:0] pmod
);
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
    
    pmu_bus pmb();
    main#(.rom_file({boa_parentdir(`__FILE__), "/../../prog/bootloader/build/rom.mem"})) main(clk || shdn, rtc_clk, rst!=0, uart_clk, txd, rxd, pmb);
    
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
