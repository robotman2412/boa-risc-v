/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial-ShareAlike 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc-sa/4.0/
*/

module top(
    input logic clk
);
    wire rst = 0;
    
    reg[7:0] cycle;
    
    reg[31:2] addr_reg;
    boa_mem_bus pbus();
    assign pbus.ready = 1;
    always @(posedge clk) addr_reg <= pbus.addr;
    always @(negedge clk) pbus.rdata <= addr_reg;
    
    wire       b_if_id_valid;
    wire[31:1] b_if_id_pc;
    wire[31:0] b_if_id_insn;
    wire       b_if_id_trap;
    wire[3:0]  b_if_id_cause;
    logic id_branch_predict;
    logic[31:1] id_branch_target;
    logic fw_stall_if;
    logic fw_stall_id;
    logic fw_branch_correct;
    logic[31:1] fw_branch_alt;
    boa_stage_if stage_if(
        clk, rst, pbus,
        b_if_id_valid, b_if_id_pc, b_if_id_insn,
        id_branch_predict, id_branch_target,
        fw_stall_if, fw_stall_id, fw_branch_correct, fw_branch_alt
    );
    
    always @(posedge clk) begin
        cycle <= cycle + 1;
    end
    
    always @(*) begin
        case (cycle)
            default: begin id_branch_predict = 0; id_branch_target = 32'h0000_0000; fw_stall_if = 0; fw_stall_id = 0; fw_branch_correct = 0; fw_branch_alt = 32'h0000_0000; end
            5:  begin id_branch_predict = 1; id_branch_target = 32'hdead_beef; fw_stall_if = 0; fw_stall_id = 0; fw_branch_correct = 0; fw_branch_alt = 32'h0000_0000; end
            6:  begin id_branch_predict = 0; id_branch_target = 32'h0000_0000; fw_stall_if = 0; fw_stall_id = 0; fw_branch_correct = 1; fw_branch_alt = 32'hcafe_babe; end
            8:  begin id_branch_predict = 1; id_branch_target = 32'hbaad_f00d; fw_stall_if = 0; fw_stall_id = 0; fw_branch_correct = 0; fw_branch_alt = 32'h0000_0000; end
            11: begin id_branch_predict = 0; id_branch_target = 32'h0000_0000; fw_stall_if = 1; fw_stall_id = 0; fw_branch_correct = 0; fw_branch_alt = 32'h0000_0000; end
            14: begin id_branch_predict = 0; id_branch_target = 32'h0000_0000; fw_stall_if = 1; fw_stall_id = 1; fw_branch_correct = 0; fw_branch_alt = 32'h0000_0000; end
        endcase
    end
endmodule
