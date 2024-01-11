
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

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
    assign      div_res  = (rhs == 0) ? -1 : (sign_lhs ^ sign_rhs) ? neg_div : u_div;
    wire [31:0] neg_mod  = ~u_mod + 1;
    assign      mod_res  = (rhs == 0) ? lhs : sign_lhs ? neg_mod : u_mod;
endmodule



/* verilator lint_off UNOPTFLAT */
/* Also: really, verilator? */

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

// Unsigned pipelined divider with configurable latency.
module boa_udiv_pipelined#(
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
    assign res[0] = 0;
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
/* verilator lint_on UNOPTFLAT */

// Signed pipelined divider with configurable latency.
module boa_div_pipelined#(
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
    // Perform unsigned division.
    input  logic            u,
    
    // Left-hand side.
    input  logic[width-1:0] lhs,
    // Right-hand side.
    input  logic[width-1:0] rhs,
    
    // Division result.
    output logic[width-1:0] div_res,
    // Modulo result.
    output logic[width-1:0] mod_res
);
    // Correct sign of inputs.
    wire [width-1:0] neg_lhs  = ~lhs + 1;
    wire             sign_lhs = !u && lhs[31];
    wire [width-1:0] tmp_lhs  = sign_lhs ? neg_lhs : lhs;
    wire [width-1:0] neg_rhs  = ~rhs + 1;
    wire             sign_rhs = !u && rhs[31];
    wire [width-1:0] tmp_rhs  = sign_rhs ? neg_rhs : rhs;
    
    // Delegate division to the unsigned edition.
    wire [width-1:0] u_div;
    wire [width-1:0] u_mod;
    boa_udiv_pipelined#(latency, distribution, width) udiv(
        clk, tmp_lhs, tmp_rhs, u_div, u_mod
    );
    
    // The 0 divisor edge case.
    logic[latency-1:0] r_0;
    logic[latency-1:0] r_sign_l;
    logic[latency-1:0] r_sign_r;
    generate
        if (latency == 1) begin: l1
            always @(posedge clk) begin
                r_0      <= rhs == 0;
                r_sign_l <= sign_lhs;
                r_sign_r <= sign_rhs;
            end
        end else begin: l2
            always @(posedge clk) begin
                r_0      <= {r_0[latency-2:0],      rhs == 0};
                r_sign_l <= {r_sign_l[latency-2:0], sign_lhs};
                r_sign_r <= {r_sign_r[latency-2:0], sign_rhs};
            end
        end
    endgenerate
    
    // Correct sign of outputs.
    wire [width-1:0] neg_div  = ~u_div + 1;
    assign           div_res  = (r_0[latency-1]) ? -1 : (r_sign_l[latency-1] ^ r_sign_r[latency-1]) ? neg_div : u_div;
    wire [width-1:0] neg_mod  = ~u_mod + 1;
    assign           mod_res  = r_sign_l[latency-1] ? neg_mod : u_mod;
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



// Pipeline delay helper.
module boa_delay_comp#(
    // Number of delay cycles.
    parameter   delay   = 1,
    // Timer exponent.
    localparam  exp     = delay > 0 ? $clog2(delay+1) : 1
)(
    // Pipeline clock.
    input  logic    clk,
    // Delay trigger.
    input  logic    trig,
    // Wait output.
    output logic    waiting
);
    generate
        if (delay != 0) begin: l1
            // Timer register.
            logic[exp-1:0] timer = 0;
            
            // Delay logic.
            always @(posedge clk) begin
                if (trig && timer == 0) begin
                    timer <= delay;
                end else if (timer != 0) begin
                    timer <= timer - 1;
                end
            end
            assign waiting = timer != 0;
        end else begin: l0
            assign waiting = 0;
        end
    endgenerate
endmodule



// Unary to binary encoder.
module boa_unary_enc#(
    // Number of input bits.
    parameter  width = 2,
    // Number of output bits.
    localparam exp   = $clog2(width)
)(
    // Unary input.
    input  logic[width-1:0] unary,
    // Binary output.
    output logic[exp-1:0]   binary
);
    always @(*) begin
        integer i;
        binary = 0;
        for (i = 0; i < width; i = i + 1) begin
            binary |= unary[i] * i;
        end
    end
endmodule



// Selection encoder.
module boa_sel_enc#(
    // Number of inputs.
    parameter depth = 2,
    // Number of bits per input.
    parameter width = 1
)(
    // Select inputs.
    input  logic[depth-1:0] sel,
    // Value inputs.
    input  logic[width-1:0] d[depth],
    // Value output.
    output logic[width-1:0] q
);
    genvar x;
    logic[width-1:0] masked_q[depth];
    generate
        for (x = 0; x < depth; x = x + 1) begin
            assign masked_q[x] = sel[x] ? d[x] : 0;
        end
    endgenerate
    always @(*) begin
        integer i;
        q = 0;
        for (i = 0; i < depth; i = i + 1) begin
            q |= masked_q[i];
        end
    end
endmodule
