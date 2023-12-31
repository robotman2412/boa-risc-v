
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Abstract phase locked loop.
// fout = fin * fb_div / out_div
module param_pll#(
    // Input clock frequency in hertz.
    parameter in_freq = 12000000,
    // Division factor for the PLL feedback divider.
    parameter fb_div  = 5,
    // Division factor for the output clock.
    parameter out_div = 1
)(
    input  logic clk_in,
    output logic clk_out
);
    logic clk_div;
    always @(posedge clk_in) clk_div <= !clk_div;
    logic clk_fb;
    PLLE2_BASE#(
        .CLKIN1_PERIOD(500000000.000 / in_freq),
        .CLKFBOUT_MULT(fb_div),
        .CLKOUT0_DIVIDE(out_div)
    ) pll (
        .CLKFBOUT(clk_fb),
        .CLKOUT0(clk_out),
        .CLKOUT1(),
        .CLKOUT2(),
        .CLKOUT3(),
        .CLKOUT4(),
        .CLKOUT5(),
        .LOCKED(),
        .CLKFBIN(clk_fb),
        .CLKIN1(clk_div),
        .PWRDWN(0),
        .RST(0)
    );
endmodule
