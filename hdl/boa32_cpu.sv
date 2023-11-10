/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

`include "boa_defines.svh"



/*
    Boa³² RV32IM_Zicsr processor.
    
    Pipeline:   5 stages (IF, ID, EX, MEM, WB)
    IPC:        t.b.d.
    Interrupts: 16 external, 1 internal
    Privileges: M-mode
    
    Implemented CSRs:
        0x300   mstatus
        0x301   misa        (RV32IM)
        0x302   medeleg     (0)
        0x303   mideleg     (0)
        0x304   mie
        0x305   mtvec
        0x310   mstatush    (0)
        
        0x344   mip
        0x340   mscratch
        0x341   mepc
        0x342   mcause
        0x343   mtval       (0)
        
        0xf11   mvendorid   (0)
        0xf12   marchid     (0)
        0xf13   mipid       (0)
        0xf14   mhartid     (parameter)
        0xf15   mconfigptr  (0)
*/
module boa32_cpu#(
    // Entrypoint address.
    parameter entrypoint    = 32'h4000_0000,
    // CSR mhartid value.
    parameter hartid        = 32'h0000_0000
)(
    // CPU clock.
    input  logic    clk,
    // Synchronous reset.
    input  logic    rst,
    
    // Program memory bus.
    boa_mem_bus.CPU pbus,
    // Data memory bus.
    boa_mem_bus.CPU dbus,
    
    // External interrupts 16 to 31.
    input  logic[15:0] irq
);
    /* ==== Pipeline barriers ==== */
    // IF/ID: Result valid.
    logic       if_id_valid;
    // IF/ID: Current instruction PC.
    logic[31:1] if_id_pc;
    // IF/ID: Current instruction word.
    logic[31:0] if_id_insn;
    // IF/ID: Trap raised.
    logic       if_id_trap;
    // IF/ID: Trap cause.
    logic[3:0]  if_id_cause;
    
    // ID/EX: Result valid.
    logic       id_ex_valid;
    // ID/EX: Current instruction PC.
    logic[31:1] id_ex_pc;
    // ID/EX: Current instruction word.
    logic[31:0] id_ex_insn;
    // ID/EX: Stores to register RD.
    logic       id_ex_use_rd;
    // ID/EX: Value from RS1 register.
    logic[31:0] id_ex_rs1_val;
    // ID/EX: Value from RS2 register.
    logic[31:0] id_ex_rs2_val;
    // ID/EX: Conditional branch.
    logic       id_ex_branch;
    // ID/EX: Branch prediction result.
    logic       id_ex_branch_predict;
    // ID/EX: Trap raised.
    logic       id_ex_trap;
    // ID/EX: Trap cause.
    logic[3:0]  id_ex_cause;
    
    // EX/MEM: Result valid.
    logic       ex_mem_valid;
    // EX/MEM: Current instruction PC.
    logic[31:1] ex_mem_pc;
    // EX/MEM: Current instruction word.
    logic[31:0] ex_mem_insn;
    // EX/MEM: Stores to register RD.
    logic       ex_mem_use_rd;
    // EX/MEM: Value from RS1 register / ALU result / memory address.
    logic[31:0] ex_mem_rs1_val;
    // EX/MEM: Value from RS2 register / memory write data.
    logic[31:0] ex_mem_rs2_val;
    // EX/MEM: Trap raised.
    logic       ex_mem_trap;
    // EX/MEM: Trap cause.
    logic[3:0]  ex_mem_cause;
    
    // MEM/WB: Result valid.
    logic       mem_wb_valid;
    // MEM/WB: Current instruction PC.
    logic[31:1] mem_wb_pc;
    // MEM/WB: Current instruction word.
    logic[31:0] mem_wb_insn;
    // MEM/WB: Stores to register RD.
    logic       mem_wb_use_rd;
    // MEM/WB: Value to store to register Rd.
    logic[31:0] mem_wb_rd_val;
    // MEM/WB: Trap raised.
    logic       mem_wb_trap;
    // MEM/WB: Trap cause.
    logic[3:0]  mem_wb_cause;
    
    
    /* ==== Control transfer logic ==== */
    // MRET or SRET instruction.
    logic       is_xret;
    // Is SRET instead of MRET.
    logic       is_sret;
    // Unconditional jump (JAL or JALR).
    logic       is_jump;
    // Conditional branch.
    logic       is_branch;
    // Branch predicted.
    logic       branch_predict;
    // Branch target address.
    logic[31:1] branch_target;
    // Branch target address uses RS1.
    logic       bt_use_rs1;
    
    // Predicted branch or unconditional control transfer.
    logic       fw_branch_predict;
    // Target address of control transfer.
    logic[31:1] fw_branch_target;
    
    always @(*) begin
        if (if_id_valid && is_xret) begin
            // TODO.
            $display("TODO: MRET");
            $finish;
        end else if (if_id_valid && is_jump) begin
            // JAL or JALR.
            fw_branch_predict   = 1;
            fw_branch_target    = branch_target;
            $strobe("JAL(R) from %x to %x", if_id_pc, fw_branch_target);
        end else if (if_id_valid && is_branch) begin
            // JAL or JALR.
            fw_branch_predict   = branch_predict;
            fw_branch_target    = branch_target;
            $strobe("BRANCH from %x to %x", if_id_pc, fw_branch_target);
        end else begin
            // Not a control transfer.
            fw_branch_predict   = 0;
            fw_branch_target    = 'bx;
        end
    end
    
    
    /* ==== Data hazard avoidance ==== */
    // Can forward from EX.
    logic[31:0] fw_ex_rd;
    // Forwarding output from EX.
    logic[31:0] fw_ex_out;
    // Forwarding output from MEM.
    logic[31:0] fw_mem_out;
    
    // Stall IF stage.
    logic       fw_stall_if;
    // Stall ID stage.
    logic       fw_stall_id;
    // Stall EX stage.
    logic       fw_stall_ex;
    // Stall MEM stage.
    logic       fw_stall_mem;
    assign fw_stall_if = 0;
    assign fw_stall_id = 0;
    assign fw_stall_ex = 0;
    assign fw_stall_mem = 0;
    
    
    /* ==== Pipeline stages ==== */
    boa_stage_if#(.entrypoint(entrypoint)) st_if(
        clk, rst, pbus,
        if_id_valid, if_id_pc, if_id_insn, if_id_trap, if_id_cause,
        fw_branch_predict, fw_branch_target, // Branch predict and target.
        fw_stall_if, fw_stall_id, 0, 0 // Branch correct and alt.
    );
    boa_stage_id st_id(
        clk, rst,
        if_id_valid, if_id_pc, if_id_insn, if_id_trap, if_id_cause,
        id_ex_valid, id_ex_pc, id_ex_insn, id_ex_use_rd, id_ex_rs1_val, id_ex_rs2_val, id_ex_branch, id_ex_branch_predict, id_ex_trap, id_ex_cause,
        is_xret, is_sret, is_jump, is_branch, branch_predict, branch_target,
        mem_wb_valid && mem_wb_use_rd, mem_wb_insn[11:7], mem_wb_rd_val,
        fw_stall_id, fw_stall_ex, bt_use_rs1, 0, // RS1 for JAL and JALR.
        0, 0, 0 // Forwarding port.
    );
    boa_stage_ex st_ex(
        clk, rst,
        id_ex_valid, id_ex_pc, id_ex_insn, id_ex_use_rd, id_ex_rs1_val, id_ex_rs2_val, id_ex_branch, id_ex_branch_predict, id_ex_trap, id_ex_cause,
        ex_mem_valid, ex_mem_pc, ex_mem_insn, ex_mem_use_rd, ex_mem_rs1_val, ex_mem_rs2_val, ex_mem_trap, ex_mem_cause,
        fw_stall_ex, fw_stall_mem,
        0, 0, 0, // Forwarding port.
        fw_ex_rd, fw_ex_out
    );
    boa_stage_mem st_mem(
        clk, rst, dbus,
        ex_mem_valid, ex_mem_pc, ex_mem_insn, ex_mem_use_rd, ex_mem_rs1_val, ex_mem_rs2_val, ex_mem_trap, ex_mem_cause,
        mem_wb_valid, mem_wb_pc, mem_wb_insn, mem_wb_use_rd, mem_wb_rd_val, mem_wb_trap, mem_wb_cause,
        fw_stall_mem, fw_mem_out
    );
endmodule
