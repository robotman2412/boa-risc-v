
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



module top(
    input logic clk
);
    reg[31:0] cycle;
    always @(posedge clk) begin
        cycle <= cycle + 1;
    end
    
    localparam sram_alen = 8;
    logic                xm_re;
    logic                xm_we;
    logic[sram_alen-1:0] xm_addr;
    logic[7:0]           xm_wdata;
    logic[7:0]           xm_rdata;
    boa_mem_bus#(16) bus();
    boa_extmem_sram#(sram_alen) xm_ctl(clk, 0, bus, xm_re, xm_we, xm_addr, xm_wdata, xm_rdata);
    
    assign xm_rdata = xm_addr;
    
    always @(*) begin
        if (cycle <= 3) begin
            bus.re    = 0;
            bus.we    = 15;
            bus.addr  = 2;
            bus.wdata = 32'hdead_beef;
        end else if (cycle <= 7) begin
            bus.re    = 1;
            bus.we    = 0;
            bus.addr  = 18;
            bus.wdata = 0;
        end else if (cycle <= 11) begin
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
