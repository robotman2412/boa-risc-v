/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial-ShareAlike 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc-sa/4.0/
*/

`include "boa_defines.sv"



// Boa³² pipline stage: ID (instruction decode).
module boa_stage_id(
    // CPU clock.
    input  logic        clk,
    // Synchronous reset.
    input  logic        rst,
    
    // Program memory bus.
    boa_mem_bus.CPU     pbus,
    
    
    // IF/ID: Result valid.
    input  logic        d_valid,
    // IF/ID: Current instruction PC.
    input  logic[31:2]  d_pc,
    // IF/ID: Current instruction word.
    input  logic[31:0]  d_insn,
    
    
    // ID/IF: Branch predicted.
    output logic        id_branch_predict,
    // ID/IF: Branch target address.
    output logic[31:2]  id_branch_target,
    
    // Stall ID stage.
    input  logic        fw_stall_id,
    // Stall EX stage.
    input  logic        fw_stall_ex
);
endmodule
