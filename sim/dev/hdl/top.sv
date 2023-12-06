/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

`timescale 1ns/1ps



module top(
    input  logic clk,
    output logic tx,
    input  logic rx
);
    `include "boa_fileio.svh"
    logic[1:0] rst = 3;
    pmu_bus pmb();
    main#(.rom_file({boa_parentdir(`__FILE__), "/../obj_dir/rom.mem"})) main(clk, rst!=0, clk, tx, rx, pmb);
    always @(posedge clk) begin
        if (pmb.shdn) begin $display("PMU poweroff"); $finish; end
        if (pmb.rst) rst <= 3;
        else if (rst) rst <= rst - 1;
    end
endmodule
