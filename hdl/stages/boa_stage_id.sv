
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`include "boa_defines.svh"



// Boa³² pipline stage: ID (instruction decode).
module boa_stage_id#(
    // Print debug messages about CPU state.
    parameter debug         = 0,
    // Support M (multiply/divide) instructions.
    parameter has_m         = 1,
    // Support C (compressed) instructions.
    parameter has_c         = 1
)(
    // CPU clock.
    input  logic        clk,
    // Synchronous reset.
    input  logic        rst,
    // Invalidate results and clear traps.
    input  logic        clear,
    
    
    // IF/ID: Result valid.
    input  logic        d_valid,
    // IF/ID: Current instruction PC.
    input  logic[31:1]  d_pc,
    // IF/ID: Current instruction word.
    input  logic[31:0]  d_insn,
    // IF/ID: Trap raised.
    input  logic        d_trap,
    // IF/ID: Trap cause.
    input  logic[3:0]   d_cause,
    
    // ID/EX: Result valid.
    output logic        q_valid,
    // ID/EX: Current instruction PC.
    output logic[31:1]  q_pc,
    // ID/EX: Current instruction word.
    output logic[31:0]  q_insn,
    // ID/EX: Is 32-bit instruction.
    output logic        q_ilen,
    // ID/EX: Stores to register RD.
    output logic        q_use_rd,
    // ID/EX: Value from RS1 register.
    output logic[31:0]  q_rs1_val,
    // ID/EX: Value from RS2 register.
    output logic[31:0]  q_rs2_val,
    // ID/EX: Conditional branch.
    output logic        q_branch,
    // ID/EX: Branch prediction result.
    output logic        q_branch_predict,
    // ID/EX: Trap raised.
    output logic        q_trap,
    // ID/EX: Trap cause.
    output logic[3:0]   q_cause,
    
    
    // MRET or SRET instruction.
    output logic        is_xret,
    // Is SRET instead of MRET.
    output logic        is_sret,
    // Unconditional jump (JAL or JALR).
    output logic        is_jump,
    // Conditional branch.
    output logic        is_branch,
    // Branch predicted.
    output logic        branch_predict,
    // Branch target address.
    output logic[31:1]  branch_target,
    
    // Write-back enable.
    input  logic        wb_we,
    // Write-back register.
    input  logic[4:0]   wb_rd,
    // Write-back write data.
    input  logic[31:0]  wb_wdata,
    
    // Stall ID stage.
    input  logic        fw_stall_id,
    
    // Branch target address uses RS1.
    output logic        use_rs1_bt,
    // Forward RS1 to branch target address.
    input  logic        fw_rs1_bt,
    // Forwarding value.
    input  logic[31:0]  fw_val
);
    // IF/ID: Result valid.
    logic       r_valid;
    // IF/ID: Current instruction PC.
    logic[31:1] r_pc;
    // IF/ID: Current instruction word.
    logic[31:0] r_insn;
    // IF/ID: Trap raised.
    logic       r_trap;
    // IF/ID: Trap cause.
    logic[3:0]  r_cause;
    
    // Pipline barrier register.
    always @(posedge clk) begin
        if (rst) begin
            r_valid <= 0;
            r_pc    <= 'bx;
            r_insn  <= 'bx;
            r_trap  <= 0;
            r_cause <= 'bx;
        end else if (!fw_stall_id) begin
            r_valid <= d_valid;
            r_pc    <= d_pc;
            r_insn  <= d_insn;
            r_trap  <= d_trap;
            r_cause <= d_cause;
        end
    end
    
    // Instruction decompression logic.
    logic[31:0] decomp;
    logic       decomp_valid;
    wire        is_rvc = has_c && r_insn[1:0] != 2'b11;
    wire [31:0] insn   = is_rvc ? decomp : r_insn;
    generate
        if (has_c) begin: rvc
            boa_insn_decomp insn_decomp(
                0, 32'hffff_ffff,
                r_insn[15:0],
                decomp, decomp_valid
            );
        end else begin: norvc
            assign decomp_valid = 0;
            assign decomp       = 0;
        end
    endgenerate
    
    // Instruction validator.
    wire insn_valid, insn_legal;
    boa_insn_validator#(.has_m(1), .has_zicsr(1)) validator(
        r_insn, 2'b11, 0, 32'hffff_ffff,
        insn_valid, insn_legal
    );
    
    // Register file.
    logic[31:0] rs1_val;
    logic[31:0] rs2_val;
    boa_regfile#(.debug(debug)) regfile(
        clk, rst,
        wb_we, wb_rd, wb_wdata,
        insn[19:15], rs1_val,
        insn[24:20], rs2_val
    );
    
    // ECALL / EBREAK logic.
    wire is_ecall  = insn[6:2] == `RV_OP_SYSTEM && insn[14:12] == 0 && insn[31:20] == 0;
    wire is_ebreak = insn[6:2] == `RV_OP_SYSTEM && insn[14:12] == 0 && insn[31:20] == 1;
    
    // Register decoder.
    logic use_rs1, use_rs2, use_rs3, use_rd;
    boa_reg_decoder reg_decd(insn, use_rs1, use_rs2, use_rs3, use_rd);
    
    // Branch decoding logic.
    boa_branch_decoder branch_decd(insn, r_pc, fw_rs1_bt ? fw_val : rs1_val, is_xret, is_branch, is_jump, branch_target, use_rs1_bt);
    assign branch_predict = insn[31];
    assign is_sret        = !insn[29];
    
    // Pipeline output logic.
    assign q_pc             = r_pc;
    assign q_insn           = insn;
    assign q_ilen           = !is_rvc;
    assign q_use_rd         = use_rd;
    assign q_rs1_val        = rs1_val;
    assign q_rs2_val        = rs2_val;
    assign q_branch         = is_branch;
    assign q_branch_predict = branch_predict;
    always @(*) begin
        if (r_trap) begin
            q_valid = 0;
            q_trap  = !clear;
            q_cause = r_cause;
        end else if (r_valid && is_rvc && !decomp_valid) begin
            q_valid = 0;
            q_trap  = !clear;
            q_cause = `RV_ECAUSE_IILLEGAL;
        end else if (r_valid && !is_rvc && !insn_valid) begin
            q_valid = 0;
            q_trap  = !clear;
            q_cause = `RV_ECAUSE_IILLEGAL;
        end else if (r_valid && is_ecall) begin
            q_valid = 0;
            q_trap  = !clear;
            q_cause = `RV_ECAUSE_M_ECALL;
        end else if (r_valid && is_ebreak) begin
            q_valid = 0;
            q_trap  = !clear;
            q_cause = `RV_ECAUSE_EBREAK;
        end else begin
            q_valid = r_valid && !clear;
            q_trap  = 0;
            q_cause = 'bx;
        end
    end
endmodule



// Read-first RV32 register file.
module boa_regfile#(
    // Print debug messages about CPU state.
    parameter debug         = 0
)(
    // CPU clock.
    input  logic        clk,
    // Synchronous reset.
    input  logic        rst,
    
    // Register write enable.
    input  logic        we,
    // Register write index.
    input  logic[4:0]   rd,
    // Register write data.
    input  logic[31:0]  wdata,
    
    // Register read index 1.
    input  logic[4:0]   rs1,
    // Register read data 1.
    output logic[31:0]  q1,
    
    // Register read index 1.
    input  logic[4:0]   rs2,
    // Register read data 1.
    output logic[31:0]  q2
);
    // Register storage.
    logic[31:0] storage[31:1];
    
    // Read logic.
    assign q1 = (rs1 == 0) ? 0 : storage[rs1];
    assign q2 = (rs2 == 0) ? 0 : storage[rs2];
    
    // Write logic.
    always @(posedge clk) begin
        if (rst) begin
            // Clear all registers on reset.
            integer i;
            for (i = 1; i < 32; i = i + 1) begin
                storage[i] <= 0;
            end
            
        end else if (we && (rd != 0)) begin
            // Write a register.
            storage[rd] <= wdata;
            if (debug) $display("x%d = 0x%08x", rd, wdata);
        end
    end
endmodule



// Does branch prediction and branch target address calculation.
module boa_branch_decoder(
    // Instruction to evaluate.
    input  logic[31:0]  insn,
    // Address of current instruction (for JAL and conditional branch).
    input  logic[31:1]  pc_val,
    // Value of RS1 register (for JALR).
    input  logic[31:0]  rs1_val,
    
    // Instruction is MRET or SRET.
    output logic        is_xret,
    // Instruction is a conditional branch.
    output logic        is_branch,
    // Instruction is JAL or JALR.
    output logic        is_jump,
    // Calculated branch target address.
    output logic[31:1]  branch_addr,
    
    // Branch address uses RS1.
    output logic        use_rs1
);
    // Adder left-hand side.
    logic[31:0] add_lhs;
    // Adder right-hand side.
    logic[31:0] add_rhs;
    // Adder result.
    logic[31:0] add_res = add_lhs + add_rhs;
    assign branch_addr[31:1] = add_res[31:1];
    
    always @(*) begin
        if (insn[6:2] == `RV_OP_JAL) begin
            // JAL instructions.
            is_xret         = 0;
            is_branch       = 0;
            is_jump         = 1;
            add_lhs[31:1]   = pc_val[31:1];
            add_lhs[0]      = 0;
            add_rhs[0]      = 0;
            add_rhs[10:1]   = insn[30:21];
            add_rhs[11]     = insn[20];
            add_rhs[19:12]  = insn[19:12];
            add_rhs[20]     = insn[31];
            use_rs1         = 0;
            
        end else if (insn[6:2] == `RV_OP_JALR) begin
            // JALR instructions.
            is_xret         = 0;
            is_branch       = 0;
            is_jump         = 1;
            add_lhs         = rs1_val;
            add_rhs[11:0]   = insn[31:20];
            add_rhs[20:12]  = insn[31] ? 9'h1ff : 9'h000;
            use_rs1         = 1;
            
        end else if (insn[6:2] == `RV_OP_BRANCH) begin
            // Conditional branch instructions.
            is_xret         = 0;
            is_branch       = 1;
            is_jump         = 0;
            add_lhs[31:1]   = pc_val[31:1];
            add_lhs[0]      = 0;
            add_rhs[0]      = 0;
            add_rhs[4:1]    = insn[11:8];
            add_rhs[10:5]   = insn[30:25];
            add_rhs[11]     = insn[7];
            add_rhs[12]     = insn[31];
            add_rhs[20:13]  = insn[31] ? 8'hff : 8'h00;
            use_rs1         = 0;
            
        end else begin
            // Non-branch instructions.
            is_xret         = insn[6:2] == `RV_OP_SYSTEM && insn[14:12] == 0 && insn[21] && insn[28];
            is_branch       = 0;
            is_jump         = 0;
            add_lhs         = 'bx;
            add_rhs[20:0]   = 'bx;
            use_rs1         = 0;
        end
        add_rhs[31:21] = insn[31] ? 11'h7ff : 11'h000;
    end
endmodule



// Determines the presence of registers in instructions.
module boa_reg_decoder#(
    // Check for atomic instructions.
    parameter a = 0,
    // Check for float instructions.
    parameter f = 0,
    // Check for RV64 instructions.
    parameter rv64 = 0
)(
    input  logic[31:0]  insn,
    output logic        has_rs1,
    output logic        has_rs2,
    output logic        has_rs3,
    output logic        has_rd
);
    always @(*) begin
        has_rs1 = 'b0; has_rs2 = 'b0; has_rs3 = 'b0; has_rd = 'b0;
        case (insn[6:2])
            default:            begin end
            `RV_OP_LOAD:        begin has_rs1 = 1; has_rs2 = 0; has_rs3 = 0; has_rd = 1; end
            `RV_OP_LOAD_FP:     if (f) begin has_rs1 = 1; has_rs2 = 0; has_rs3 = 0; has_rd = 1; end
            `RV_OP_MISC_MEM:    begin has_rs1 = 0; has_rs2 = 0; has_rs3 = 0; has_rd = 0; end
            `RV_OP_OP_IMM:      begin has_rs1 = 1; has_rs2 = 0; has_rs3 = 0; has_rd = 1; end
            `RV_OP_AUIPC:       begin has_rs1 = 0; has_rs2 = 0; has_rs3 = 0; has_rd = 1; end
            `RV_OP_OP_IMM_32:   if (rv64) begin has_rs1 = 1; has_rs2 = 0; has_rs3 = 0; has_rd = 1; end
            `RV_OP_STORE:       begin has_rs1 = 1; has_rs2 = 1; has_rs3 = 0; has_rd = 0; end
            `RV_OP_STORE_FP:    if (f) begin has_rs1 = 1; has_rs2 = 1; has_rs3 = 0; has_rd = 0; end
            `RV_OP_AMO:         if (a) begin has_rs1 = 1; has_rs2 = 1; has_rs3 = 0; has_rd = 1; end
            `RV_OP_OP:          begin has_rs1 = 1; has_rs2 = 1; has_rs3 = 0; has_rd = 1; end
            `RV_OP_LUI:         begin has_rs1 = 0; has_rs2 = 0; has_rs3 = 0; has_rd = 1; end
            `RV_OP_OP_32:       if (rv64) begin has_rs1 = 1; has_rs2 = 1; has_rs3 = 0; has_rd = 1; end
            `RV_OP_MADD:        if (f) begin has_rs1 = 1; has_rs2 = 1; has_rs3 = 1; has_rd = 1; end
            `RV_OP_MSUB:        if (f) begin has_rs1 = 1; has_rs2 = 1; has_rs3 = 1; has_rd = 1; end
            `RV_OP_NMSUB:       if (f) begin has_rs1 = 1; has_rs2 = 1; has_rs3 = 1; has_rd = 1; end
            `RV_OP_NMADD:       if (f) begin has_rs1 = 1; has_rs2 = 1; has_rs3 = 1; has_rd = 1; end
            `RV_OP_OP_FP:       if (f) begin has_rs1 = 1; has_rs2 = 1; has_rs3 = 0; has_rd = 1; end
            `RV_OP_BRANCH:      begin has_rs1 = 1; has_rs2 = 1; has_rs3 = 0; has_rd = 0; end
            `RV_OP_JALR:        begin has_rs1 = 1; has_rs2 = 0; has_rs3 = 0; has_rd = 1; end
            `RV_OP_JAL:         begin has_rs1 = 0; has_rs2 = 0; has_rs3 = 0; has_rd = 1; end
            `RV_OP_SYSTEM:
                begin
                    if (insn[14:12] != 0) begin
                        has_rs1 = !insn[14]; has_rs2 = 0; has_rd = 1;
                    end else begin
                        has_rs1 = 0; has_rs2 = 0; has_rd = 0;
                    end
                end
        endcase
    end
