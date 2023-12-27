
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

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
    parameter exponent  = 0,
    // Divider bit width.
    parameter width     = 32,
    // Whether this stage has a pipeline register at the input.
    parameter has_reg   = 0
)(
    // Clock (unused if not pipelined).
    input  logic            clk,
    
    // Unshifted divisor input.
    input  logic[width-1:0] d_divisor,
    // Remainder input.
    input  logic[width-1:0] d_remainder,
    // Result input.
    input  logic[width-1:0] d_result,
    
    // Divisor output.
    output logic[width-1:0] q_divisor,
    // Remainder output.
    output logic[width-1:0] q_remainder,
    // Result output.
    output logic[width-1:0] q_result
);
    // Unshifted divisor input.
    logic[width*2-1:0] r_divisor;
    // Remainder input.
    logic[width-1:0] r_remainder;
    // Result input.
    logic[width-1:0] r_result;
    
    // Pipeline register.
    generate
        if (has_reg) begin: pipelined
            always @(posedge clk) begin
                r_divisor   <= d_divisor;
                r_remainder <= d_remainder;
                r_result    <= d_result;
            end
        end else begin: passive
            assign r_divisor   = d_divisor;
            assign r_remainder = d_remainder;
            assign r_result    = d_result;
        end
    endgenerate
    
    // Subtraction logic.
    wire   divisible   = r_remainder >= (r_divisor << exponent);
    assign q_remainder = r_remainder - (r_divisor << exponent) * divisible;
    generate
        if (exponent > 0) begin: a
            assign q_result[exponent-1:0] = r_result[exponent-1:0];
        end
        if (exponent < width-1) begin: b
            assign q_result[width-1:exponent+1] = r_result[width-1:exponent+1];
        end
    endgenerate
    assign q_result[exponent] = divisible;
    assign q_divisor = r_divisor;
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
    // Pipeline clock.
    input  logic            clk,
    
    // Left-hand side.
    input  logic[width-1:0] lhs,
    // Right-hand side.
    input  logic[width-1:0] rhs,
    
    // Division result.
    output logic[width-1:0] div_res,
    // Modulo result.
    output logic[width-1:0] mod_res
);
    genvar x;
    
    // Determine whether a pipeline register is present at a given bit.
    function automatic bit has_reg(input integer stage);
        integer i0, i1, count, spacing;
        if (distribution == "begin") begin
            i0 = 1; i1 = width;   count = latency-1;
            if (stage == 0) return 1;
        end else if (distribution == "end") begin
            i0 = 0; i1 = width-1; count = latency-1;
            if (stage == width) return 1;
        end else if (distribution == "center") begin
            i0 = 0; i1 = width;   count = latency;
        end else /* distribution == "all" */ begin
            i0 = 1; i1 = width-1; count = latency-2;
            if (stage == 0 || stage == width) return 1;
        end
        if (count <= 0) return 0;
        spacing = (i1 - i0 + 1) / count;
        return (stage-i0+spacing/2) % spacing == 0;
    endfunction
    
    // Divisors.
    logic[width-1:0]    div[width+1];
    // Remainders.
    logic[width-1:0]    rem[width+1];
    // Division results.
    logic[width-1:0]    res[width+1];
    
    // Pipelined divider generator.
    assign div[0] = rhs;
    assign rem[0] = lhs;
    generate
        for (x = 0; x < width; x = x + 1) begin
            boa_div_part#(width-x-1, width, has_reg(x)) part(
                clk,
                div[x],   rem[x],   res[x],
                div[x+1], rem[x+1], res[x+1]
            );
        end
    endgenerate
    
    // Output logic.
    generate
        if (has_reg(width)) begin: pipelined
            always @(posedge clk) begin
                div_res <= res[width];
                mod_res <= rem[width];
            end
        end else begin: passive
            assign div_res = res[width];
            assign mod_res = rem[width];
        end
    endgenerate
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
