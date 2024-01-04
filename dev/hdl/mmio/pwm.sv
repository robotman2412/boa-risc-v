
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// A PWM generator intended for use with GPIO signals.
module boa_peri_pwm#(
    // Base address to respond to.
    parameter addr      = 32'h8000_0000
)(
    // CPU clock.
    input  logic        clk,
    // PWM clock.
    input  logic        pwm_clk,
    // Synchronous reset.
    input  logic        rst,
    
    // Peripheral bus.
    boa_mem_bus.MEM     bus,
    
    // PWM value.
    output logic        pwm
);
    // Configuration register.
    logic[31:0] cfg;
    boa_peri_writeable#(addr) cfg_reg(clk, rst, bus, cfg);
    wire[7:0]  pwm_val = cfg[7:0];
    wire[15:0] pwm_div = cfg[31:15];
    
    // PWM generator.
    logic[15:0] div = 1;
    logic[7:0]  val;
    always @(posedge pwm_clk) begin
        if (div == 1) begin
            div <= pwm_div ? pwm_div : 1;
            val <= val + 1;
            if (val == 0) begin
                pwm <= pwm_val != 0;
            end else if (val == pwm_val) begin
                pwm <= 0;
            end
        end else begin
            div <= div - 1;
        end
    end
endmodule
