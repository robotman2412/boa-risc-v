
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`include "boa_defines.svh"



// Boa³² pipline stage: MEM (memory and CSR access).
module boa_stage_mem#(
    // Support A (atomic memory operation) instructions.
    parameter has_a         = 1
)(
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
    // Perform a RMW AMO operation.
    // Always 0 if A extension isn't enabled.
    output logic        amo_rmw,
    // Atomic memory operations bus.
    // Never used if A extension isn't enabled.
    boa_amo_bus.CPU     amo,
    
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
    wire   is_fence = r_valid  && !clear && !fw_stall_mem && r_insn[6:2] == `RV_OP_MISC_MEM && r_insn[14:12] == 0;
    assign fence_aq = is_fence && r_insn[27:24] != 0;
    assign fence_rl = is_fence && r_insn[23:20] != 0;
    
    /* ==== Memory access logic ==== */
    // Alignment error.
    logic       ealign;
    // Ready.
    logic       ready;
    // Read data.
    logic[31:1] rdata;
    
    // Enable RMW AMO logic.
    wire        d_rmw_en    = d_valid && !trap && !clear && d_insn[6:2] == `RV_OP_AMO && d_insn[28:27] == 0;
    // Read enable.
    wire        d_re        = d_valid && !trap && !clear && d_insn[6:2] == `RV_OP_LOAD;
    // Write enable.
    wire        d_we        = d_valid && !trap && !clear && d_insn[6:2] == `RV_OP_STORE;
    // Access is signed.
    wire        d_sign      = !d_insn[14];
    // Access size.
    wire [1:0]  d_asize     = d_insn[13:12];
    // Memory access address.
    wire [31:0] d_addr      = d_rs1_val;
    // Data to write.
    wire [31:0] d_wdata     = d_rs2_val;
    
    // Enable RMW AMO logic.
    logic       r_rmw_en;
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
    wire        rsel    = (r_re || r_we || r_rmw_en) && !ready;
    
    always @(posedge clk) begin
        if (rst || clear) begin
            r_rmw_en    <= 0;
            r_re        <= 0;
            r_we        <= 0;
            r_sign      <= 'bx;
            r_asize     <= 'bx;
            r_addr      <= 'bx;
            r_wdata     <= 'bx;
        end else if (ready || !(r_re || r_we || r_rmw_en)) begin
            r_rmw_en    <= d_rmw_en;
            r_re        <= d_re;
            r_we        <= d_we;
            r_sign      <= d_sign;
            r_asize     <= d_asize;
            r_addr      <= d_addr;
            r_wdata     <= d_wdata;
        end
    end
    
    assign amo_rmw = rsel ? r_rmw_en : d_rmw_en;
    boa_stage_mem_access#(has_a) mem_if(
        clk,
        rsel ? r_rmw_en      : d_rmw_en,
        rsel ? r_insn[31:29] : d_insn[31:29],
        rsel ? r_re          : d_re,
        rsel ? r_we          : d_we,
        rsel ? r_sign        : d_sign,
        rsel ? r_asize       : d_asize,
        rsel ? r_addr        : d_addr,
        rsel ? r_wdata       : d_wdata,
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
    assign  stall_req   = (r_re || r_we || r_rmw_en) && !mem_if.ready;
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
        if (d_insn[6:2] == `RV_OP_AMO) begin
            // AMO instructions.
            use_rs1 = 1;
            use_rs2 = d_insn[28:27] != 2'b10;
        end else if (d_insn[6:2] == `RV_OP_LOAD) begin
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



// RMW AMO write data calculator.
module boa_stage_mem_rmw(
    // Mode for RMW AMOs.
    input  logic[2:0]   amo_mode,
    // Read data.
    input  logic[31:0]  rdata,
    // Write mask / value.
    input  logic[31:0]  wmask,
    // Write data.
    output logic[31:0]  wdata
);
    // Subtract mode.
    logic       sub_mode;
    // Invert adder MSB.
    logic       inv_msb;
    // Adder output.
    logic[31:0] add_res;
    // LHS >= RHS.
    logic       cmp_ge;
    
    // Adder logic.
    always @(*) begin
        bit[31:0] lhs = rdata;
        bit[31:0] rhs = wmask;
        bit[32:0] res;
        if (sub_mode) begin
            rhs ^= 32'hffff_ffff;
        end
        if (inv_msb) begin
            lhs ^= 32'h8000_0000;
            rhs ^= 32'h8000_0000;
        end
        res     = lhs + rhs;
        add_res = res[31:0];
        cmp_ge  = res[32];
    end
    
    // Output multiplexer.
    always @(*) begin
        case(amo_mode)
            3'b000: begin sub_mode=0;   inv_msb=0;   wdata=add_res; end
            3'b001: begin sub_mode='bx; inv_msb='bx; wdata=rdata^wmask; end
            3'b010: begin sub_mode='bx; inv_msb='bx; wdata=rdata|wmask; end
            3'b011: begin sub_mode='bx; inv_msb='bx; wdata=rdata&wmask; end
            3'b100: begin sub_mode=1;   inv_msb=1;   wdata=cmp_ge?wmask:rdata; end
            3'b101: begin sub_mode=1;   inv_msb=1;   wdata=cmp_ge?rdata:wmask; end
            3'b110: begin sub_mode=1;   inv_msb=0;   wdata=cmp_ge?wmask:rdata; end
            3'b111: begin sub_mode=1;   inv_msb=0;   wdata=cmp_ge?rdata:wmask; end
        endcase
    end
endmodule

// Memory access helper.
module boa_stage_mem_access#(
    // Support A (atomic memory operation) instructions.
    parameter has_a         = 1
)(
    // CPU clock.
    input  logic        clk,
    
    // Enable RMW AMO logic.
    input  logic        amo_en,
    // Mode for RMW AMOs.
    input  logic[2:0]   amo_mode,
    
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
    // Data to write or RHS for RMW AMOs.
    input  logic[31:0]  wmask,
    
    // Alignment error.
    output logic        ealign,
    // Ready.
    output logic        ready,
    // Read data.
    output logic[31:0]  rdata,
    
    // Memory bus.
    boa_mem_bus.CPU     bus
);
    assign bus.addr[31:2] = addr[31:2];
    
    // Memory write data.
    logic[31:0] wdata;
    
    // RMW AMO phase; 0 is read, 1 is modify/write.
    logic       amo_stage;
    // RMW AMO read data latch.
    logic[31:0] amo_rdata_reg;
    // RMW AMO write data.
    logic[31:0] amo_wdata;
    
    // Latch the req.
    logic       sign_reg;
    logic[1:0]  asize_reg;
    logic[1:0]  addr_reg;
    always @(posedge clk) begin
        sign_reg    <= sign;
        asize_reg   <= asize;
        addr_reg    <= addr[1:0];
        if (amo_en && amo_stage == 0) begin
            // Transistion from read to modify/write.
            amo_stage       <= 1;
        end else if (amo_en && bus.ready) begin
            // Transition from modify/write to idle or read.
            amo_stage       <= 0;
            amo_rdata_reg   <= bus.rdata;
        end
    end
    
    // Write data logic.
    boa_stage_mem_rmw rmw(amo_mode, bus.ready ? bus.rdata : amo_rdata_reg, wmask, amo_wdata);
    assign wdata = amo_en ? amo_wdata : wmask;
    
    // Request logic.
    always @(*) begin
        bit re_tmp, we_tmp;
        if (amo_en) begin
            // Divide RMW AMOs into two accesses.
            re_tmp = !amo_stage;
            we_tmp = amo_stage;
        end else begin
            // NON-RMW AMO or normal access.
            re_tmp = re;
            we_tmp = we;
        end
        
        if (asize == 2'b00) begin
            // 8-bit access.
            ealign              = 0;
            bus.re              = re_tmp;
            bus.we[0]           = we_tmp && (addr[1:0] == 2'b00);
            bus.we[1]           = we_tmp && (addr[1:0] == 2'b01);
            bus.we[2]           = we_tmp && (addr[1:0] == 2'b10);
            bus.we[3]           = we_tmp && (addr[1:0] == 2'b11);
            bus.wdata[7:0]      = wdata[7:0];
            bus.wdata[15:8]     = wdata[7:0];
            bus.wdata[23:16]    = wdata[7:0];
            bus.wdata[31:24]    = wdata[7:0];
            
        end else if (asize == 2'b01) begin
            // 16-bit access.
            ealign              = addr[0];
            bus.re              = re_tmp && !addr[0];
            bus.we[0]           = we_tmp && !addr[0] && !addr[1];
            bus.we[1]           = we_tmp && !addr[0] && !addr[1];
            bus.we[2]           = we_tmp && !addr[0] &&  addr[1];
            bus.we[3]           = we_tmp && !addr[0] &&  addr[1];
            bus.wdata[15:0]     = wdata[15:0];
            bus.wdata[31:16]    = wdata[15:0];
            
        end else if (asize == 2'b10) begin
            // 32-bit access.
            ealign              = addr[1:0] != 2'b00;
            bus.re              = re_tmp && (addr[1:0] == 2'b00);
            bus.we              = we_tmp && (addr[1:0] == 2'b00) ? 4'b1111 : 4'b0000;
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
        if (amo_stage) begin
            // Override ready to 0 so the CPU waits for the write access too.
            ready = 0;
        end else begin
            // Normal access or second half of RMW.
            ready = bus.ready;
        end
        
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
