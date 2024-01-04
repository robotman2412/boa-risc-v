
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps

module param_clk_div#(
    parameter fast_hz = 1000000,
    parameter slow_hz = 9600*4
)(
    input  logic clk_fast,
    output logic clk_slow
);
    generate
        if (slow_hz > fast_hz) begin: gt
            $error("slow_hz must be less than or equal to fast_hz");
        end else if (slow_hz == fast_hz) begin: eq
            assign clk_slow = clk_fast;
        end else begin: lt
            localparam div = fast_hz / slow_hz;
            localparam exp = $clog2(div-1)-1;
            logic[exp:0] div_reg;
            always @(posedge clk_fast) begin
                if (div_reg == div/2) begin
                    clk_slow <= 1;
                end
                if (div_reg == div-1) begin
                    div_reg <= 0;
                    clk_slow <= 0;
                end else begin
                    div_reg <= div_reg + 1;
                end
            end
        end
    endgenerate
endmodule
