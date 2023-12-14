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



// Generic explicit divider bit.
module boa_div_part#(
    // Bit shift position of divisor.
    parameter exponent = 0,
    // Divider bit width.
    parameter width    = 32
)(
    // Unshifted divisor input.
    input  logic[width-1:0] d_divisor,
    // Remainder input.
    input  logic[width-1:0] d_remainder,
    // Result input.
    input  logic[width-1:0] d_result,
    // Remainder output.
    output logic[width-1:0] q_remainder,
    // Result output.
    output logic[width-1:0] q_result
);
    wire   divisible   = d_remainder >= (d_divisor << exponent);
    assign q_remainder = d_remainder - d_divisor * divisible;
    generate
        if (exponent > 0) begin: a
            assign q_result[exponent-1:0] = d_result[exponent-1:0];
        end
        if (exponent < width-1) begin: b
            assign q_result[width-1:exponent+1] = d_result[width-1:exponent+1];
        end
    endgenerate
    assign q_result[exponent] = divisible;
endmodule

// Uncached unsigned pipelined divider part with configurable latency.
module boa_div_part_ucpl#(
    // Number of pipeline registers, at least 1.
    parameter latency      = 1,
    // Pipeline register distribution, "begin", "end", "center" or "all".
    // "begin" and "end" place pipeline registers at their respective locations but not the opposite.
    // "center" places pipeline register throughout but not at the beginning or end.
    // "all" places pipeline registers at the beginning and end, and more in the center if latency >= 3.
    parameter distribution = "center",
    // Divider bit width.
    parameter width        = 32
)(
    // Left-hand side.
    input  logic[width-1:0] lhs,
    // Right-hand side.
    input  logic[width-1:0] rhs,
    // Division result.
    output logic[width-1:0] div_res,
    // Modulo result.
    output logic[width-1:0] mod_res
);
    // Determine whether a pipeline register is present at a given bit.
    function automatic bit has_reg(input stage);
        if (distribution == "begin") begin
        end else if (distribution == "end") begin
        end else if (distribution == "center") begin
        end else /* distribution == "all" */ begin
        end
    endfunction
    
    // Divider part remainder inputs.
    logic[width-1:0]    d_rem[width];
    // Divider part result inputs.
    logic               d_res[width];
    // Divider part remainder outputs.
    logic[width-1:0]    q_rem[width];
    // Divider part result outputs.
    logic               q_res[width];
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
