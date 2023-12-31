
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
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
    // CSR access bus.
    boa_csr_bus.CPU     csr,
    
    // Perform a release data fence.
    output logic    fence_rl,
    // Perform an acquire data fence.
    output logic    fence_aq,
    
    
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
    input  logic        fw_stall_mem,
    // Stall request.
    output logic        stall_req
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
    
    // Pipeline barrier register.
    always @(posedge clk) begin
        if (rst) begin
            r_valid     <= 0;
            r_pc        <= 'bx;
            r_insn      <= 'bx;
            r_use_rd    <= 'bx;
            r_rs1_val   <= 'bx;
            r_rs2_val   <= 'bx;
        end else if (!fw_stall_mem) begin
            r_valid     <= d_valid;
            r_pc        <= d_pc;
            r_insn      <= d_insn;
            r_use_rd    <= d_use_rd;
            r_rs1_val   <= d_rs1_val;
            r_rs2_val   <= d_rs2_val;
        end
    end
    
    // Raise a trap.
    logic      trap;
    // Trap cause.
    logic[3:0] cause;
    
    
    /* ==== Fence logic ==== */
    // Is this a FENCE instruction?
    logic  is_fence = r_valid  && !clear && !fw_stall_mem && r_insn[6:2] == `RV_OP_MISC_MEM && r_insn[14:12] == 0;
    assign fence_aq = is_fence && r_insn[27:24] != 0;
    assign fence_rl = is_fence && r_insn[23:20] != 0;
    
    /* ==== Memory access logic ==== */
    // Alignment error.
    logic       ealign;
    // Ready.
    logic       ready;
    // Read data.
    logic[31:1] rdata;
    
    // Read enable.
    wire        d_re    = d_valid && !trap && !clear && d_insn[6:2] == `RV_OP_LOAD;
    // Write enable.
    wire        d_we    = d_valid && !trap && !clear && d_insn[6:2] == `RV_OP_STORE;
    // Access is signed.
    wire        d_sign  = !d_insn[14];
    // Access size.
    wire [1:0]  d_asize = d_insn[13:12];
    // Memory access address.
    wire [31:0] d_addr  = d_rs1_val;
    // Data to write.
    wire [31:0] d_wdata = d_rs2_val;
    
    // Read enable.
    logic       r_re;
    // Write enable.
    logic       r_we;
    // Access is signed.
    logic       r_sign;
    // Access size.
    logic[1:0]  r_asize;
    // Memory access address.
    logic[31:0] r_addr;
    // Data to write.
    logic[31:0] r_wdata;
    
    // Memory register select.
    wire        rsel    = (r_re || r_we) && !ready;
    
    always @(posedge clk) begin
        if (rst || clear) begin
            r_re    <= 0;
            r_we    <= 0;
            r_sign  <= 'bx;
            r_asize <= 'bx;
            r_addr  <= 'bx;
            r_wdata <= 'bx;
        end else if (ready || !(r_re || r_we)) begin
            r_re    <= d_re;
            r_we    <= d_we;
            r_sign  <= d_sign;
            r_asize <= d_asize;
            r_addr  <= d_addr;
            r_wdata <= d_wdata;
        end
    end
    
    boa_mem_helper mem_if(
        clk,
        rsel ? r_re : d_re, rsel ? r_we : d_we, rsel ? r_sign : d_sign, rsel ? r_asize : d_asize, rsel ? r_addr : d_addr, rsel ? r_wdata : d_wdata,
        ealign, ready, rdata,
        dbus
    );
    
    
    /* ==== CSR access logic ==== */
    assign     csr.addr  = d_insn[31:20];
    wire[31:0] csr_mask  = d_insn[14] ? d_insn[19:15] : d_rs1_val;
    always @(*) begin
        if (d_insn[13:12] == 2'b01) begin
            csr.wdata = csr_mask;
        end else if (d_insn[13:12] == 2'b10) begin
            csr.wdata = csr.rdata | csr_mask;
        end else if (d_insn[13:12] == 2'b11) begin
            csr.wdata = csr.rdata & ~csr_mask;
        end else begin
            csr.wdata = 'bx;
        end
    end
    logic  csr_re, csr_we;
    always @(*) begin
        if (d_insn[6:2] == `RV_OP_SYSTEM && d_insn[14:12] != 2'b00) begin
            // CSR instruction.
            csr_re = 1;
            csr_we = d_insn[14] || (d_insn[19:15] != 0);
        end else begin
            // Not CSR instruction.
            csr_re = 0;
            csr_we = 0;
        end
    end
    assign csr.we = d_valid && csr_we;
    
    logic       r_csr_re;
    logic[31:0] r_csr_rdata;
    always @(posedge clk) begin
        r_csr_re    <= csr_re;
        r_csr_rdata <= csr.rdata;
    end
    
    
    /* ==== Trap generation logic ==== */
    always @(posedge clk) begin
        if (d_trap) begin
            // Trap from an earlier stage.
            trap    <= 1;
            cause   <= d_cause;
            
        end else if ((mem_if.re || mem_if.we) && mem_if.ealign) begin
            // Memory alignment error.
            trap    <= mem_if.ealign;
            cause   <= mem_if.we ? `RV_ECAUSE_SALIGN : `RV_ECAUSE_LALIGN;
            
        end else if ((csr_re && !csr.exists) || (csr_we && csr.rdonly)) begin
            // CSR access error.
            trap    <= d_valid;
            cause   <= `RV_ECAUSE_IILLEGAL;
            
        end else begin
            trap    <= 0;
            cause   <= 'bx;
        end
    end
    
    
    // Pipeline barrier logic.
    assign  stall_req   = (r_re || r_we) && !mem_if.ready;
    assign  q_valid     = r_valid && !trap && !clear;
    assign  q_pc        = r_pc;
    assign  q_insn      = r_insn;
    assign  q_use_rd    = r_use_rd;
    assign  q_trap      = trap;
    assign  q_cause     = cause;
    always @(*) begin
        if (r_csr_re && !r_re) begin
            q_rd_val = r_csr_rdata;
        end else if (r_re && !r_csr_re) begin
            q_rd_val = mem_if.rdata;
        end else begin
            q_rd_val = r_rs1_val;
        end
    end
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
            end else if (!d_insn[14]) begin
                // CSR* instructions.
                use_rs1 = 1;
                use_rs2 = 0;
            end else begin
                // CSR*I instructions.
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



// Memory access helper.
module boa_mem_helper(
    // CPU clock.
    input  logic        clk,
    
    // Read enable.
    input  logic        re,
    // Write enable.
    input  logic        we,
    // Access is signed.
    input  logic        sign,
    // Access size.
    input  logic[1:0]   asize,
    // Memory access address.
    input  logic[31:0]  addr,
    // Data to write.
    input  logic[31:0]  wdata,
    
    // Alignment error.
    output logic        ealign,
    // Ready.
    output logic        ready,
    // Read data.
    output logic[31:0]  rdata,
    
    // Memory bus.
    boa_mem_bus.CPU     bus
);
    assign ready = bus.ready;
    assign bus.addr[31:2] = addr[31:2];
    
    // Latch the req.
    logic      sign_reg;
    logic[1:0] asize_reg;
    logic[1:0] addr_reg;
    always @(posedge clk) begin
        sign_reg    <= sign;
        asize_reg   <= asize;
        addr_reg    <= addr[1:0];
    end
    
    // Request logic.
    always @(*) begin
        if (asize == 2'b00) begin
            // 8-bit access.
            ealign              = 0;
            bus.re              = re;
            bus.we[0]           = we && (addr[1:0] == 2'b00);
            bus.we[1]           = we && (addr[1:0] == 2'b01);
            bus.we[2]           = we && (addr[1:0] == 2'b10);
            bus.we[3]           = we && (addr[1:0] == 2'b11);
            bus.wdata[7:0]      = wdata[7:0];
            bus.wdata[15:8]     = wdata[7:0];
            bus.wdata[23:16]    = wdata[7:0];
            bus.wdata[31:24]    = wdata[7:0];
            
        end else if (asize == 2'b01) begin
            // 16-bit access.
            ealign              = addr[0];
            bus.re              = re && !addr[0];
            bus.we[0]           = we && !addr[0] && !addr[1];
            bus.we[1]           = we && !addr[0] && !addr[1];
            bus.we[2]           = we && !addr[0] &&  addr[1];
            bus.we[3]           = we && !addr[0] &&  addr[1];
            bus.wdata[15:0]     = wdata[15:0];
            bus.wdata[31:16]    = wdata[15:0];
            
        end else if (asize == 2'b10) begin
            // 32-bit access.
            ealign              = addr[1:0] != 2'b00;
            bus.re              = re && (addr[1:0] == 2'b00);
            bus.we              = we && (addr[1:0] == 2'b00) ? 4'b1111 : 4'b0000;
            bus.wdata           = wdata;
            
        end else begin
            // Illegal instruction.
            bus.re      = 0;
            bus.we      = 0;
            bus.wdata   = 'bx;
            ealign      = 'bx;
        end
    end
    
    // Response logic.
    always @(*) begin
        if (asize_reg == 2'b00) begin
            // 8-bit access.
            case (addr_reg)
                2'b00: rdata[7:0] = bus.rdata[7:0];
                2'b01: rdata[7:0] = bus.rdata[15:8];
                2'b10: rdata[7:0] = bus.rdata[23:16];
                2'b11: rdata[7:0] = bus.rdata[31:24];
            endcase
            rdata[31:8]     = (sign_reg && rdata[7]) ? 24'hff_ffff : 24'h00_0000;
            
        end else if (asize_reg == 2'b01) begin
            // 16-bit access.
            if (!addr_reg[1]) begin
                rdata[15:0] = bus.rdata[15:0];
            end else begin
                rdata[15:0] = bus.rdata[31:16];
            end
            rdata[31:16]    = (sign_reg && rdata[15]) ? 16'hffff : 16'h0000;
            
        end else if (asize_reg == 2'b10) begin
            // 32-bit access.
            rdata           = bus.rdata;
            
        end else begin
            // Illegal instruction.
            rdata   = 'bx;
        end
    end
endmodule
