/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

`timescale 1ns/1ps
`include "boa_defines.svh"



// Simple zero latency multiplier.
module boa_mul_simple(
    // Left-hand side is unsigned.
    input  logic       u_lhs,
    // Right-hand side is unsigned.
    input  logic       u_rhs,
    
    // Left-hand side.
    input  logic[31:0] lhs,
    // Right-hand side.
    input  logic[31:0] rhs,
    // Multiplication result.
    output logic[63:0] res
);
    // Expand inputs to 64-bit.
    logic[63:0] tmp_lhs;
    assign tmp_lhs[31:0]  = lhs;
    assign tmp_lhs[63:32] = u_lhs ? 0 : lhs[31] * 32'hffff_ffff;
    logic[63:0] tmp_rhs;
    assign tmp_rhs[31:0]  = rhs;
    assign tmp_rhs[63:32] = u_rhs ? 0 : rhs[31] * 32'hffff_ffff;
    
    // Have the synthesizer figure out the multiplier for us.
    assign res = tmp_lhs * tmp_rhs;
endmodule



// Multiple-adder configurable pipelined multiplier.
module boa_mul_addpl#(
    // Number of pipeline stages, at least 2.
    parameter stages = 2
)(
    // CPU clock.
    input  logic       clk,
    
    // Left-hand side is unsigned.
    input  logic       u_lhs,
    // Right-hand side is unsigned.
    input  logic       u_rhs,
    
    // Left-hand side.
    input  logic[31:0] lhs,
    // Right-hand side.
    input  logic[31:0] rhs,
    // Multiplication result.
    output logic[63:0] res
);
    // Expand inputs to 64-bit.
    logic[63:0] tmp_lhs;
    assign tmp_lhs[31:0]  = lhs;
    assign tmp_lhs[63:32] = u_lhs ? 0 : lhs[31] * 32'hffff_ffff;
    logic[63:0] tmp_rhs;
    assign tmp_rhs[31:0]  = rhs;
    assign tmp_rhs[63:32] = u_rhs ? 0 : rhs[31] * 32'hffff_ffff;
    
endmodule



// Simple zero latency divider.
module boa_div_simple(
    // Perform unsigned division.
    input  logic        u,
    
    // Left-hand side.
    input  logic[31:0] lhs,
    // Right-hand side.
    input  logic[31:0] rhs,
    // Division result.
    output logic[31:0] div_res,
    // Modulo result.
    output logic[31:0] mod_res
);
    // Correct sign of inputs.
    wire [31:0] neg_lhs  = ~lhs + 1;
    wire        sign_lhs = !u && lhs[31];
    wire [31:0] tmp_lhs  = sign_lhs ? neg_lhs : lhs;
    wire [31:0] neg_rhs  = ~rhs + 1;
    wire        sign_rhs = !u && rhs[31];
    wire [31:0] tmp_rhs  = sign_rhs ? neg_rhs : rhs;
    
    // Have the synthesizer figure out the divider for us.
    wire [31:0] u_div    = tmp_lhs / tmp_rhs;
    wire [31:0] u_mod    = tmp_lhs % tmp_rhs;
    
    // Correct sign of outputs.
    wire [31:0] neg_div  = ~u_div + 1;
    assign      div_res  = sign_lhs ^ sign_rhs ? neg_div : u_div;
    wire [31:0] neg_mod  = ~u_mod + 1;
    assign      mod_res  = sign_lhs ? neg_mod : u_mod;
endmodule



// Simple zero latency bit shifter.
module boa_shift_simple(
    // Shift arithmetic.
    input  logic                arith,
    // Shift right instead of left.
    input  logic                shr,
    
    // Left-hand side.
    input  logic signed[31:0]   lhs,
    // Right-hand side.
    input  logic       [31:0]   rhs,
    // Bit shift result.
    output logic signed[31:0]   res
);
    assign              res  = shr ? arith ? (lhs >>> rhs[4:0]) : (lhs >> rhs[4:0]) : (lhs << rhs[4:0]);
endmodule
