
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`include "boa_defines.svh"



module boa_mtime#(
    parameter addr = 32'hffff_f000
)(
    // CPU clock.
    input  logic    clk,
    // Timekeeping clock.
    input  logic    rtc_clk,
    // Synchronous reset.
    input  logic    rst,
    
    // Memory bus.
    boa_mem_bus.MEM bus,
    
    // Interrupt signal.
    output logic    irq
);
    initial begin
        bus.ready = 1;
    end
    
    // RTC domain: Timer register.
    logic[63:0] rtc_mtime;
    // RTC domain: Comparison register.
    logic[63:0] rtc_mtimecmp;
    // CPU domain: Timer register.
    logic[63:0] cpu_mtime;
    // CPU domain: Comparison register.
    logic[63:0] cpu_mtimecmp;
    
    // CPU domain: Time write trigger.
    logic[1:0] cpu_mtime_we;
    // RTC domain: Time write trigger.
    logic[1:0] rtc_mtime_we;
    // CPU domain: Time write acknowledge.
    logic[1:0] cpu_mtime_ack;
    // RTC domain: Time write acknowledge.
    logic[1:0] rtc_mtime_ack;
    
    // Timer logic.
    always @(posedge rtc_clk) begin
        rtc_mtime_ack <= 0;
        if (rtc_mtime_we[0]) begin
            rtc_mtime[31:0]  <= bus.wdata;
            rtc_mtime_ack[0] <= 1;
        end else if (rtc_mtime_we[1]) begin
            rtc_mtime[63:31] <= bus.wdata;
            rtc_mtime_ack[1] <= 1;
        end else begin
            rtc_mtime <= rtc_mtime + 1;
            irq       <= rtc_mtime > rtc_mtimecmp;
        end
    end
    
    // Domain crossing logic.
    always @(posedge clk) cpu_mtime <= rtc_mtime;
    always @(posedge clk) cpu_mtime_ack <= rtc_mtime_ack;
    always @(posedge rtc_clk) rtc_mtimecmp <= cpu_mtimecmp;
    always @(posedge rtc_clk) rtc_mtime_we <= cpu_mtime_we;
    
    // Memory-mapped access logic.
    always @(posedge clk) begin
        // Write access logic.
        if (bus.we == 15) begin
            if (!bus.ready) begin
                cpu_mtime_we        <= cpu_mtime_we & ~cpu_mtime_ack;
                bus.ready           <= cpu_mtime_we == 0 && cpu_mtime_ack == 0;
            end else if (bus.addr[31:2] == addr[31:2]) begin
                cpu_mtime_we[0]     <= 1;
                bus.ready           <= 0;
            end else if (bus.addr[31:2] == addr[31:2]+1) begin
                cpu_mtime_we[1]     <= 1;
                bus.ready           <= 0;
            end else if (bus.addr[31:2] == addr[31:2]+2) begin
                cpu_mtimecmp[31:0]  <= bus.wdata;
                bus.ready           <= 1;
            end else if (bus.addr[31:2] == addr[31:2]+3) begin
                cpu_mtimecmp[63:32] <= bus.wdata;
                bus.ready           <= 1;
            end else begin
                bus.ready           <= 1;
            end
        end else begin
            bus.ready <= 1;
        end
        // Read access logic.
        if (bus.addr[31:2] == addr[31:2]) begin
            bus.rdata <= cpu_mtime[31:0];
        end else if (bus.addr[31:2] == addr[31:2]+1) begin
            bus.rdata <= cpu_mtime[63:32];
        end else if (bus.addr[31:2] == addr[31:2]+2) begin
            bus.rdata <= cpu_mtimecmp[31:0];
        end else if (bus.addr[31:2] == addr[31:2]+3) begin
            bus.rdata <= cpu_mtimecmp[63:32];
        end else begin
            bus.rdata <= 0;
        end
    end
endmodule
