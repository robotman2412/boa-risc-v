
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`default_nettype none



// A maximal 128-bit LFSR.
module lfsr128#(
    parameter [127:0] init_value = 128'h001bb69a_baf65811_caa417d1_19362a08
)(
    input  wire         clk,
    output logic[127:0] state
);
    initial begin
        state = init_value;
    end
    // 128-bit left-shifting XNOR LFSR: 128,126,101,99
    always @(posedge clk) begin
        state[127:1] <= state[126:0];
        state[0]     <= 1 ^ state[127] ^ state[125] ^ state[100] ^ state[98];
    end
endmodule
