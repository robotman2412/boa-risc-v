
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`default_nettype none
`include "boa_defines.svh"



// Fetch buffer permission entry.
typedef struct packed {
    // Check was run for M-mode.
    bit m_mode;
    // Allow exec.
    bit x;
} cperm_t;

// Boa³² pipline stage: IF (instruction fetch; 16-bit aligned version).
module boa_stage_if#(
    // Entrypoint address.
    parameter entrypoint    = 32'h4000_0000,
    // Depth of the instruction cache, at least 2.
    parameter cache_depth   = 4,
    // Enable additional latch in IF branch address.
    parameter if_branch_reg = 0
)(
    // CPU clock.
    input  wire         clk,
    // Synchronous reset.
    input  wire         rst,
    // Invalidate results and clear traps.
    input  wire         clear,
    // Current privilege mode.
    input  wire [1:0]   cur_priv,
    
    // Program memory bus.
    boa_mem_bus.CPU     pbus,
    // PMP checking bus.
    boa_pmp_bus.CPU     pmp,
    
    
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
    
    
    // Instruction fetch fence.
    input  wire         fence_i,
    
    // Unconditional control transfer or branch predicted as taken.
    input  wire         fw_branch_predict,
    // Branch target address.
    input  wire [31:1]  fw_branch_target,
    // Address of the next instruction.
    output logic[31:1]  if_next_pc,
    // Branch to be corrected.
    input  wire         fw_branch_correct,
    // Branch correction address.
    input  wire [31:1]  fw_branch_alt,
    // Exception occurred.
    input  wire         fw_exception,
    // Exception vector.
    input  wire [31:2]  fw_tvec,
    
    // Stall IF stage.
    input  wire         fw_stall_if,
    // Clear cache.
    input  wire         fw_cclear
);
    genvar x;
    
    // Instruction read from cache and or pbus.rdata.
    logic[31:0] insn;
    // Whether the current value of `insn` is valid.
    logic       insn_valid;
    // Current program counter.
    logic[31:1] pc         = entrypoint[31:1];
    // Next memory read is valid.
    logic       valid;
    // Address of requested instruction.
    logic[31:1] addr;
    // Requested address is valid.
    logic       addr_valid;
    // Next program counter.
    wire [31:1] next_addr  = addr[31:1] + 1 + (insn[1:0] == 2'b11);
    // Next 16-bit word after address of requested instruction.
    wire [31:1] next_hw    = addr[31:1] + 1;
    
    assign if_next_pc = pc;
    
    generate if (if_branch_reg) begin: with_branch_reg
        // Branch is requested.
        logic branch_req;
        // Branch is requested latch.
        logic branch_req_reg;
        // Next address.
        logic[31:1] next_branch;
        // Next address latch.
        logic[31:1] next_branch_reg;
        // Program counter generation.
        always @(*) begin
            branch_req = 1;
            if (fw_stall_if) begin
                next_branch[31:1] = pc[31:1];
            end else if (fw_exception) begin
                next_branch[31:1] = {fw_tvec[31:2], 1'b0};
            end else if (fw_branch_correct) begin
                next_branch[31:1] = fw_branch_alt[31:1];
            end else if (fw_branch_predict) begin
                next_branch[31:1] = fw_branch_target[31:1];
            end else begin
                branch_req = 0;
                next_branch[31:1] = 'bx;
            end
            addr_valid = !branch_req;
            if (rst) begin
                addr[31:1] = entrypoint[31:1];
            end else if (branch_req_reg) begin
                addr[31:1] = next_branch_reg[31:1];
            end else begin
                addr[31:1] = pc[31:1];
            end
        end
        // Branch address latch.
        always @(posedge clk) begin
            branch_req_reg  <= branch_req;
            next_branch_reg <= next_branch;
        end
    end else begin: without_branch_reg
        // Program counter generation.
        always @(*) begin
            addr_valid = 1;
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
    end endgenerate
    
    // Instruction cache.
    logic[31:0] icache[cache_depth];
    // Address cache.
    logic[31:2] acache[cache_depth];
    // Cache validity.
    logic       cvalid[cache_depth];
    // Cache permission.
    cperm_t     cperm[cache_depth];
    
    // Cache writing logic.
    assign icache[0] = pbus.rdata;
    assign cvalid[0] = pbus.ready;
    always @(posedge clk) begin
        acache[0]       <= pbus.addr;
        cperm[0]        <= {pmp.m_mode, pmp.x};
    end
    wire cwrite = pbus.ready;
    generate
        for (x = 1; x < cache_depth; x = x + 1) begin
            always @(posedge clk) begin
                if (rst || fence_i || fw_cclear) begin
                    icache[x] <= 'bx;
                    acache[x] <= 'bx;
                    cvalid[x] <= 0;
                    cperm[x]  <= 'bx;
                end else if (cwrite) begin
                    icache[x] <= icache[x-1];
                    acache[x] <= acache[x-1];
                    cvalid[x] <= cvalid[x-1];
                    cperm[x]  <= cperm[x-1];
                end
            end
        end
    endgenerate
    
    // Cache reading logic.
    logic       cvalidl;
    logic       cexpirel;
    logic[31:0] crdatal;
    cperm_t     cperml;
    boa_stage_if_creader#(cache_depth) rl(
        cur_priv == 3, icache, acache, cvalid, cperm,
        addr[31:2], cvalidl, cexpirel, crdatal, cperml
    );
    logic       cvalidh;
    logic       cexpireh;
    logic[31:0] crdatah;
    cperm_t     cpermh;
    boa_stage_if_creader#(cache_depth) rh(
        cur_priv == 3, icache, acache, cvalid, cperm,
        next_hw[31:2], cvalidh, cexpireh, crdatah, cpermh
    );
    assign insn[15:0]  = addr[1]    ? crdatal[31:16] : crdatah[15:0];
    assign insn[31:16] = next_hw[1] ? crdatah[31:16] : crdatah[15:0];
    assign insn_valid  = cvalidl && (insn[1:0] != 2'b11 || cvalidh);
    
    // Program bus logic.
    assign pbus.we    = 0;
    assign pbus.wdata = 'bx;
    always @(*) begin
        if (rst || fence_i) begin
            // Reset; don't do anything.
            pbus.re         = 0;
            pbus.addr       = 'bx;
        end else if (!cvalidl) begin
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
    
    // PMP bus logic.
    assign pmp.addr   = pbus.addr;
    assign pmp.m_mode = cur_priv == 3;
    
    // Pipeline output logic.
    always @(*) begin
        q_valid  = 0;
        q_trap   = 0;
        q_cause  = 'bx;
        q_pc     = 'bx;
        q_insn   = 'bx;
        if (!insn_valid || clear || fence_i || fw_cclear) begin
            // No results to give.
        end else if (!cperml.x || (!cpermh.x && insn[1:0] == 2'b11)) begin
            // No permission to execute this address.
            q_trap  = 1;
            q_cause = `RV_ECAUSE_IACCESS;
            q_pc    = addr;
        end else begin
            // Valid instruction.
            q_valid = addr_valid;
            q_pc    = addr;
            q_insn  = insn;
        end
    end
    
    always @(posedge clk) begin
        if (rst) begin
            pc <= entrypoint[31:1];
        end else if (!fw_stall_if) begin
            pc <= insn_valid ? next_addr : addr;
        end
    end
endmodule

// Instruction cache read helper.
module boa_stage_if_creader#(
    // Depth of the instruction cache, at least 2.
    parameter depth   = 2
)(
    // Match M-mode.
    input  wire         m_mode,
    // Instruction cache.
    input  wire [31:0]  icache[depth],
    // Address cache.
    input  wire [31:2]  acache[depth],
    // Cache validity.
    input  wire         cvalid[depth],
    // Cache permission.
    input  cperm_t      cperm[depth],
    
    // Cache read address.
    input  wire [31:2]  addr,
    // Cache read valid.
    output logic        valid,
    // Cache read is about to expire.
    output logic        expire,
    // Cache read data.
    output logic[31:0]  rdata,
    // Cache read permission.
    output cperm_t      rperm
);
    genvar x;
    
    // Address matching logic.
    logic[depth-1:0]    amatch;
    logic[depth-1:0]    amask;
    assign amatch[0] = acache[0] == addr && cvalid[0];
    assign amask [0] = amatch[0];
    generate
        for (x = 1; x < depth; x = x + 1) begin
            assign amatch[x] = acache[x] == addr && cvalid[x] && m_mode == cperm[x].m_mode;
            assign amask [x] = amatch[x-1:0] == 0 && amatch[x];
        end
    endgenerate
    
    // Cache reading logic.
    boa_sel_enc#(depth, 32) rdata_enc(amask, icache, rdata);
    always @(*) begin
        integer i;
        rperm.m_mode = 0;
        rperm.x      = 0;
        for (i = 0; i < depth; i = i + 1) begin
            rperm.m_mode |= amask[i] & cperm[i].m_mode;
            rperm.x      |= amask[i] & cperm[i].x;
        end
    end
    assign valid  = amatch != 0;
    assign expire = amask[depth-1];
endmodule
