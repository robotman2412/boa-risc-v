
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

module top(
    input logic clk
);
    wire rst = 0;
    reg[7:0] cycle;
    always @(posedge clk) begin
        cycle <= cycle + 1;
    end
    
    
    // ID/EX: Result valid.
    logic        d_valid;
    // ID/EX: Current instruction PC.
    logic[31:1]  d_pc;
    // ID/EX: Current instruction word.
    logic[31:0]  d_insn;
    // ID/EX: Stores to register RD.
    logic        d_use_rd;
    // ID/EX: Value from RS1 register.
    logic[31:0]  d_rs1_val;
    // ID/EX: Value from RS2 register.
    logic[31:0]  d_rs2_val;
    // ID/EX: Conditional branch.
    logic        d_branch;
    // ID/EX: Branch prediction result.
    logic        d_branch_predict;
    // ID/EX: Trap raised.
    logic        d_trap;
    // ID/EX: Trap cause.
    logic[3:0]   d_cause;
    
    // ID/EX: Result valid.
    logic        q_valid;
    // ID/EX: Current instruction PC.
    logic[31:1]  q_pc;
    // ID/EX: Current instruction word.
    logic[31:0]  q_insn;
    // ID/EX: Stores to register RD.
    logic        q_use_rd;
    // ID/EX: Value from RS1 register / ALU result / memory address.
    logic[31:0]  q_rs1_val;
    // ID/EX: Value from RS2 register / memory write data.
    logic[31:0]  q_rs2_val;
    // ID/EX: Trap raised.
    logic        q_trap;
    // ID/EX: Trap cause.
    logic[3:0]   q_cause;
    
    // Stall EX stage.
    logic        fw_stall_ex;
    // Stall MEM stage.
    logic        fw_stall_mem;
    
    // Forward value to RS1.
    wire         fw_rs1 = 0;
    // Forward value to RS2.
    wire         fw_rs2 = 0;
    // Forwarding value.
    wire [31:0]  fw_val = 0;
    
    boa_stage_ex stage_ex(
        clk, rst,
        d_valid, d_pc, d_insn, d_use_rd, d_rs1_val, d_rs2_val, d_branch, d_branch_predict, d_trap, d_cause,
        q_valid, q_pc, q_insn, q_use_rd, q_rs1_val, q_rs2_val, q_trap, q_cause,
        fw_stall_ex, fw_stall_mem, fw_rs1, fw_rs2, fw_val
    );
    
    always @(*) begin
        case (cycle)
            default: begin d_valid = 0; d_pc = 0; d_insn = 0; d_use_rd = 0; d_rs1_val = 0; d_rs2_val = 0; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
            
            2:  begin d_valid = 1; d_pc = 'h802; d_insn = 32'h2beef517; d_use_rd = 1; d_rs1_val = 32'h0000_0000; d_rs2_val = 32'h0000_0005; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
            3:  begin d_valid = 1; d_pc = 0;     d_insn = 32'h7ff00513; d_use_rd = 1; d_rs1_val = 32'h0000_0018; d_rs2_val = 32'h0000_0005; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
            4:  begin d_valid = 1; d_pc = 0;     d_insn = 32'h40555513; d_use_rd = 1; d_rs1_val = 32'h800f_0018; d_rs2_val = 32'h0000_0005; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
            5:  begin d_valid = 1; d_pc = 0;     d_insn = 32'h00555513; d_use_rd = 1; d_rs1_val = 32'h800f_0018; d_rs2_val = 32'h0000_0005; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
            
            7:  begin d_valid = 1; d_pc = 0;     d_insn = 32'h00b54533; d_use_rd = 1; d_rs1_val = 32'h0000_1010; d_rs2_val = 32'h0000_1100; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
            8:  begin d_valid = 1; d_pc = 0;     d_insn = 32'h00b57533; d_use_rd = 1; d_rs1_val = 32'h0000_1010; d_rs2_val = 32'h0000_1100; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
            9:  begin d_valid = 1; d_pc = 0;     d_insn = 32'h00b56533; d_use_rd = 1; d_rs1_val = 32'h0000_1010; d_rs2_val = 32'h0000_1100; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
            10: begin d_valid = 1; d_pc = 0;     d_insn = 32'h00b52533; d_use_rd = 1; d_rs1_val = 32'h8000_1010; d_rs2_val = 32'h0000_1100; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
            
            12: begin d_valid = 1; d_pc = 0;     d_insn = 32'h02b50533; d_use_rd = 1; d_rs1_val = 32'hffff_fffd; d_rs2_val = 32'hffff_fffb; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
            13: begin d_valid = 1; d_pc = 0;     d_insn = 32'h02b51533; d_use_rd = 1; d_rs1_val = 32'hffff_fffd; d_rs2_val = 32'hffff_fffb; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
            14: begin d_valid = 1; d_pc = 0;     d_insn = 32'h02b53533; d_use_rd = 1; d_rs1_val = 32'hffff_fffd; d_rs2_val = 32'hffff_fffb; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
            15: begin d_valid = 1; d_pc = 0;     d_insn = 32'h02b52533; d_use_rd = 1; d_rs1_val = 32'hffff_fffd; d_rs2_val = 32'hffff_fffb; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
            
            17: begin d_valid = 1; d_pc = 0;     d_insn = 32'h02b54533; d_use_rd = 1; d_rs1_val = 32'hffff_fffb; d_rs2_val = 32'hffff_fffd; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
            18: begin d_valid = 1; d_pc = 0;     d_insn = 32'h02b56533; d_use_rd = 1; d_rs1_val = 32'hffff_fffb; d_rs2_val = 32'hffff_fffd; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
            19: begin d_valid = 1; d_pc = 0;     d_insn = 32'h02b55533; d_use_rd = 1; d_rs1_val = 32'h8000_0000; d_rs2_val = 32'h0800_0000; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
            20: begin d_valid = 1; d_pc = 0;     d_insn = 32'h02b57533; d_use_rd = 1; d_rs1_val = 32'h8000_0000; d_rs2_val = 32'h0800_0000; d_branch = 0; d_branch_predict = 0; d_trap = 0; d_cause = 0; fw_stall_ex = 0; fw_stall_mem = 0; end
        endcase
    end
endmodule