endmodule



// Verifies the validity of an uncompressed instruction.
module boa_insn_validator#(
    // Allow multiply/divide instructions.
    parameter has_m = 0,
    // Allow atomic instructions.
    parameter has_a = 0,
    // Allow float instructions.
    parameter has_f = 0,
    // Allow double instructions.
    parameter has_d = 0,
    // Allow long double instructions.
    parameter has_q = 0,
    // Allow CSR instructions.
    parameter has_zicsr = 0,
    // Allow fence.i instructions.
    parameter has_zifencei = 0,
    // Allow S-mode instructions.
    parameter has_s_mode = 0
)(
    // Instruction to verify.
    input  logic[31:0] insn,
    // Current privilege level.
    input  logic[1:0]  privilege,
    // Allow RV64 instructions.
    input  logic       rv64,
    // Current value of misa.
    input  logic[31:0] misa,
    
    // Instruction is recognised.
    output logic       valid,
    // Instruction is allowed in current privilege level.
    // May still be 1 if valid is 0.
    output logic       legal
);
    // Evaluate misa.
    wire allow_m        = (misa & `RV_MISA_M) && has_m;
    wire allow_a        = (misa & `RV_MISA_A) && has_a;
    wire allow_f        = (misa & `RV_MISA_F) && has_f;
    wire allow_d        = (misa & `RV_MISA_D) && has_d;
    wire allow_q        = (misa & `RV_MISA_Q) && has_q;
    wire allow_zicsr    = has_zicsr;
    wire allow_zifencei = has_zifencei;
    wire allow_s_mode   = (misa & `RV_MISA_S) && has_s_mode;
    
    
    // ALU operation verifier.
    logic valid_op_imm;
    always @(*) begin
        if (insn[14:12] == `RV_ALU_SLL) begin
            // Shift left.
            valid_op_imm = (insn[31:26] == 0) && (rv64 && !insn[3] || !insn[25]);
            
        end else if (insn[14:12] == `RV_ALU_SRL) begin
            // Shift right.
            valid_op_imm = (insn[31] == 0) && (insn[29:26] == 0) && (rv64 && !insn[5] || !insn[25]);
            
        end else begin
            // Any other OP-IMM or OP-IMM-32.
            valid_op_imm = 1;
        end
    end
    
    logic valid_op;
    always @(*) begin
        if (insn[25]) begin
            // Multiply / divide.
            if (rv64 && insn[3]) begin
                valid_op = (insn[31:26] == 0) && (insn[14] || (insn[13:12] != 0));
            end else begin
                valid_op = insn[31:26] == 0;
            end
            
        end else if (insn[14:12] == `RV_ALU_SLL) begin
            // Shift left.
            valid_op = (insn[31:26] == 0) && (rv64 && !insn[3] || !insn[25]);
            
        end else if (insn[14:12] == `RV_ALU_SRL) begin
            // Shift right.
            valid_op = (insn[31] == 0) && (insn[29:26] == 0) && (rv64 && !insn[3] || !insn[25]);
            
        end else if (insn[14:12] == `RV_ALU_ADD) begin
            // Add / subtract.
            valid_op = (insn[31] == 0) && (insn[29:26] == 0) && (rv64 && !insn[3] || !insn[25]);
            
        end else begin
            // Any other OP or OP-32.
            valid_op = (insn[31:25] == 0);
        end
    end
    
    
    // SYSTEM opcode verifier.
    logic valid_system;
    logic legal_system;
    always @(*) begin
        if (insn[14:12] == 3'b000) begin
            // Privileged instructions.
            casez (insn[31:20])
                default:            begin valid_system = 0;          legal_system = 1; end
                12'b0000000_0000?:  begin valid_system = 1;          legal_system = 1; end // ECALL and EBREAK
                12'b0001000_00010:  begin valid_system = has_s_mode; legal_system = privilege[0]; end // SRET
                12'b0011000_00010:  begin valid_system = 1;          legal_system = privilege[1]; end // MRET
                12'b0001000_00101:  begin valid_system = 1;          legal_system = 1; end // WFI
            endcase
        end else begin
            // CSR instructions.
            valid_system = insn[14:12] != 3'b100;
            legal_system = 1;
        end
    end
    
    
    // Output multiplexer.
    always @(*) begin
        legal = 1;
        if (insn[1:0] != 2'b11) begin
            valid = 0;
        end else case (insn[6:2])
            default:            begin valid = 0; end
            `RV_OP_LOAD:        begin valid = insn[14] ? (insn[13:12] < 2) + rv64 : (insn[13:12] < 3) + rv64; end
            `RV_OP_LOAD_FP:     begin valid = 0; $strobe("TODO: validity for LOAD_FP"); end
            `RV_OP_MISC_MEM:    begin valid = insn[14:12] == 0; end
            `RV_OP_OP_IMM:      begin valid = valid_op_imm; end
            `RV_OP_AUIPC:       begin valid = 1; end
            `RV_OP_OP_IMM_32:   begin valid = rv64 && valid_op_imm; end
            `RV_OP_STORE:       begin valid = (insn[14] == 0) && (insn[13:12] <= 2) + rv64; end
            `RV_OP_STORE_FP:    begin valid = 0; $strobe("TODO: validity for STORE_FP"); end
            `RV_OP_AMO:         begin valid = allow_a; end
            `RV_OP_OP:          begin valid = valid_op; end
            `RV_OP_LUI:         begin valid = 1; end
            `RV_OP_OP_32:       begin valid = rv64 && valid_op; end
            `RV_OP_MADD:        begin valid = 0; $strobe("TODO: validity for MADD"); end
            `RV_OP_MSUB:        begin valid = 0; $strobe("TODO: validity for MSUB"); end
            `RV_OP_NMSUB:       begin valid = 0; $strobe("TODO: validity for NMSUB"); end
            `RV_OP_NMADD:       begin valid = 0; $strobe("TODO: validity for NMADD"); end
            `RV_OP_OP_FP:       begin valid = 0; $strobe("TODO: validity for OP_FP"); end
            `RV_OP_BRANCH:      begin valid = insn[14] || !insn[13]; end
            `RV_OP_JALR:        begin valid = insn[14:12] == 0; end
            `RV_OP_JAL:         begin valid = 1; end
            `RV_OP_SYSTEM:      begin valid = valid_system; legal = legal_system; end
        endcase
    end
endmodule
