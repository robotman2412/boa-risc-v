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
    // Stall MEM stage.
    input  logic        fw_stall_mem,
    
    // Forward value to RS1.
    input  logic        fw_rs1,
    // Forward value to RS2.
    input  logic        fw_rs2,
    // Forwarding input.
    input  logic[31:0]  fw_in,
    
    // Produces final result.
    output logic        fw_rd,
    // Forwarding output.
    output logic[31:0]  fw_out
);
    // Is it an OP or OP-IMM instruction?
    wire is_op  = d_insn[6:2] == `RV_OP_OP_IMM || d_insn[6:2] == `RV_OP_OP;
    // Is it a LOAD or STORE instruction?
    wire is_mem = d_insn[6:2] == `RV_OP_LOAD || d_insn[6:2] == `RV_OP_STORE;
    // Is it a JAL or JALR instruction?
    wire is_jal = d_insn[6:2] == `RV_OP_JAL || d_insn[6:2] == `RV_OP_JALR;
    
    // IMM generation for LUI and AUIPC.
    logic[31:0] uimm;
    assign uimm[11:0]  = 0;
    assign uimm[31:12] = d_insn[31:12];
    
    // RHS generation for OP-IMM.
    logic[31:0] rhs;
    always @(*) begin
        if (d_insn[5]) begin
            rhs = d_rs2_val;
        end else begin
            rhs[11:0]  = d_insn[31:20];
            rhs[31:12] = d_insn[31] * 20'hf_ffff;
        end
    end
    
    // Computational units.
    wire        mul_u_lhs = d_insn[13] && d_insn[12];
    wire        mul_u_rhs = d_insn[13];
    wire        div_u     = d_insn[12];
    wire        shr_arith = d_insn[30];
    wire        shr       = d_insn[14];
    wire        muldiv_en = d_insn[25] && d_insn[5];
    logic[63:0] mul_res;
    logic[31:0] div_res;
    logic[31:0] mod_res;
    logic[31:0] shx_res;
    boa_mul_simple mul(mul_u_lhs, mul_u_rhs, d_rs1_val, d_rs2_val, mul_res);
    boa_div_simple div(div_u, d_rs1_val, d_rs2_val, div_res, mod_res);
    boa_shift_simple shift(shr_arith, shr, d_rs1_val, rhs, shx_res);
    
    // Adder and comparator.
    wire        cmp           = (d_insn[6:2] == `RV_OP_BRANCH) || (is_op && (d_insn[14:12] == `RV_ALU_SLT || d_insn[14:12] == `RV_ALU_SLTU));
    wire        xorh          = cmp && d_insn[4] ? !d_insn[12] : !d_insn[13];
    wire        sub           = cmp || (d_insn[6:2] == `RV_OP_OP && d_insn[30]);
    logic[31:0] add_lhs;
    logic[31:0] add_rhs;
    assign      add_lhs[30:0] = d_rs1_val[30:0];
    assign      add_lhs[31]   = d_rs1_val[31] ^ xorh;
    assign      add_rhs[30:0] = rhs[30:0] ^ (sub * 31'h7fff_ffff);
    assign      add_rhs[31]   = rhs[31] ^ xorh ^ sub;
    wire [32:0] add_res       = add_lhs + add_rhs + sub;
    
    // The comparator.
    wire        cmp_eq = add_res[31:0] == 0;
    wire        cmp_lt = !cmp_eq && !add_res[32];
    
    // Branch condition evaluation.
    wire   branch_cond       = d_insn[12] ^ (d_insn[14] ? cmp_lt : cmp_eq);
    assign fw_branch_correct = d_valid && d_insn[6:2] == `RV_OP_BRANCH && branch_cond != d_branch_predict;
    
    // Output LHS multiplexer.
    logic[31:0] out_mux;
    assign fw_out = out_mux;
    always @(*) begin
        if (is_op) begin
            if (muldiv_en) begin
                // MULDIV instructions.
                casez (d_insn[14:12])
                    3'b000:  out_mux = mul_res[31:0];
                    default: out_mux = mul_res[63:32];
                    3'b10?:  out_mux = div_res;
                    3'b11?:  out_mux = mod_res;
                endcase
            end else begin
                // OP and OP-IMM instructions.
                casez (d_insn[14:12])
                    `RV_ALU_ADD:  out_mux = add_res;
                    `RV_ALU_SLL:  out_mux = shx_res;
                    `RV_ALU_SLT:  out_mux = cmp_lt;
                    `RV_ALU_SLTU: out_mux = cmp_lt;
                    `RV_ALU_XOR:  out_mux = d_rs1_val ^ rhs;
                    `RV_ALU_SRL:  out_mux = shx_res;
                    `RV_ALU_OR:   out_mux = d_rs1_val | rhs;
                    `RV_ALU_AND:  out_mux = d_rs1_val & rhs;
                endcase
            end
            fw_rd = d_valid && d_use_rd;
        end else if (is_jal) begin
            // JAL and JALR instructions.
            out_mux = add_res;
            fw_rd   = 1;
        end else if (is_mem) begin
            // LOAD and STORE instructions.
            out_mux = add_res;
            fw_rd   = 0;
        end else if (d_insn[6:2] == `RV_OP_LUI) begin
            // LUI instructions.
            out_mux = uimm;
            fw_rd   = d_valid && d_use_rd;
        end else if (d_insn[6:2] == `RV_OP_AUIPC) begin
            // AUIPC instructions.
            out_mux[31:1] = uimm[31:1] + d_pc[31:1];
            out_mux[0]    = 0;
            fw_rd         = d_valid && d_use_rd;
        end else begin
            // Other instructions.
            out_mux = d_rs1_val;
            fw_rd   = 0;
        end
    end
    
    // Pipeline barrier logic.
    always @(posedge clk) begin
        if (rst) begin
            q_valid             <= 0;
            q_pc                <= 'bx;
            q_insn              <= 'bx;
            q_use_rd            <= 'bx;
            q_rs1_val           <= 'bx;
            q_rs2_val           <= 'bx;
            q_trap              <= 0;
            q_cause             <= 'bx;
        end else if (!fw_stall_ex) begin
            q_valid             <= d_valid;
            q_pc                <= d_pc;
            q_insn              <= d_insn;
            q_use_rd            <= d_use_rd;
            q_rs1_val           <= fw_rs1 ? fw_in : out_mux;
            q_rs2_val           <= fw_rs2 ? fw_in : d_rs2_val;
            q_trap              <= d_trap;
            q_cause             <= d_cause;
        end else begin
            q_valid <= q_valid && !fw_stall_mem;
        end
    end
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
        end else if (d_insn[6:2] == `RV_OP_BRANCH) begin
            // BRANCH instructions.
            use_rs1 = 1;
            use_rs2 = 1;
        end else if (d_insn[6:2] == `RV_OP_OP_IMM) begin
            // OP-IMM instructions.
            use_rs1 = 1;
            use_rs2 = 0;
        end else if (d_insn[6:2] == `RV_OP_LOAD || d_insn[6:2] == `RV_OP_STORE) begin
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
