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
    // Invalidate results and clear traps.
    input  logic        clear,
    
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
    
    
    // Unconditional control transfer or branch predicted as taken.
    input  logic        fw_branch_predict,
    // Branch target address.
    input  logic[31:1]  fw_branch_target,
    // Address of the next instruction.
    output logic[31:1]  if_next_pc,
    
    // Stall IF stage.
    input  logic        fw_stall_if,
    // Branch to be corrected.
    input  logic        fw_branch_correct,
    // Branch correction address.
    input  logic[31:1]  fw_branch_alt
);
    // Current program counter.
    logic[31:1] pc      = entrypoint;
    assign if_next_pc = pc;
    // Next program counter.
    logic[31:1] next_pc;
    assign next_pc[31:1] = pc[31:1] + pbus.ready*2;
    // Next memory read is valid.
    logic       valid   = 0;
    
    // Program bus logic.
    assign pbus.re          = !fw_stall_if;
    assign pbus.we          = 0;
    always @(*) begin
        if (fw_branch_correct) begin
            pbus.addr[31:2] = fw_branch_alt[31:2];
        end else if (fw_branch_predict) begin
            pbus.addr[31:2] = fw_branch_target[31:2];
        end else if (pbus.ready) begin
            pbus.addr[31:2] = next_pc[31:2];
        end else begin
            pbus.addr[31:2] = pc[31:2];
        end
    end
    
    // Pipeline output logic.
    assign q_valid  = valid && !q_pc[1];
    assign q_trap   = valid && q_pc[1];
    assign q_cause  = `RV_ECAUSE_IALIGN;
    
    assign valid    = pbus.ready && !fw_branch_predict && !fw_branch_correct && !clear;
    assign q_insn   = pbus.rdata;
    always @(posedge clk) begin
        if (rst) begin
            pc[31:1]    <= entrypoint[31:1];
        end else if(!fw_stall_if) begin
            pc[31:2]    <= pbus.addr[31:2];
            pc[1]       <= 0;
        end
    end
    
    // always @(posedge clk) begin
    //     q_pc <= pc;
    //     if (rst) begin
    //         pc[31:1]    <= entrypoint[31:1];
    //         valid       <= 0;
    //     end else if(!fw_stall_if) begin
    //         valid       <= pbus.ready && !fw_branch_predict && !fw_branch_correct && !clear;
    //         pc[31:2]    <= pbus.addr[31:2];
    //         pc[1]       <= 0;
    //         q_insn      <= pbus.rdata;
    //     end else begin
    //         valid       <= valid && fw_stall_id;
    //     end
    // end
endmodule
