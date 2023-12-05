/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

`timescale 1ns/1ps



module top(
    input logic clk
);
    logic rst = 1;
    always @(negedge clk) rst <= 0;
    logic txd, rxd;
    assign rxd = 1;
    main main(clk, rst, clk, txd, rxd);
endmodule
