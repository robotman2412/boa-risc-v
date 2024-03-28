
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`default_nettype none



// Configurable 8-bit SRAM controller.
module boa_extmem_sram#(
    // Address width of the SRAM.
    parameter sram_alen = 8
)(
    // CPU clock.
    input  wire                 clk,
    // Synchronous reset.
    input  wire                 rst,
    
    // Internal memory bus.
    boa_mem_bus.MEM             bus,
    
    // Extmem read enable.
    output logic                xm_re,
    // Extmem write enable.
    output logic                xm_we,
    // Extmem address.
    output logic[sram_alen-1:0] xm_addr,
    // Extmem write data.
    output logic[7:0]           xm_wdata,
    // Extmem read data.
    input  wire [7:0]           xm_rdata
);
    genvar x;
    
    // Read enable buffer.
    logic                   ab_re;
    // Write enable buffer.
    logic[3:0]              ab_we;
    // Address buffer.
    logic[sram_alen-1:2]    ab_addr;
    // Write data buffer.
    logic[31:0]             ab_wdata;
    // Read data buffer.
    logic[23:0]             rdata;
    
    // Access in progress.
    logic                   busy;
    // Extmem sub-word address.
    logic[1:0]              subaddr;
    
    // Internal bus logic.
    assign bus.rdata[31:24] = xm_rdata;
    assign bus.rdata[23:0]  = rdata;
    always @(posedge clk) begin
        if (rst) begin
            // Reset.
            ab_re       <= 0;
            ab_we       <= 0;
            ab_addr     <= 'bx;
            ab_wdata    <= 'bx;
            subaddr     <= 0;
            busy        <= 0;
            bus.ready   <= 1;
        end else if (busy && subaddr == 3) begin
            // Extmem access finishing up.
            subaddr     <= subaddr + 1;
            bus.ready   <= !(bus.re || bus.we);
            busy        <= bus.re || bus.we;
            if (bus.re || bus.we) begin
                ab_re       <= bus.re;
                ab_we       <= bus.we;
                ab_addr     <= bus.addr;
                ab_wdata    <= bus.wdata;
            end
        end else if (busy) begin
            // Extmem access in progress.
            subaddr     <= subaddr + 1;
            bus.ready   <= subaddr[1];
            if (subaddr == 0) begin
                rdata[7:0]   <= xm_rdata;
            end else if (subaddr == 1) begin
                rdata[15:8]  <= xm_rdata;
            end else if (subaddr == 2) begin
                rdata[23:16] <= xm_rdata;
            end
        end else if (bus.re || bus.we) begin
            // Initiate extmem access.
            ab_re       <= bus.re;
            ab_we       <= bus.we;
            ab_addr     <= bus.addr;
            ab_wdata    <= bus.wdata;
            subaddr     <= 0;
            busy        <= 1;
            bus.ready   <= 0;
        end else begin
            // Idle.
            ab_re       <= 0;
            ab_we       <= 0;
            ab_addr     <= 'bx;
            ab_wdata    <= 'bx;
            subaddr     <= 0;
            busy        <= 0;
            bus.ready   <= 1;
        end
    end
    
    // External bus logic.
    assign xm_addr[sram_alen-1:2]   = ab_addr[sram_alen-1:2];
    assign xm_addr[1:0]             = subaddr;
    assign xm_we                    = busy && ab_we[subaddr];
    assign xm_re                    = busy && ab_re;
    always @(*) begin
        if (subaddr == 0) begin
            xm_wdata = ab_wdata[7:0];
        end else if (subaddr == 1) begin
            xm_wdata = ab_wdata[15:8];
        end else if (subaddr == 2) begin
            xm_wdata = ab_wdata[23:16];
        end else begin
            xm_wdata = ab_wdata[31:24];
        end
    end
endmodule
