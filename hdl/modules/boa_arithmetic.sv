
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`default_nettype none
`include "boa_defines.svh"



// Simple zero latency multiplier.
module boa_mul_simple(
    // Left-hand side is unsigned.
    input  wire        u_lhs,
    // Right-hand side is unsigned.
    input  wire        u_rhs,
    
    // Left-hand side.
    input  wire [31:0] lhs,
    // Right-hand side.
    input  wire [31:0] rhs,
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
    input  wire         u,
    
    // Left-hand side.
    input  wire [31:0] lhs,
    // Right-hand side.
    input  wire [31:0] rhs,
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



// Cyclic divider slice.
module boa_cyc_div_part#(
    // Divider bit width.
    parameter   width   = 32,
    // Double the divider bit width.
    localparam  dwidth  = width * 2
)(
    // Current divisor position bitmask.
    input  wire [width-1:0]     pos,
    // Divisor.
    input  wire [dwidth-1:0]    div,
    
    // Remainder in.
    input  wire [width-1:0]     d_rem,
    // Result in.
    input  wire [width-1:0]     d_res,
    
    // Remainder out.
    output logic[width-1:0]     q_rem,
    // Result out.
    output logic[width-1:0]     q_res
);
    // Subtraction and comparison logic.
    wire[width:0]   sub = d_rem - div[width-1:0];
    wire            ge  = !sub[width] && div[dwidth-1:width] == 0;
    
    // Output mux.
    assign q_rem = ge ? sub : d_rem;
    assign q_res = (ge * pos) | d_res;
endmodule

// Multiple cyclic divider slices.
module boa_cyc_div_parts#(
    // Divider bit width.
    parameter   width   = 32,
    // Number of slices.
    parameter   slices  = 1,
    // Double the divider bit width.
    localparam  dwidth      = width * 2
)(
    // Current divisor position bitmask.
    input  wire [width-1:0]     pos,
    // Divisor.
    input  wire [dwidth-1:0]    div,
    
    // Remainder in.
    input  wire [width-1:0]     d_rem,
    // Result in.
    input  wire [width-1:0]     d_res,
    
    // Remainder out.
    output logic[width-1:0]     q_rem,
    // Result out.
    output logic[width-1:0]     q_res
);
    genvar x;
    
    // Remainder in.
    logic[width-1:0] d_rem_arr[slices];
    // Result in.
    logic[width-1:0] d_res_arr[slices];
    
    // Remainder out.
    logic[width-1:0] q_rem_arr[slices];
    // Result out.
    logic[width-1:0] q_res_arr[slices];
    
    generate
        // Divider slices.
        for (x = 0; x < slices; x = x + 1) begin
            boa_cyc_div_part#(width) part(
                pos >> x, div >> x,
                d_rem_arr[x], d_res_arr[x],
                q_rem_arr[x], q_res_arr[x]
            );
        end
        // Slice interconnects.
        assign d_rem_arr[0] = d_rem;
        assign d_res_arr[0] = d_res;
        for (x = 0; x < slices - 1; x = x + 1) begin
            assign d_rem_arr[x+1] = q_rem_arr[x];
            assign d_res_arr[x+1] = q_res_arr[x];
        end
        assign q_rem = q_rem_arr[slices-1];
        assign q_res = q_res_arr[slices-1];
    endgenerate
endmodule

