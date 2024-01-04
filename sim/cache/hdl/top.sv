
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



module top(
    input logic clk
);
    wire rst = 0;
    reg[31:0] cycle;
    always @(posedge clk) begin
        cycle <= cycle + 1;
    end
    
    boa_mem_bus#(16) xm_bus();
    assign xm_bus.ready = 1;
    always @(posedge clk) begin
        xm_bus.rdata[31]    <= xm_bus.re;
        xm_bus.rdata[30:16] <= 0;
        xm_bus.rdata[15:2]  <= xm_bus.addr[15:2];
        xm_bus.rdata[1:0]   <= 0;
    end
    
    boa_mem_bus#(16) bus();
    boa_cache#(16, 4, 4, 2) cache(
        clk, rst,
        0, 0, 0, 0,
        0, 0,
        bus, xm_bus
    );
    
    always @(*) begin
        if (cycle <= 5) begin
            bus.re    = 1;
            bus.we    = 1;
            bus.addr  = 2;
            bus.wdata = 32'hdead_beef;
        end else if (cycle <= 11) begin
            bus.re    = 1;
            bus.we    = 0;
            bus.addr  = 18;
            bus.wdata = 0;
        end else if (cycle <= 22) begin
            bus.re    = 1;
            bus.we    = 0;
            bus.addr  = 34;
            bus.wdata = 0;
        end else begin
            bus.re    = 0;
            bus.we    = 0;
            bus.addr  = 0;
            bus.wdata = 0;
        end
    end
endmodule
