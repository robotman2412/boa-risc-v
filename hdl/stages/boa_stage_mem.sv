/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

`include "boa_defines.svh"



// Boa³² pipline stage: MEM (memory and CSR access).
module boa_stage_mem(
    // CPU clock.
    input  logic        clk,
    // Synchronous reset.
    input  logic        rst,
    // Invalidate results and clear traps.
    input  logic        clear,
    
    // Data memory bus.
    boa_mem_bus.CPU     dbus,
    
    
    // EX/MEM: Result valid.
    input  logic        d_valid,
    // EX/MEM: Current instruction PC.
    input  logic[31:1]  d_pc,
    // EX/MEM: Current instruction word.
    input  logic[31:0]  d_insn,
    // EX/MEM: Stores to register RD.
    input  logic        d_use_rd,
    // EX/MEM: Value from RS1 register / ALU result / memory address.
    input  logic[31:0]  d_rs1_val,
    // EX/MEM: Value from RS2 register / memory write data.
    input  logic[31:0]  d_rs2_val,
    // EX/MEM: Trap raised.
    input  logic        d_trap,
    // EX/MEM: Trap cause.
    input  logic[3:0]   d_cause,
    
    
    // MEM/WB: Result valid.
    output logic        q_valid,
    // MEM/WB: Current instruction PC.
    output logic[31:1]  q_pc,
    // MEM/WB: Current instruction word.
    output logic[31:0]  q_insn,
    // MEM/WB: Stores to register RD.
    output logic        q_use_rd,
    // MEM/WB: Value to store to register RD.
    output logic[31:0]  q_rd_val,
    // MEM/WB: Trap raised.
    output logic        q_trap,
    // MEM/WB: Trap cause.
    output logic[3:0]   q_cause,
    
    
    // Stall MEM stage.
    input  logic        fw_stall_mem
);
    // EX/MEM: Result valid.
    logic       r_valid;
    // EX/MEM: Current instruction PC.
    logic[31:1] r_pc;
    // EX/MEM: Current instruction word.
    logic[31:0] r_insn;
    // EX/MEM: Stores to register RD.
    logic       r_use_rd;
    // EX/MEM: Value from RS1 register / ALU result / memory address.
    logic[31:0] r_rs1_val;
    // EX/MEM: Value from RS2 register / memory write data.
    logic[31:0] r_rs2_val;
    // EX/MEM: Trap raised.
    logic       r_trap;
    // EX/MEM: Trap cause.
    logic[3:0]  r_cause;
    
    // Pipeline barrier register.
    always @(posedge clk) begin
        if (rst) begin
            r_valid     <= 0;
            r_pc        <= 'bx;
            r_insn      <= 'bx;
            r_use_rd    <= 'bx;
            r_rs1_val   <= 'bx;
            r_rs2_val   <= 'bx;
            r_trap      <= 0;
            r_cause     <= 'bx;
        end else if (!fw_stall_mem) begin
            r_valid     <= d_valid;
            r_pc        <= d_pc;
            r_insn      <= d_insn;
            r_use_rd    <= d_use_rd;
            r_rs1_val   <= d_rs1_val;
            r_rs2_val   <= d_rs2_val;
            r_trap      <= d_trap;
            r_cause     <= d_cause;
        end
    end
    
    
    // Is it a LOAD or STORE instruction?
    wire is_mem = (r_insn[6:2] == `RV_OP_LOAD) || (r_insn[6:2] == `RV_OP_STORE);
    // Is it a CSR access instruction?
    wire is_csr = 0;
    
    // Raise a trap.
    logic      trap;
    // Trap cause.
    logic[3:0] cause;
    assign trap  = 0;
    assign cause = 0;
    
    // Pipeline barrier logic.
    assign  q_valid     = r_valid && !trap && !clear;
    assign  q_pc        = r_pc;
    assign  q_insn      = r_insn;
    assign  q_use_rd    = r_use_rd;
    assign  q_rd_val    = r_rs1_val;
    assign  q_trap      = (r_trap || trap) && !clear;
    assign  q_cause     = r_trap ? r_cause : cause;
    
    // always @(posedge clk) begin
    //     if (rst) begin
    //         q_valid             <= 0;
    //         q_pc                <= 'bx;
    //         q_insn              <= 'bx;
    //         q_use_rd            <= 'bx;
    //         q_rd_val            <= 'bx;
    //         q_trap              <= 0;
    //         q_cause             <= 'bx;
    //     end else if (!fw_stall_mem) begin
    //         q_valid             <= d_valid && !trap;
    //         q_pc                <= d_pc;
    //         q_insn              <= d_insn;
    //         q_use_rd            <= d_use_rd;
    //         q_rd_val            <= d_rs1_val;
    //         q_trap              <= d_trap || trap;
    //         q_cause             <= d_trap ? d_cause : cause;
    //     end else begin
    //         q_valid             <= 0;
    //     end
    // end
endmodule

// Boa³² pipline stage forwarding helper: MEM (memory and CSR access).
module boa_stage_mem_fw(
    // Current instruction word.
    input  logic[31:0]  d_insn,
    
    // Uses value of RS1.
    output logic        use_rs1,
    // Uses value of RS2.
    output logic        use_rs2
);
    // Usage calculator.
    always @(*) begin
        if (d_insn[6:2] == `RV_OP_LOAD) begin
            // LOAD instructions.
            // RS1 not used because EX calculates the address.
            use_rs1 = 0;
            use_rs2 = 0;
        end else if (d_insn[6:2] == `RV_OP_STORE) begin
            // STORE instructions.
            // RS1 not used because EX calculates the address.
            use_rs1 = 0;
            use_rs2 = 1;
        end else if (d_insn[6:2] == `RV_OP_SYSTEM) begin
            // SYSTEM instructions.
            if (d_insn[14:12] == 0) begin
                // Other SYSTEM instructions.
                use_rs1 = 0;
                use_rs2 = 0;
            end else if (d_insn[14]) begin
                // CSR*I instructions.
                use_rs1 = 1;
                use_rs2 = 0;
            end else begin
                // CSR* instructions.
                use_rs1 = 0;
                use_rs2 = 0;
            end
        end else begin
            // Other instructions.
            use_rs1 = 0;
            use_rs2 = 0;
        end
    end
endmodule
