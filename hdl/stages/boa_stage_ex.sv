/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

`include "boa_defines.svh"



// Boa³² pipline stage: EX (ALU and address calculation).
module boa_stage_ex(
    // CPU clock.
    input  logic        clk,
    // Synchronous reset.
    input  logic        rst,
    // Invalidate results and clear traps.
    input  logic        clear,
    
    
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
    
    
    // EX/MEM: Result valid.
    output logic        q_valid,
    // EX/MEM: Current instruction PC.
    output logic[31:1]  q_pc,
    // EX/MEM: Current instruction word.
    output logic[31:0]  q_insn,
    // EX/MEM: Stores to register RD.
    output logic        q_use_rd,
    // EX/MEM: Value from RS1 register / ALU result / memory address.
    output logic[31:0]  q_rs1_val,
    // EX/MEM: Value from RS2 register / memory write data.
    output logic[31:0]  q_rs2_val,
    // EX/MEM: Trap raised.
    output logic        q_trap,
    // EX/MEM: Trap cause.
    output logic[3:0]   q_cause,
    
    
    // EX/IF: Mispredicted branch.
    output logic        fw_branch_correct,
    // Stall EX stage.
    input  logic        fw_stall_ex,
    // Produces final result.
    output logic        fw_rd
);
    // ID/EX: Result valid.
    logic       r_valid;
    // ID/EX: Current instruction PC.
    logic[31:1] r_pc;
    // ID/EX: Current instruction word.
    logic[31:0] r_insn;
    // ID/EX: Stores to register RD.
    logic       r_use_rd;
    // ID/EX: Value from RS1 register.
    logic[31:0] r_rs1_val;
    // ID/EX: Value from RS2 register.
    logic[31:0] r_rs2_val;
    // ID/EX: Conditional branch.
    logic       r_branch;
    // ID/EX: Branch prediction result.
    logic       r_branch_predict;
    // ID/EX: Trap raised.
    logic       r_trap;
    // ID/EX: Trap cause.
    logic[3:0]  r_cause;
    
    // Pipeline barrier register.
    always @(posedge clk) begin
        if (rst) begin
            r_valid             <= 0;
            r_pc                <= 'bx;
            r_insn              <= 'bx;
            r_use_rd            <= 'bx;
            r_rs1_val           <= 'bx;
            r_rs2_val           <= 'bx;
            r_branch            <= 'bx;
            r_branch_predict    <= 'bx;
            r_trap              <= 0;
            r_cause             <= 'bx;
        end else if (!fw_stall_ex) begin
            r_valid             <= d_valid;
            r_pc                <= d_pc;
            r_insn              <= d_insn;
            r_use_rd            <= d_use_rd;
            r_rs1_val           <= d_rs1_val;
            r_rs2_val           <= d_rs2_val;
            r_branch            <= d_branch;
            r_branch_predict    <= d_branch_predict;
            r_trap              <= d_trap;
            r_cause             <= d_cause;
        end
    end
    
    
    // Is it an OP or OP-IMM instruction?
    wire is_op  = (r_insn[6:2] == `RV_OP_OP_IMM) || (r_insn[6:2] == `RV_OP_OP);
    // Is it a LOAD or STORE instruction?
    wire is_mem = (r_insn[6:2] == `RV_OP_LOAD)   || (r_insn[6:2] == `RV_OP_STORE);
    // Is it a JAL or JALR instruction?
    wire is_jal = (r_insn[6:2] == `RV_OP_JAL)    || (r_insn[6:2] == `RV_OP_JALR);
    
    // IMM generation.
    logic[31:0] uimm;
    assign uimm[11:0]  = 0;
    assign uimm[31:12] = r_insn[31:12];
    
    logic[31:0] imm12_i;
    assign imm12_i[11:0]  = r_insn[31:20];
    assign imm12_i[31:12] = r_insn[31] * 20'hfffff;
    
    logic[31:0] imm12_s;
    assign imm12_s[4:0]   = r_insn[11:7];
    assign imm12_s[11:5]  = r_insn[31:25];
    assign imm12_s[31:12] = r_insn[31] * 20'hfffff;
    
    // RHS generation for OP-IMM.
    wire [31:0] op_rhs_mux = r_insn[5] ? r_rs2_val : imm12_i;
    
    // Computational units.
    wire        mul_u_lhs = r_insn[13] && r_insn[12];
    wire        mul_u_rhs = r_insn[13];
    wire        div_u     = r_insn[12];
    wire        shr_arith = r_insn[30];
    wire        shr       = r_insn[14];
    wire        muldiv_en = r_insn[25] && r_insn[5];
    logic[63:0] mul_res;
    logic[31:0] div_res;
    logic[31:0] mod_res;
    logic[31:0] shx_res;
    boa_mul_simple mul(mul_u_lhs, mul_u_rhs, r_rs1_val, r_rs2_val, mul_res);
    boa_div_simple div(div_u, r_rs1_val, r_rs2_val, div_res, mod_res);
    boa_shift_simple shift(shr_arith, shr, r_rs1_val, op_rhs_mux, shx_res);
    
    // Adder mode.
    wire        cmp           = (r_insn[6:2] == `RV_OP_BRANCH) || (is_op && ((r_insn[14:12] == `RV_ALU_SLT) || (r_insn[14:12] == `RV_ALU_SLTU)));
    wire        xorh          = cmp && (r_insn[4] ? !r_insn[12] : !r_insn[13]);
    wire        sub           = cmp || ((r_insn[6:2] == `RV_OP_OP) && r_insn[30]);
    
    // Adder operands.
    logic[31:0] add_lhs_mux;
    logic[31:0] add_rhs_mux;
    always @(*) begin
        if (r_insn[6:2] == `RV_OP_LOAD) begin
            // LOAD instructions.
            add_lhs_mux         = r_rs1_val;
            add_rhs_mux         = imm12_s;
        end else if (r_insn[6:2] == `RV_OP_STORE) begin
            // STORE instructions.
            add_lhs_mux         = r_rs1_val;
            add_rhs_mux         = imm12_i;
        end else if ((r_insn[6:2] == `RV_OP_JAL) || (r_insn[6:2] == `RV_OP_JALR)) begin
            // JAL and JALR instructions.
            add_lhs_mux[31:1]   = r_pc;
            add_lhs_mux[0]      = 0;
            add_rhs_mux         = 4;
        end else begin
            // OP and OP-IMM.
            add_lhs_mux         = r_rs1_val;
            add_rhs_mux         = op_rhs_mux;
        end
    end
    
    // Adder.
    logic[31:0] add_lhs;
    logic[31:0] add_rhs;
    assign      add_lhs[30:0] = add_lhs_mux[30:0];
    assign      add_lhs[31]   = add_lhs_mux[31] ^ xorh;
    assign      add_rhs[30:0] = add_rhs_mux[30:0] ^ (sub * 31'h7fff_ffff);
    assign      add_rhs[31]   = add_rhs_mux[31] ^ xorh ^ sub;
    wire [32:0] add_res       = add_lhs + add_rhs + sub;
    
    // The comparator.
    wire        cmp_eq = add_res[31:0] == 0;
    wire        cmp_lt = !cmp_eq && !add_res[32];
    
    // Branch condition evaluation.
    wire   branch_cond       = r_insn[12] ^ (r_insn[14] ? cmp_lt : cmp_eq);
    assign fw_branch_correct = r_valid && (r_insn[6:2] == `RV_OP_BRANCH) && (branch_cond != r_branch_predict);
    
    // Output LHS multiplexer.
    logic[31:0] out_mux;
    always @(*) begin
        if (is_op) begin
            if (muldiv_en) begin
                // MULDIV instructions.
                casez (r_insn[14:12])
                    3'b000:  out_mux = mul_res[31:0];
                    default: out_mux = mul_res[63:32];
                    3'b10?:  out_mux = div_res;
                    3'b11?:  out_mux = mod_res;
                endcase
            end else begin
                // OP and OP-IMM instructions.
                casez (r_insn[14:12])
                    `RV_ALU_ADD:  out_mux = add_res;
                    `RV_ALU_SLL:  out_mux = shx_res;
                    `RV_ALU_SLT:  out_mux = cmp_lt;
                    `RV_ALU_SLTU: out_mux = cmp_lt;
                    `RV_ALU_XOR:  out_mux = r_rs1_val ^ op_rhs_mux;
                    `RV_ALU_SRL:  out_mux = shx_res;
                    `RV_ALU_OR:   out_mux = r_rs1_val | op_rhs_mux;
                    `RV_ALU_AND:  out_mux = r_rs1_val & op_rhs_mux;
                endcase
            end
            fw_rd = r_valid && r_use_rd;
        end else if (is_jal) begin
            // JAL and JALR instructions.
            out_mux = add_res;
            fw_rd   = 1;
        end else if (is_mem) begin
            // LOAD and STORE instructions.
            out_mux = add_res;
            fw_rd   = 0;
        end else if (r_insn[6:2] == `RV_OP_LUI) begin
            // LUI instructions.
            out_mux = uimm;
            fw_rd   = r_valid && r_use_rd;
        end else if (r_insn[6:2] == `RV_OP_AUIPC) begin
            // AUIPC instructions.
            out_mux[31:1] = uimm[31:1] + r_pc[31:1];
            out_mux[0]    = 0;
            fw_rd         = r_valid && r_use_rd;
        end else begin
            // Other instructions.
            out_mux = r_rs1_val;
            fw_rd   = 0;
        end
    end
    
    // Pipeline barrier logic.
    assign q_valid          = r_valid && !clear;
    assign q_pc             = r_pc;
    assign q_insn           = r_insn;
    assign q_use_rd         = r_use_rd;
    assign q_rs1_val        = out_mux;
    assign q_rs2_val        = r_rs2_val;
    assign q_trap           = !clear && r_trap;
    assign q_cause          = r_cause;
endmodule

// Boa³² pipline stage forwarding helper: EX (ALU and address calculation).
module boa_stage_ex_fw(
    // Current instruction word.
    input  logic[31:0]  d_insn,
    
    // Uses value of RS1.
    output logic        use_rs1,
    // Uses value of RS2.
    output logic        use_rs2
);
    // Usage calculator.
    always @(*) begin
        if (d_insn[6:2] == `RV_OP_OP) begin
            // OP instructions.
            use_rs1 = 1;
            use_rs2 = 1;
        end else if (d_insn[6:2] == `RV_OP_OP_IMM) begin
            // OP-IMM instructions.
            use_rs1 = 1;
            use_rs2 = 0;
        end else if (d_insn[6:2] == `RV_OP_BRANCH) begin
            // BRANCH instructions.
            use_rs1 = 1;
            use_rs2 = 1;
        end else if ((d_insn[6:2] == `RV_OP_LOAD) || (d_insn[6:2] == `RV_OP_STORE)) begin
            // LOAD and STORE instructions.
            use_rs1 = 1;
            use_rs2 = 0;
        end else begin
            // Other instructions.
            use_rs1 = 0;
            use_rs2 = 0;
        end
    end
endmodule
