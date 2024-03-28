
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`default_nettype none
`include "boa_defines.svh"



// Pipeline delay helper.
module boa_delay_comp#(
    // Number of delay cycles.
    parameter   delay   = 1,
    // Timer exponent.
    localparam  exp     = delay > 0 ? $clog2(delay+1) : 1
)(
    // Pipeline clock.
    input  wire     clk,
    // Delay trigger.
    input  wire     trig,
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
    input  wire [width-1:0] unary,
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
    input  wire [depth-1:0] sel,
    // Value inputs.
    input  wire [width-1:0] d[depth],
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



// Clock synchronization detector.
// The two clocks must have an integer multiplier between them.
module boa_clk_sync#(
    // Number of clock divider bits.
    parameter   integer div_len = 2
)(
    // Slow clock.
    input  wire                 clk_slow,
    // Fast clock.
    input  wire                 clk_fast,
    // Current division factor minus one.
    input  wire [div_len-1:0]   division,
    // Detected clock phase.
    output logic[div_len-1:0]   phase,
    // Clock sync detected.
    output logic                sync
);
    logic pclk_slow;
    always @(posedge clk_fast) begin
        pclk_slow <= clk_slow;
        if (clk_slow && !pclk_slow) begin
            sync  <= phase == 1;
            phase <= 1;
        end else if (phase == division) begin
            phase <= 0;
        end else begin
            phase <= phase + 1;
        end
    end
endmodule
