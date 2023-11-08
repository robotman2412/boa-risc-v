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
    
    // IF/ID: Result valid.
    logic        d_valid;
    // IF/ID: Current instruction PC.
    logic[31:2]  d_pc;
    // IF/ID: Current instruction word.
    logic[31:0]  d_insn;
    // IF/ID: Trap raised.
    logic        d_trap;
    // IF/ID: Trap cause.
    logic[3:0]   d_cause;
    
    // ID/EX: Result valid.
    logic        q_valid;
    // ID/EX: Current instruction PC.
    logic[31:1]  q_pc;
    // ID/EX: Current instruction word.
    logic[31:0]  q_insn;
    // ID/EX: Stores to register RD.
    logic        q_use_rd;
    // ID/EX: Value from RS1 register.
    logic[31:0]  q_rs1_val;
    // ID/EX: Value from RS2 register.
    logic[31:0]  q_rs2_val;
    // ID/EX: Conditional branch.
    logic        q_branch;
    // ID/EX: Branch prediction result.
    logic        q_branch_predict;
    // ID/EX: Trap raised.
    logic        q_trap;
    // ID/EX: Trap cause.
    logic[3:0]   q_cause;
    
    // MRET or SRET instruction.
    logic        is_xret;
    // Is SRET instead of MRET.
    logic        is_sret;
    // Unconditional jump.
    logic        is_jump;
    // Conditional branch.
    logic        is_branch;
    // Branch predicted.
    logic        branch_predict;
    // Branch target address.
    logic[31:1]  branch_target;
    
    // Stall ID stage.
    logic        fw_stall_id;
    // Stall EX stage.
    logic        fw_stall_ex;
    
    boa_stage_id stage_id(
        clk, rst,
        d_valid, d_pc, d_insn, d_trap, d_cause,
        q_valid, q_pc, q_insn, q_use_rd, q_rs1_val, q_rs2_val, q_branch, q_branch_predict, q_trap, q_cause,
        is_xret, is_sret, is_jump, is_branch, branch_predict, branch_target,
        0, 0, 0,
        fw_stall_id, fw_stall_ex
    );
    
    always @(*) begin
        case (cycle)
            default: begin d_valid = 0; d_pc = 0; d_insn = 0; d_trap = 0; d_cause = 0; fw_stall_id = 0; fw_stall_ex = 0; end
            
            0: begin d_valid = 1; d_pc = 0; d_insn = 32'h0000106f; d_trap = 0; d_cause = 0; fw_stall_id = 0; fw_stall_ex = 0; end
            1: begin d_valid = 1; d_pc = 2; d_insn = 32'h00900093; d_trap = 0; d_cause = 0; fw_stall_id = 0; fw_stall_ex = 0; end
            2: begin d_valid = 1; d_pc = 4; d_insn = 32'h00001463; d_trap = 0; d_cause = 0; fw_stall_id = 0; fw_stall_ex = 0; end
            4: begin d_valid = 1; d_pc = 6; d_insn = 32'h7fd0006f; d_trap = 0; d_cause = 0; fw_stall_id = 0; fw_stall_ex = 0; end
        endcase
    end
endmodule
