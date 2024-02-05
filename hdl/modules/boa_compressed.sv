
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`include "boa_defines.svh"



// Boa instruction decompressor.
module boa_insn_decomp#(
    // Allow float instructions.
    parameter has_f = 0,
    // Allow double instructions.
    parameter has_d = 0,
    // Allow long double instructions.
    parameter has_q = 0
)(
    // Decompress RV64 instructions.
    input  logic       rv64,
    // Current value of misa.
    input  logic[31:0] misa,
    // Instruction to decompress.
    input  logic[15:0] comp,
    // Decompressed instruction.
    output logic[31:0] decomp,
    // Is a valid RVC instruction.
    output logic       valid
);
    // Evaluate misa.
    wire allow_f        = (misa & `RV_MISA_F) && has_f;
    wire allow_d        = (misa & `RV_MISA_D) && has_d;
    wire allow_q        = (misa & `RV_MISA_Q) && has_q;
    
    // RVC opcode number.
    wire[4:0] op  = {comp[1:0], comp[15:13]};
    // Low-order bits 3-bit register number.
    wire[4:0] r3l = {2'b01, comp[4:2]};
    // High-ordedr bits 3-bit register number.
    wire[4:0] r3h = {2'b01, comp[9:7]};
    // 5-bit register number.
    wire[4:0] r5  = comp[11:7];
    
    // Decompressed instruction temporary.
    logic[31:0] result;
    
    // Instruction decompression logic.
    always @(*) begin
        if (                              op == `RV_OPC_ADDI4SPN    ) begin
            // addi rd', sp, imm
            valid   = comp[12:5] != 0;
            result  = {
                // IMM
                {2'b00, comp[10:7], comp[12:11], comp[5], comp[6], 2'b00},
                // RS1
                5'd2,
                // FUNCT3
                `RV_ALU_ADD,
                // RD
                r3l,
                // OP
                `RV_OP_OP_IMM, 2'b11
            };
        end else if ( allow_f          && op == `RV_OPC_FLD         ) begin
            valid=0;result='bx;//TODO.
        end else if (                     op == `RV_OPC_LW          ) begin
            // lw rd', imm(rs1')
            valid  = 1;
            result = {
                // IMM
                {8'b0000_0000, comp[5], comp[12:10], comp[6], 2'b00},
                // RS1
                r3h,
                // FUNCT3
                3'd2,
                // RD
                r3l,
                // OP
                `RV_OP_LOAD, 2'b11
            };
        end else if ((allow_f || rv64) && op == `RV_OPC_FLW_LD      ) begin
            valid=0;result='bx;//TODO.
        end else if ( allow_f          && op == `RV_OPC_FSD         ) begin
            valid=0;result='bx;//TODO.
        end else if (                     op == `RV_OPC_SW          ) begin
            // sw rd', imm(rs1')
            valid  = 1;
            result = {
                // IMM
                {8'b0000_0000, comp[5], comp[12]},
                // RS2
                r3l,
                // RS1
                r3h,
                // FUNCT3
                3'd2,
                // IMM
                {comp[11:10], comp[6], 2'b00},
                // OP
                `RV_OP_STORE, 2'b11
            };
        end else if ((allow_f || rv64) && op == `RV_OPC_FSW_SD      ) begin
            valid=0;result='bx;//TODO.
        end else if (                     op == `RV_OPC_ADDI        ) begin
            // addi rd', rd', imm
            valid  = 1;
            result = {
                // IMM
                {7'b111_1111 * comp[12], comp[6:2]},
                // RS1
                r5,
                // FUNCT3
                `RV_ALU_ADD,
                // RD
                r5,
                // OP
                `RV_OP_OP_IMM, 2'b11
            };
        end else if (                     op == `RV_OPC_JAL_ADDIW   ) begin
            if (rv64) begin
                // addiw rd', rd', imm
                valid  = 1;
                result = {
                    // IMM
                    {4'b0000, comp[12], comp[6:2]},
                    // RS1
                    r5,
                    // FUNCT3
                    `RV_ALU_ADD,
                    // RD
                    r5,
                    // OP
                    `RV_OP_OP_IMM_32, 2'b11
                };
            end else begin
                // jal ra, imm
                valid  = 1;
                result = {
                    // IMM
                    {comp[12], comp[8], comp[10:9], comp[6], comp[7], comp[2], comp[11], comp[5:3], comp[12], 8'b1111_1111 * comp[12]},
                    // RD
                    5'd1,
                    // OP
                    `RV_OP_JAL, 2'b11
                };
            end
        end else if (                     op == `RV_OPC_LI          ) begin
            // addi rd', x0, imm
            valid  = 1;
            result = {
                // IMM
                {7'b111_1111 * comp[12], comp[6:2]},
                // RS1
                5'd0,
                // FUNCT3
                `RV_ALU_ADD,
                // RD
                r5,
                // OP
                `RV_OP_OP_IMM, 2'b11
            };
        end else if (                     op == `RV_OPC_LUI_ADDI16SP) begin
            if (comp[11:7] == 2) begin
                // addi sp, sp, imm
                valid  = 1;
                result = {
                    // IMM
                    {3'b111 * comp[12], comp[4:3], comp[5], comp[2], comp[6], 4'b0000},
                    // RS1
                    r5,
                    // FUNCT3
                    `RV_ALU_ADD,
                    // RD
                    r5,
                    // OP
                    `RV_OP_OP_IMM, 2'b11
                };
            end else begin
                // lui rd, imm
                valid  = 1;
                result = {
                    // IMM
                    {14'b11_1111_1111_1111 * comp[12], comp[12], comp[6:2]},
                    // RD
                    r5,
                    // OP
                    `RV_OP_LUI, 2'b11
                };
            end
        end else if (                     op == `RV_OPC_ALU         ) begin
            if (comp[11:10] == 2'b10) begin
                // andi rd', rd', imm
                valid  = 1;
                result = {
                    // IMM
                    {6'b11_1111 * comp[12], comp[12], comp[6:2]},
                    // RS1
                    r3h,
                    // FUNCT3
                    `RV_ALU_AND,
                    // RD
                    r3h,
                    // OP
                    `RV_OP_OP_IMM, 2'b11
                };
            end else if (comp[11] == 0) begin
                // srli rd', rd', imm
                // srai rd', rd', imm
                valid  = !comp[12] || rv64;
                result = {
                    // IMM
                    {1'b0, comp[10], 4'b0000, comp[12], comp[6:2]},
                    // RS1
                    r3h,
                    // FUNCT3
                    `RV_ALU_SRL,
                    // RD
                    r3h,
                    // OP
                    `RV_OP_OP_IMM, 2'b11
                };
            end else if (rv64 && comp[12] && !comp[6]) begin
                // subw rd', rd', rs2'
                // addw rd', rd', rs2'
                valid  = 1;
                result = {
                    {1'b0, !comp[5], 5'b0_0000},
                    // RS2
                    r3l,
                    // RS1
                    r3h,
                    // FUNCT3
                    `RV_ALU_ADD,
                    // RD
                    r3h,
                    // OP
                    `RV_OP_OP_32, 2'b11
                };
            end else if (!comp[12]) begin
                // sub rd', rd', rs2'
                // xor rd', rd', rs2'
                // or  rd', rd', rs2'
                // and rd', rd', rs2'
                valid  = 1;
                result = {
                    {1'b0, comp[6:5] == 2'b00, 5'b000_0000},
                    // RS2
                    r3l,
                    // RS1
                    r3h,
                    // FUNCT3
                    {comp[6] || comp[5], comp[6], comp[6] && comp[5]},
                    // RD
                    r3h,
                    // OP
                    `RV_OP_OP, 2'b11
                };
            end else begin
                valid  = 0;
                result = 'bx;
            end
        end else if (                     op == `RV_OPC_J           ) begin
            // j imm
            valid  = 1;
            result = {
                // IMM
                {comp[12], comp[8], comp[10:9], comp[6], comp[7], comp[2], comp[11], comp[5:3], comp[12], 8'b1111_1111 * comp[12]},
                // RD
                5'd0,
                // OP
                `RV_OP_JAL, 2'b11
            };
        end else if (                     op == `RV_OPC_BEQZ        ) begin
            // beq rs1', x0, imm
            valid  = 1;
            result = {
                // IMM
                {3'b111 * comp[12], comp[12], comp[6:5], comp[2]},
                // RS2
                5'd0,
                // RS1
                r3h,
                // FUNCT3
                `RV_BRANCH_BEQ,
                // IMM
                {comp[11:10], comp[4:3], comp[12]},
                // OP
                `RV_OP_BRANCH, 2'b11
            };
        end else if (                     op == `RV_OPC_BNEZ        ) begin
            // beq rs1', x0, imm
            valid  = 1;
            result = {
                // IMM
                {3'b111 * comp[12], comp[12], comp[6:5], comp[2]},
                // RS2
                5'd0,
                // RS1
                r3h,
                // FUNCT3
                `RV_BRANCH_BNE,
                // IMM
                {comp[11:10], comp[4:3], comp[12]},
                // OP
                `RV_OP_BRANCH, 2'b11
            };
        end else if (                     op == `RV_OPC_SLLI        ) begin
            // slli rd', rd', imm
            valid  = !comp[12] || rv64;
            result = {
                // IMM
                {4'b0000, comp[12], comp[6:2]},
                // RS1
                r5,
                // FUNCT3
                `RV_ALU_SLL,
                // RD
                r5,
                // OP
                `RV_OP_OP_IMM, 2'b11
            };
        end else if ( allow_f          && op == `RV_OPC_FLDSP       ) begin
            valid=0;result='bx;//TODO.
        end else if (                     op == `RV_OPC_LWSP        ) begin
            // lw rd, imm(sp)
            valid  = comp[11:7] != 0;
            result = {
                // IMM
                {4'b0000, comp[3:2], comp[12], comp[6:4], 2'b00},
                // RS1
                5'd2,
                // FUNCT3
                3'd2,
                // RD
                r5,
                // OP
                `RV_OP_LOAD, 2'b11
            };
        end else if ((allow_f || rv64) && op == `RV_OPC_FLWSP_LDSP  ) begin
            valid=0;result='bx;//TODO.
        end else if (                     op == `RV_OPC_JR_MV_ADD   ) begin
            if (!comp[12] && comp[6:2] == 0) begin
                // jalr x0, 0(rs1)
                valid  = comp[11:7] != 0;
                result = {
                    // IMM
                    12'b0000_0000_0000,
                    // RS1
                    comp[11:7],
                    // FUNCT3
                    3'b000,
                    // RD
                    5'd0,
                    // OP
                    `RV_OP_JALR, 2'b11
                };
            end else if (!comp[12]) begin
                // addi rd, rs1, 0
                valid  = 1;
                result = {
                    // IMM
                    12'b0000_0000_0000,
                    // RS1
                    comp[6:2],
                    // FUNCT3
                    `RV_ALU_ADD,
                    // RD
                    comp[11:7],
                    // OP
                    `RV_OP_OP_IMM, 2'b11
                };
            end else if (comp[11:2] == 0) begin
                // ebreak
                valid  = 1;
                result = {
                    // SYSTEM
                    21'b0000_0000_0001,
                    // RS1
                    5'd0,
                    // FUNCT3
                    3'b000,
                    // RD
                    5'd0,
                    // OP
                    `RV_OP_SYSTEM, 2'b11
                };
            end else if (comp[6:2] == 0) begin
                // jalr ra, 0(rs1)
                valid  = comp[11:7] != 0;
                result = {
                    // IMM
                    12'b0000_0000_0000,
                    // RS1
                    comp[11:7],
                    // FUNCT3
                    3'b000,
                    // RD
                    5'd1,
                    // OP
                    `RV_OP_JALR, 2'b11
                };
            end else begin
                // add rd, rd, rs1
                valid  = 1;
                result = {
                    // IMM
                    7'b000_0000,
                    // RS2
                    comp[6:2],
                    // RS1
                    comp[11:7],
                    // FUNCT3
                    `RV_ALU_ADD,
                    // RD
                    comp[11:7],
                    // OP
                    `RV_OP_OP, 2'b11
                };
            end
        end else if ( allow_f          && op == `RV_OPC_FSDSP       ) begin
            valid=0;result='bx;//TODO.
        end else if (                     op == `RV_OPC_SWSP        ) begin
            // sw rd, imm(sp)
            valid  = 1;
            result = {
                // IMM
                {4'b0000, comp[8:7], comp[12]},
                // RS2
                comp[6:2],
                // RS1
                5'd2,
                // FUNCT3
                3'd2,
                // IMM
                {comp[11:9], 2'b00},
                // OP
                `RV_OP_STORE, 2'b11
            };
        end else if ((allow_f || rv64) && op == `RV_OPC_FSWSP_SDSP  ) begin
            valid=0;result='bx;//TODO.
        end else begin
            valid  = 0;
            result = 'bx;
        end
    end
    
    // Output mux.
    assign decomp = valid ? result : comp;
endmodule
