
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`default_nettype none



module top(
    input logic clk
);
    logic rst;
    reg[31:0] cycle;
    always @(posedge clk) begin
        cycle <= cycle + 1;
    end
    
    boa_mem_bus#(16) xm_bus();
    always @(posedge clk) begin
        xm_bus.rdata[31]    <= xm_bus.re;
        xm_bus.rdata[30:16] <= 0;
        xm_bus.rdata[15:2]  <= xm_bus.addr[15:2];
        xm_bus.rdata[1:0]   <= 0;
    end
    
    boa_mem_bus#(16) bus();
    logic flush_r, flush_w, pi_en;
    logic[15:2] pi_addr;
    boa_cache#(16, 4, 4, 2) cache(
        clk, rst,
        flush_r, flush_w, pi_en, pi_addr,
        bus, xm_bus
    );
    
    always @(*) begin
        xm_bus.ready = 1;
        rst       = 0;
        bus.re    = 0;
        bus.we    = 0;
        bus.addr  = 0;
        bus.wdata = 0;
        flush_r   = 0;
        flush_w   = 0;
        pi_en     = 0;
        pi_addr   = 0;
        if (cycle <= 9) begin
            bus.re    = 1;
            bus.we    = 4'b1111;
            bus.addr  = 2;
            bus.wdata = 32'hdead_beef;
            xm_bus.ready = cycle[0];
        end else if (cycle <= 19) begin
            bus.re    = 1;
            bus.addr  = 18;
            xm_bus.ready = !(cycle >= 11 && cycle <= 15);
        end else if (cycle <= 34) begin
            bus.re    = 1;
            bus.addr  = 34;
            xm_bus.ready = !cycle[0] || (cycle >= 31);
        end else if (cycle == 35) begin
            flush_r   = 1;
            flush_w   = 0;
            pi_en     = 1;
            pi_addr   = 34;
        end else if (cycle <= 41) begin
            bus.re    = 1;
            bus.we    = 4'b1111;
            bus.addr  = 34;
            bus.wdata = 32'hcafe_babe;
        end else if (cycle == 42) begin
            flush_r   = 1;
            flush_w   = 1;
        end else if (cycle <= 57) begin
        end else if (cycle <= 58) begin
            bus.re    = 1;
            bus.we    = 4'b1111;
            bus.addr  = 34;
            bus.wdata = 32'hcafe_babe;
        end else if (cycle == 59) begin
            rst = 1;
        end
    end
endmodule
