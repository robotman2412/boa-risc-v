/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

`include "boa_defines.svh"



// Boa³² pipline stage: IF (instruction fetch).
module boa_stage_if#(
    // Entrypoint address.
    parameter entrypoint    = 32'h4000_0000
)(
    // CPU clock.
    input  logic        clk,
    // Synchronous reset.
    input  logic        rst,
    
    // Program memory bus.
    boa_mem_bus.CPU     pbus,
    
    
    // IF/ID: Result valid.
    output logic        q_valid,
    // IF/ID: Current instruction PC.
    output logic[31:1]  q_pc,
    // IF/ID: Current instruction word.
    output logic[31:0]  q_insn,
    // IF/ID: Trap raised.
    output logic        q_trap,
    // IF/ID: Trap cause.
    output logic[3:0]   q_cause,
    
    
    // ID/IF: Branch predicted.
    input  logic        id_branch_predict,
    // ID/IF: Branch target address.
    input  logic[31:1]  id_branch_target,
    
    // Stall IF stage.
    input  logic        fw_stall_if,
    // Stall ID stage.
    input  logic        fw_stall_id,
    // Branch to be corrected.
    input  logic        fw_branch_correct,
    // Branch correction address.
    input  logic[31:1]  fw_branch_alt
);
    // Next instruction to load.
    logic[31:1] pc      = entrypoint;
    // Next memory read is valid.
    logic       valid   = 0;
    
    // Program bus logic.
    assign pbus.re      = !fw_stall_if;
    assign pbus.we      = 0;
    assign pbus.addr    = pc;
    
    // Pipeline barrier logic.
    assign q_insn       = pbus.rdata;
    assign q_valid      = valid && pbus.ready && !q_trap;
    always @(posedge clk) q_pc <= pc;
    assign q_trap       = valid && q_pc[1];
    assign q_cause      = `RV_ECAUSE_IALIGN;
    
    always @(posedge clk) begin
        q_pc <= pc;
        if (rst) begin
            pc      <= entrypoint;
            valid   <= 0;
        end else if(!fw_stall_if) begin
            if (fw_branch_correct) begin
                pc      <= fw_branch_alt;
                valid <= 0;
            end else if (id_branch_predict) begin
                pc      <= id_branch_target;
                valid   <= 0;
            end else if (!pbus.ready) begin
                valid   <= 0;
            end else begin
                pc      <= pc + 4;
                valid   <= 1;
            end
        end else begin
            valid <= valid && fw_stall_id;
        end
    end
endmodule