// Signed cyclic divider with configurable delay.
module boa_div_cyclic#(
    // Number of cycles division takes, at least 1.
    parameter   delay       = 8,
    // Divider bit width.
    parameter   width       = 32,
    // Number of slices required.
    localparam  slices      = (width - 1) / delay + 1,
    // Double the divider bit width.
    localparam  dwidth      = width * 2
)(
    // Cycle clock.
    input  wire             clk,
    // Input latch.
    input  wire             latch,
    // Perform unsigned division.
    input  wire             u,
    
    // Left-hand side.
    input  wire [width-1:0] lhs,
    // Right-hand side.
    input  wire [width-1:0] rhs,
    
    // Division result.
    output logic[width-1:0] div_res,
    // Modulo result.
    output logic[width-1:0] mod_res
);
    // Correct sign of inputs.
    wire [width-1:0]    neg_lhs  = ~lhs + 1;
    wire                sign_lhs = !u && lhs[width-1];
    wire [width-1:0]    tmp_lhs  = sign_lhs ? neg_lhs : lhs;
    wire [width-1:0]    neg_rhs  = ~rhs + 1;
    wire                sign_rhs = !u && rhs[width-1];
    wire [width-1:0]    tmp_rhs  = sign_rhs ? neg_rhs : rhs;
    
    logic sign_lhs_reg, sign_rhs_reg;
    
    // Divisor was zero register.
    logic               zero_reg;
    // Divisor register.
    logic[dwidth-1:0]   div_reg;
    // Exponent register.
    logic[width-1:0]    pos_reg;
    // Remainder register.
    logic[width-1:0]    rem_reg;
    // Result register.
    logic[width-1:0]    res_reg;
    
    // Divider slices.
    logic[width-1:0]    q_rem, q_res;
    boa_cyc_div_parts#(width, slices) parts(pos_reg, div_reg, rem_reg, res_reg, q_rem, q_res);
    
    // Latching logic.
    always @(posedge clk) begin
        if (latch) begin
            zero_reg            <= tmp_rhs == 0;
            div_reg             <= tmp_rhs << (width-1);
            pos_reg[width-1]    <= 1;
            pos_reg[width-2:0]  <= 0;
            rem_reg             <= tmp_lhs;
            res_reg             <= 0;
            sign_lhs_reg        <= sign_lhs;
            sign_rhs_reg        <= sign_rhs;
        end else begin
            div_reg             <= div_reg >> slices;
            pos_reg             <= pos_reg >> slices;
            rem_reg             <= q_rem;
            res_reg             <= q_res;
        end
    end
    wire [width-1:0] u_div = q_res;
    wire [width-1:0] u_mod = q_rem;
    
    // Correct sign of outputs.
    wire [width-1:0]    neg_div  = ~u_div + 1;
    assign              div_res  = zero_reg ? -1 : (sign_lhs_reg ^ sign_rhs_reg) ? neg_div : u_div;
    wire [width-1:0]    neg_mod  = ~u_mod + 1;
    assign              mod_res  = sign_lhs_reg ? neg_mod : u_mod;
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
    input  wire             clk,
    
    // Unshifted divisor input.
    input  wire [width-1:0] d_divisor,
    // Remainder input.
    input  wire [width-1:0] d_remainder,
    // Result input.
    input  wire [width-1:0] d_result,
    
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
    input  wire             clk,
    
    // Left-hand side.
    input  wire [width-1:0] lhs,
    // Right-hand side.
    input  wire [width-1:0] rhs,
    
    // Division result.
    output logic[width-1:0] div_res,
    // Modulo result.
    output logic[width-1:0] mod_res
);
    genvar x;
    
    // Determine whether a pipeline register is present at a given bit.
    function automatic bit has_reg(input integer stage);
        integer i0, i1, y;
        real count, spacing, tally;
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
        if (count < 1) return 0;
        spacing = count / (i1 - i0 + 1);
        tally   = 0;
        for (y = 0; y < width; y = y + 1) begin
            tally = tally + spacing;
            if (tally >= 0.5 && count > 0) begin
                tally = tally - 1;
                count = count - 1;
                if (y == stage) begin
                    return 1;
                end
            end
        end
        return 0;
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
    input  wire             clk,
    // Perform unsigned division.
    input  wire             u,
    
    // Left-hand side.
    input  wire [width-1:0] lhs,
    // Right-hand side.
    input  wire [width-1:0] rhs,
    
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
    input  wire                 arith,
    // Shift right instead of left.
    input  wire                 shr,
    
    // Left-hand side.
    input  wire  signed[31:0]   lhs,
    // Right-hand side.
    input  wire        [31:0]   rhs,
    // Bit shift result.
    output logic signed[31:0]   res
);
    assign              res  = shr ? arith ? (lhs >>> rhs[4:0]) : (lhs >> rhs[4:0]) : (lhs << rhs[4:0]);
endmodule
