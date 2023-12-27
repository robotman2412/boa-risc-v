
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`include "boa_defines.svh"



// Boa³² pipline stage: IF (instruction fetch; 32-bit aligned version).
module boa_stage_aligned_if#(
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
    // Branch to be corrected.
    input  logic        fw_branch_correct,
    // Branch correction address.
    input  logic[31:1]  fw_branch_alt,
    // Exception occurred.
    input  logic        fw_exception,
    // Exception vector.
    input  logic[31:2]  fw_tvec,
    
    // Stall IF stage.
    input  logic        fw_stall_if
);
    assign if_next_pc = pc;
    
    // Current program counter.
    logic[31:1] pc      = entrypoint[31:1];
    // Next program counter.
    wire [31:1] next_pc = pc[31:1] + pbus.ready*2;
    // Next memory read is valid.
    logic       valid;
    
    // Program bus logic.
    assign pbus.re      = !fw_stall_if;
    assign pbus.we      = 0;
    assign pbus.wdata   = 'bx;
    always @(*) begin
        if (rst) begin
            pbus.addr[31:2] = entrypoint[31:2];
        end else if (fw_stall_if) begin
            pbus.addr[31:2] = pc[31:2];
        end else if (fw_exception) begin
            pbus.addr[31:2] = fw_tvec[31:2];
        end else if (fw_branch_correct) begin
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
    assign q_pc     = pc;
    assign q_insn   = pbus.rdata;
    always @(posedge clk) begin
        if (!fw_stall_if || rst) begin
            pc[31:2]    <= pbus.addr[31:2];
            pc[1]       <= 0;
        end
    end
endmodule



// Boa³² pipline stage: IF (instruction fetch; 16-bit aligned version).
module boa_stage_if#(
    // Entrypoint address.
    parameter entrypoint    = 32'h4000_0000,
    // Depth of the instruction cache, at least 2.
    parameter cache_depth   = 4
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
    // Branch to be corrected.
    input  logic        fw_branch_correct,
    // Branch correction address.
    input  logic[31:1]  fw_branch_alt,
    // Exception occurred.
    input  logic        fw_exception,
    // Exception vector.
    input  logic[31:2]  fw_tvec,
    
    // Stall IF stage.
    input  logic        fw_stall_if
);
    genvar x;
    assign if_next_pc = pc;
    
    // Instruction read from cache and or pbus.rdata.
    logic[31:0] insn;
    // Which halves of the instruction have been found.
    logic[1:0]  insn_valid;
    // Current program counter.
    logic[31:1] pc         = entrypoint[31:1];
    // Next program counter.
    wire [31:1] next_addr  = addr[31:1] + 1 + (insn[1:0] == 2'b11);
    // Next memory read is valid.
    logic       valid;
    // Address of requested instruction.
    logic[31:1] addr;
    // Next 16-bit word after address of requested instruction.
    wire [31:1] next_hw    = addr[31:1] + 1;
    
    // Program counter generation.
    always @(*) begin
        if (rst) begin
            addr[31:1] = entrypoint[31:1];
        end else if (fw_stall_if) begin
            addr[31:1] = pc[31:1];
        end else if (fw_exception) begin
            addr[31:1] = {fw_tvec[31:2], 1'b0};
        end else if (fw_branch_correct) begin
            addr[31:1] = fw_branch_alt[31:1];
        end else if (fw_branch_predict) begin
            addr[31:1] = fw_branch_target[31:1];
        end else begin
            addr[31:1] = pc[31:1];
        end
    end
    
    // Instruction cache.
    logic[31:0] icache[cache_depth];
    // Address cache.
    logic[31:2] acache[cache_depth];
    // Cache validity.
    logic       cvalid[cache_depth];
    
    // Cache writing logic.
    assign icache[0] = pbus.rdata;
    assign cvalid[0] = pbus.ready;
    always @(posedge clk) begin
        acache[0] <= pbus.addr;
    end
    wire cwrite = pbus.ready;
    generate
        for (x = 1; x < cache_depth; x = x + 1) begin
            always @(posedge clk) begin
                if (rst) begin
                    icache[x] <= 'bx;
                    acache[x] <= 'bx;
                    cvalid[x] <= 0;
                end else if (cwrite) begin
                    icache[x] <= icache[x-1];
                    acache[x] <= acache[x-1];
                    cvalid[x] <= cvalid[x-1];
                end
            end
        end
    endgenerate
    
    // Cache reading logic.
    logic       cvalidl;
    logic       cexpirel;
    logic[31:0] crdatal;
    boa_stage_if_creader#(cache_depth) rl(
        icache, acache, cvalid,
        addr[31:2], cvalidl, cexpirel, crdatal
    );
    logic       cvalidh;
    logic       cexpireh;
    logic[31:0] crdatah;
    boa_stage_if_creader#(cache_depth) rh(
        icache, acache, cvalid,
        next_hw[31:2], cvalidh, cexpireh, crdatah
    );
    assign insn[15:0]  = addr[1]    ? crdatal[31:16] : crdatah[15:0];
    assign insn[31:16] = next_hw[1] ? crdatah[31:16] : crdatah[15:0];
    assign insn_valid  = cvalidl && (insn[1:0] != 2'b11 || cvalidh);
    
    // Program bus logic.
    assign pbus.we    = 0;
    assign pbus.wdata = 'bx;
    always @(*) begin
        if (!cvalidl) begin
            // Fetch lower half of instruction.
            pbus.re         = 1;
            pbus.addr[31:2] = addr[31:2];
        end else if (!cvalidh && insn[1:0] == 2'b11) begin
            // Fetch higher half of instruction.
            pbus.re         = 1;
            pbus.addr[31:2] = next_hw[31:2];
        end else begin
            // Fetch the next word.
            pbus.re         = 1;
            pbus.addr[31:2] = acache[0][31:2] + 1;
        end
    end
    
    // Pipeline output logic.
    assign q_valid  = insn_valid && !clear;
    assign q_trap   = 0;
    assign q_cause  = 'bx;
    
    assign q_pc     = addr;
    assign q_insn   = insn;
    always @(posedge clk) begin
        if (!fw_stall_if || rst) begin
            pc <= insn_valid ? next_addr : addr;
        end
    end
endmodule

// Instruction cache read helper.
module boa_stage_if_creader#(
    // Depth of the instruction cache, at least 2.
    parameter depth   = 2
)(
    // Instruction cache.
    input  logic[31:0] icache[depth],
    // Address cache.
    input  logic[31:2] acache[depth],
    // Cache validity.
    input  logic       cvalid[depth],
    
    // Cache read address.
    input  logic[31:2] addr,
    // Cache read valid.
    output logic       valid,
    // Cache read is about to expire.
    output logic       expire,
    // Cache read data.
    output logic[31:0] rdata
);
    genvar x;
    
    // Address matching logic.
    logic[depth-1:0]    amatch;
    logic[depth-1:0]    amask;
    assign amatch[0] = acache[0] == addr && cvalid[0];
    assign amask [0] = amatch[0];
    generate
        for (x = 1; x < depth; x = x + 1) begin
            assign amatch[x] = acache[x] == addr && cvalid[x];
            assign amask [x] = amatch[x-1:0] == 0 && amatch[x];
        end
    endgenerate
    
    // Cache reading logic.
    logic[31:0] masked_rdata[depth];
    generate
        for (x = 0; x < depth; x = x + 1) begin
            assign masked_rdata[x] = amask[x] ? icache[x] : 0;
        end
    endgenerate
    always @(*) begin
        integer i;
        rdata = 0;
        for (i = 0; i < depth; i = i + 1) begin
            rdata |= masked_rdata[i];
        end
    end
    
    assign valid  = amatch != 0;
    assign expire = amask[depth-1];
endmodule
