
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



module top(
    input logic clk
);
    logic rst = 1;
    reg[31:0] cycle;
    always @(posedge clk) begin
        rst   <= 0;
        cycle <= cycle + 1;
    end
    
    boa_amo_bus amobus[2]();
    boa_mem_bus watchbus[2]();
    boa_amo_ctl_1 amoctl(clk, rst, amobus, watchbus);
    
    always @(*) begin
        amobus[0].req       = 0;
        amobus[0].addr      = 'bx;
        amobus[1].req       = 0;
        amobus[1].addr      = 'bx;
        watchbus[0].we      = 0;
        watchbus[0].addr    = 'bx;
        watchbus[1].we      = 0;
        watchbus[1].addr    = 'bx;
        if (cycle == 0) begin
        end else if (cycle <= 2) begin
            amobus[0].req       = 1;
            amobus[0].addr      = 39;
        end else if (cycle == 3) begin
            amobus[0].req       = 1;
            amobus[0].addr      = 39;
            watchbus[0].we      = 1;
            watchbus[0].addr    = 39;
        end else if (cycle == 7) begin
            amobus[0].req       = 1;
            amobus[0].addr      = 39;
            amobus[1].req       = 1;
            amobus[1].addr      = 69;
        end else if (cycle == 9) begin
            amobus[1].req       = 1;
            amobus[1].addr      = 69;
        end
    end
endmodule
