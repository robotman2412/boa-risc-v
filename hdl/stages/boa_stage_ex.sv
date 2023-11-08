/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

`include "boa_defines.sv"



// Boa³² pipline stage: EX (ALU and address calculation).
module boa_stage_ex(
    // CPU clock.
    input  logic        clk,
    // Synchronous reset.
    input  logic        rst,
    
    
    // ID/EX: Result valid.
    input  logic        d_valid,
    // ID/EX: Current instruction PC.
    input  logic[31:1]  d_pc,
    // ID/EX: Current instruction word.
    input  logic[31:0]  d_insn,
    // ID/EX: Stores to register RD.
    input  logic        d_use_rd,
    // ID/EX: Value from RS1 register.
    input  logic[31:0]  d_rs1_val,
    // ID/EX: Value from RS2 register.
    input  logic[31:0]  d_rs2_val,
    // ID/EX: Conditional branch.
    input  logic        d_branch,
    // ID/EX: Branch prediction result.
    input  logic        d_branch_predict,
    // ID/EX: Trap raised.
    input  logic        d_trap,
    // ID/EX: Trap cause.
    input  logic[3:0]   d_cause,
    
    
    // ID/EX: Result valid.
    output logic        q_valid,
    // ID/EX: Current instruction PC.
    output logic[31:1]  q_pc,
    // ID/EX: Current instruction word.
    output logic[31:0]  q_insn,
    // ID/EX: Stores to register RD.
    output logic        q_use_rd,
    // ID/EX: Value from RS1 register / ALU result / memory address.
    output logic[31:0]  q_rs1_val,
    // ID/EX: Value from RS2 register / memory write data.
    output logic[31:0]  q_rs2_val,
    // ID/EX: Trap raised.
    output logic        q_trap,
    // ID/EX: Trap cause.
    output logic[3:0]   q_cause,
    
    
    // Stall EX stage.
    input  logic        fw_stall_ex,
    // Stall MEM stage.
    input  logic        fw_stall_mem
);
    // Pipeline barrier logic.
    always @(posedge clk) begin
        if (rst) begin
            q_valid             <= 0;
            q_pc                <= 'bx;
            q_insn              <= 'bx;
            q_use_rd            <= 'bx;
            q_rs1_val           <= 'bx;
            q_rs2_val           <= 'bx;
            q_branch            <= 'bx;
            q_branch_predict    <= 'bx;
            q_trap              <= 0;
            q_cause             <= 'bx;
        end else if (!fw_stall_id) begin
            q_valid             <= d_valid && insn_valid && insn_legal;
            q_pc                <= d_pc;
            q_insn              <= d_insn;
            q_use_rd            <= has_rd;
            q_rs1_val           <= rs1_val;
            q_rs2_val           <= rs2_val;
            q_branch            <= is_branch;
            q_branch_predict    <= branch_predict;
            q_trap              <= d_trap || d_valid && (!insn_valid || !insn_legal);
            q_cause             <= d_trap ? d_cause : `RV_ECAUSE_IILLEGAL;
        end else begin
            q_valid <= q_valid && !fw_stall_ex;
        end
    end
endmodule
