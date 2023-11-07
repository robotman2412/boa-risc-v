/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

module top(
    input logic clk
);
    wire rst = 0;
    reg[7:0] cycle;
    always @(posedge clk) begin
        cycle <= cycle + 1;
    end
    
    boa_stage_id stage_id(
        clk, rst
    );
    
    always @(*) begin
        case (cycle)
            default: begin end
        endcase
    end
endmodule
