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
    logic[1:0] rst = 3;
    logic txd, rxd;
    assign rxd = 1;
    pmu_bus pmb();
    main main(clk, rst!=0, clk, txd, rxd, pmb);
    always @(posedge clk) begin
        if (pmb.shdn) begin $display("PMU poweroff"); $finish; end
        if (pmb.rst) rst <= 3;
        else if (rst) rst <= rst - 1;
    end
endmodule
