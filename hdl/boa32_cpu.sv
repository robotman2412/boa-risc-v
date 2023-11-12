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
    // Clear results from IF.
    logic       clear_if;
    // Clear results from ID.
    logic       clear_id;
    // Clear results from EX.
    logic       clear_ex;
    // Clear results from MEM.
    logic       clear_mem;
    
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
    
    // Predicted branch or unconditional control transfer.
    logic       fw_branch_predict;
    // Target address of control transfer.
    logic[31:1] fw_branch_target;
    // Address of the next instruction.
    logic[31:1] if_next_pc;
    // Mispredicted branch.
    logic       fw_branch_correct;
    // Branch correction address.
    logic[31:1] fw_branch_alt;
    
    assign clear_if  = 0;
    assign clear_id  = fw_branch_correct;
    assign clear_ex  = 0;
    assign clear_mem = 0;
    
    always @(posedge clk) begin
        if (is_branch) begin
            fw_branch_alt <= fw_branch_predict ? if_next_pc : fw_branch_target;
        end
    end
    
    always @(*) begin
        if (fw_branch_correct) begin
            $strobe("Branch correction to %x", fw_branch_alt<<1);
        end
        if (id_ex_valid && is_xret) begin
            // TODO.
            fw_branch_predict   = 1;
            fw_branch_target    = 'bx;
            $display("TODO: MRET");
            $finish;
        end else if (id_ex_valid && is_jump) begin
            // JAL or JALR.
            fw_branch_predict   = 1;
            fw_branch_target    = branch_target;
            $strobe("JAL(R) from %x to %x", id_ex_pc<<1, fw_branch_target<<1);
        end else if (id_ex_valid && is_branch) begin
            // JAL or JALR.
            fw_branch_predict   = branch_predict;
            fw_branch_target    = branch_target;
            $strobe("BRANCH from %x to %x", id_ex_pc<<1, fw_branch_target<<1);
        end else begin
            // Not a control transfer.
            fw_branch_predict   = 0;
            fw_branch_target    = 'bx;
        end
    end
    
    
    /* ==== Data hazard avoidance ==== */
    // EX uses RS1 value.
    logic       use_rs1_ex;
    // EX uses RS2 value.
    logic       use_rs2_ex;
    // MEM uses RS1 value.
    logic       use_rs1_mem;
    // MEM uses RS2 value.
    logic       use_rs2_mem;
    // Branch target address uses RS1 value.
    logic       use_rs1_bt;
    
    // Can forward from EX.
    logic       fw_rd_ex;
    // Forwarding output from EX.
    wire [31:0] fw_out_ex  = ex_mem_rs1_val;
    // Forwarding output from MEM.
    wire [31:0] fw_out_mem = mem_wb_rd_val;
    
    // Forward RS1 to branch target address.
    logic       fw_rs1_bt;
    // Forward RS1 to EX.
    logic       fw_rs1_ex;
    // Forward RS2 to EX.
    logic       fw_rs2_ex;
    // Forward RS1 to MEM.
    logic       fw_rs1_mem;
    // Forward RS2 to MEM.
    logic       fw_rs2_mem;
    
    // Forwarding input to branch target address.
    logic[31:0] fw_in_bt;
    // Forwarding input to EX RS1.
    logic[31:0] fw_in_rs1_ex;
    // Forwarding input to EX RS2.
    logic[31:0] fw_in_rs2_ex;
    // Forwarding input to MEM RS1.
    logic[31:0] fw_in_rs1_mem;
    // Forwarding input to MEM RS2.
    logic[31:0] fw_in_rs2_mem;
    
    // Stall IF stage.
    logic       fw_stall_if;
    // Stall ID stage.
    logic       fw_stall_id;
    // Stall EX stage.
    logic       fw_stall_ex;
    // Stall MEM stage.
    logic       fw_stall_mem;
    
    // RS1 for branch targte matches RD for EX.
    wire fw_bt_rs1_ex_rd    = id_ex_valid  && ex_mem_valid && fw_rd_ex      && (id_ex_insn[19:15]  == ex_mem_insn[11:7]);
    // RS1 for branch targte matches RD for MEM.
    wire fw_bt_rs1_mem_rd   = id_ex_valid  && ex_mem_valid && mem_wb_use_rd && (id_ex_insn[19:15]  == mem_wb_insn[11:7]);
    
    // RS1 for EX matches RD for EX.
    wire fw_ex_rs1_ex_rd    = id_ex_valid  && ex_mem_valid && fw_rd_ex      && (id_ex_insn[19:15]  == ex_mem_insn[11:7]);
    // RS2 for EX matches RD for EX.
    wire fw_ex_rs2_ex_rd    = id_ex_valid  && ex_mem_valid && fw_rd_ex      && (id_ex_insn[24:20]  == ex_mem_insn[11:7]);
    // RS1 for EX matches RD for MEM.
    wire fw_ex_rs1_mem_rd   = id_ex_valid  && mem_wb_valid && mem_wb_use_rd && (id_ex_insn[19:15]  == mem_wb_insn[11:7]);
    // RS2 for EX matches RD for MEM.
    wire fw_ex_rs2_mem_rd   = id_ex_valid  && mem_wb_valid && mem_wb_use_rd && (id_ex_insn[24:20]  == mem_wb_insn[11:7]);
    
    // RS1 for MEM matches RD for MEM.
    wire fw_mem_rs1_mem_rd  = ex_mem_valid && mem_wb_valid && mem_wb_use_rd && (ex_mem_insn[19:15] == mem_wb_insn[11:7]);
    // RS2 for MEM matches RD for MEM.
    wire fw_mem_rs2_mem_rd  = ex_mem_valid && mem_wb_valid && mem_wb_use_rd && (ex_mem_insn[24:20] == mem_wb_insn[11:7]);
    
    // Data dependency resolution.
    boa_stage_ex_fw  st_ex_fw (id_ex_insn,  use_rs1_ex,  use_rs2_ex);
    boa_stage_mem_fw st_mem_fw(ex_mem_insn, use_rs1_mem, use_rs2_mem);
    always @(*) begin
        fw_stall_mem = 0;
        fw_stall_ex  = 0;
        fw_stall_id  = 0;
        fw_stall_if  = 0;
        
        // Forwarding logic.
        fw_rs1_bt     = fw_bt_rs1_ex_rd || fw_bt_rs1_mem_rd;
        fw_in_bt      = fw_bt_rs1_ex_rd ? fw_out_ex : fw_out_mem;
        fw_rs1_ex     = fw_ex_rs1_ex_rd || fw_ex_rs1_mem_rd;
        fw_in_rs1_ex  = fw_ex_rs1_ex_rd ? fw_out_ex : fw_out_mem;
        fw_rs2_ex     = fw_ex_rs2_ex_rd || fw_ex_rs2_mem_rd;
        fw_in_rs2_ex  = fw_ex_rs2_ex_rd ? fw_out_ex : fw_out_mem;
        fw_rs1_mem    = fw_mem_rs1_mem_rd;
        fw_in_rs1_mem = fw_out_mem;
        fw_rs2_mem    = fw_mem_rs2_mem_rd;
        fw_in_rs2_mem = fw_out_mem;
        
        // Stalling logic.
        if ((fw_rs1_ex || fw_rs2_ex) && ex_mem_use_rd && !fw_rd_ex) begin
            // EX will next need something that has to be processed by MEM first.
            // Stall ID so that this instruction doesn't enter EX until a result is available.
            fw_stall_id = 1;
        end
        if (fw_rs1_bt && ex_mem_use_rd && !fw_rd_ex) begin
            // Branch target address needs something that has to be processed by MEM first.
            // Stall ID so that MEM will produce a result that may then be used by the branch target address.
            fw_stall_id = 1;
        end
        
        fw_stall_ex |= fw_stall_mem;
        fw_stall_id |= fw_stall_ex;
        fw_stall_if |= fw_stall_id;
    end
    
    
    /* ==== Pipeline stages ==== */
    boa_stage_if#(.entrypoint(entrypoint)) st_if(
        clk, rst, clear_if, pbus,
        // Pipeline output.
        if_id_valid, if_id_pc, if_id_insn, if_id_trap, if_id_cause,
        // Control transfer.
        fw_branch_predict, fw_branch_target, if_next_pc, fw_branch_correct, fw_branch_alt,
        // Data hazard avoicance.
        fw_stall_if
    );
    boa_stage_id st_id(
        clk, rst, clear_id,
        // Pipeline input.
        if_id_valid, if_id_pc, if_id_insn, if_id_trap, if_id_cause,
        // Pipeline output.
        id_ex_valid, id_ex_pc, id_ex_insn, id_ex_use_rd, id_ex_rs1_val, id_ex_rs2_val, id_ex_branch, id_ex_branch_predict, id_ex_trap, id_ex_cause,
        // Control transfer.
        is_xret, is_sret, is_jump, is_branch, branch_predict, branch_target,
        // Write-back.
        mem_wb_valid && mem_wb_use_rd, mem_wb_insn[11:7], mem_wb_rd_val,
        // Data hazard avoidance.
        fw_stall_id, use_rs1_bt, fw_rs1_bt, fw_in_bt
    );
    boa_stage_ex st_ex(
        clk, rst, clear_ex,
        // Pipeline input.
        id_ex_valid, id_ex_pc, id_ex_insn, id_ex_use_rd, fw_rs1_ex ? fw_in_rs1_ex : id_ex_rs1_val, fw_rs2_ex ? fw_in_rs2_ex : id_ex_rs2_val, id_ex_branch, id_ex_branch_predict, id_ex_trap, id_ex_cause,
        // Pipeline output.
        ex_mem_valid, ex_mem_pc, ex_mem_insn, ex_mem_use_rd, ex_mem_rs1_val, ex_mem_rs2_val, ex_mem_trap, ex_mem_cause,
        // Data hazard avoidance.
        fw_branch_correct, fw_stall_ex, fw_rd_ex
    );
    boa_stage_mem st_mem(
        clk, rst, clear_mem, dbus,
        // Pipeline input.
        ex_mem_valid, ex_mem_pc, ex_mem_insn, ex_mem_use_rd, fw_rs1_mem ? fw_in_rs1_mem : ex_mem_rs1_val, fw_rs2_mem ? fw_in_rs2_mem : ex_mem_rs2_val, ex_mem_trap, ex_mem_cause,
        // Pipeline output.
        mem_wb_valid, mem_wb_pc, mem_wb_insn, mem_wb_use_rd, mem_wb_rd_val, mem_wb_trap, mem_wb_cause,
        // Data hazard avoidance.
        fw_stall_mem
    );
endmodule
