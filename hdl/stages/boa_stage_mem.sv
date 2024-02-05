
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`include "boa_defines.svh"



// Boa³² pipline stage: MEM (memory and CSR access).
module boa_stage_mem#(
    // Support A (atomic memory operation) instructions.
    parameter has_a         = 1,
    // Enable additional latch for RMW AMOs.
    parameter rmw_amo_reg   = 0
)(
    // CPU clock.
    input  logic        clk,
    // Synchronous reset.
    input  logic        rst,
    // Invalidate results and clear traps.
    input  logic        clear,
    // Current privilege mode.
    input  logic[1:0]   cur_priv,
    // Effective memory privilege mode.
    input  logic[1:0]   mem_priv,
    
    // Data memory bus.
    boa_mem_bus.CPU     dbus,
    // PMP checking bus.
    boa_pmp_bus.CPU     pmp,
    // CSR access bus.
    boa_csr_bus.CPU     csr,
    // Current memory access is an AMO (disable caches).
    // Always 0 if A extension isn't enabled.
    output logic        amo_en,
    // Atomic reservation bus for LR/SC sequences.
    // Never used if A extension isn't enabled.
    boa_amo_bus.CPU     resv_bus,
    
    // Perform a release data fence.
    output logic        fence_rl,
    // Perform an acquire data fence.
    output logic        fence_aq,
    
    
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
    output logic        stall_req,
    // Virtual address for traps.
    output logic[31:0]  mem_vaddr
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
    
    // Enable RMW AMO logic.
    logic       d_rmw_en;
    // Enable atomic memory access.
    logic       d_amo_en;
    // Read enable.
    logic       d_re;
    // Write enable.
    logic       d_we;
    // Access is signed.
    wire        d_sign      = !d_insn[14];
    // Access size.
    wire [1:0]  d_asize     = d_insn[13:12];
    // Memory access address.
    wire [31:0] d_addr      = d_rs1_val;
    // Data to write.
    wire [31:0] d_wdata     = d_rs2_val;
    
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
    always @(*) begin
        fence_aq = 0;
        fence_rl = 0;
        if (!r_valid || clear || rst || fw_stall_mem) begin
            // Invalid instruction, no fencing.
        end else if (r_insn[6:2] == `RV_OP_MISC_MEM && r_insn[14:12] == 0) begin
            // FENCE instruction.
            fence_aq = r_insn[27:24] != 0;
            fence_rl = r_insn[23:20] != 0;
        end else if (has_a && r_insn[6:2] == `RV_OP_AMO) begin
            // AMO instruction.
            fence_aq = r_insn[26];
            fence_rl = r_insn[25];
        end
    end
    
    /* ==== Reservation logic ==== */
    // Whether to keep the reservation next cycle.
    logic       resv_keep;
    // Whether the reservation is currently valid.
    logic       resv_valid;
    // The address of the reservation.
    logic[31:2] resv_addr;
    // How many instructions ago the reservation was made.
    logic[3:0]  resv_age;
    // Whether a SC was successfull.
    logic       sc_success;
    
    generate
        if (has_a) begin: a
            always @(*) begin
                if (!d_valid || trap || clear) begin
                    // Invalid instruction, no memory access.
                    resv_bus.req    = resv_valid;
                    resv_keep       = 1;
                end else if (d_insn[6:2] == `RV_OP_LOAD) begin
                    // Load instructions.
                    resv_bus.req    = 0;
                    resv_keep       = 0;
                end else if (d_insn[6:2] == `RV_OP_STORE) begin
                    // Store instructions.
                    resv_bus.req    = 0;
                    resv_keep       = 0;
                end else if (has_a && d_insn[6:2] == `RV_OP_AMO && d_insn[28] == 0) begin
                    // Read-modify-write AMO instructions.
                    resv_bus.req    = 0;
                    resv_keep       = 0;
                end else if (has_a && d_insn[6:2] == `RV_OP_AMO && d_insn[28:27] == 2'b10) begin
                    // LR instructions.
                    resv_bus.req    = d_addr[1:0] == 0;
                    resv_keep       = 1;
                end else if (has_a && d_insn[6:2] == `RV_OP_AMO && d_insn[28:27] == 2'b11) begin
                    // SC instructions.
                    resv_bus.req    = resv_valid;
                    resv_keep       = 0;
                end else begin
                    // Other instructions.
                    resv_bus.req    = resv_valid;
                    resv_keep       = 1;
                end
                if (resv_valid && resv_age == 15) begin
                    // Ran outta time.
                    resv_keep       = 0;
                end
            end
            
            always @(posedge clk) begin
                // Reservation validity logic.
                resv_valid <= !rst && !trap && !clear && resv_bus.valid && resv_keep;
                // Reservation age logic.
                if (resv_valid && d_valid && !trap && !clear) begin
                    resv_age    <= resv_age + 1;
                end
                if (!resv_valid && resv_bus.req) begin
                    // Reservation outdated.
                    resv_addr   <= d_addr[31:2];
                    resv_age    <= 0;
                end
                
                if (!d_valid || trap || clear) begin
                    // Invalid instruction, no memory access.
                end else if (has_a && d_insn[6:2] == `RV_OP_AMO && d_insn[28:27] == 2'b11) begin
                    // SC instructions.
                    sc_success  <= d_we;
                end
            end
        end else begin: not_a
            assign resv_bus.req = 0;
            assign resv_keep    = 'bx;
            assign resv_valid   = 0;
            assign resv_addr    = 'bx;
            assign resv_age     = 'bx;
        end
    endgenerate
    
    /* ==== Memory access logic ==== */
    // Alignment error.
    logic       ealign;
    // Ready.
    logic       ready;
    // Read data.
    logic[31:1] rdata;
    
    always @(*) begin
        d_rmw_en = 0;
        d_amo_en = 0;
        d_re     = 0;
        d_we     = 0;
        if (!d_valid || trap || clear) begin
            // Invalid instruction, no memory access.
        end else if (d_insn[6:2] == `RV_OP_LOAD) begin
            // Load instructions.
            d_re        = 1;
        end else if (d_insn[6:2] == `RV_OP_STORE) begin
            // Store instructions.
            d_we        = 1;
        end else if (has_a && d_insn[6:2] == `RV_OP_AMO && d_insn[28:27] == 2'b00) begin
            // Read-modify-write AMO instructions.
            d_rmw_en    = 1;
            d_amo_en    = 1;
        end else if (has_a && d_insn[6:2] == `RV_OP_AMO && d_insn[28:27] == 2'b01) begin
            // AMOSWAP instructions.
            d_re        = 1;
            d_we        = 1;
            d_amo_en    = 1;
        end else if (has_a && d_insn[6:2] == `RV_OP_AMO && d_insn[28:27] == 2'b10) begin
            // LR instructions.
            d_re        = 1;
            d_amo_en    = 1;
        end else if (has_a && d_insn[6:2] == `RV_OP_AMO && d_insn[28:27] == 2'b11) begin
            // SC instructions.
            d_we        = resv_bus.valid && d_addr[31:2] == resv_addr[31:2] && d_addr[1:0] == 0;
            d_amo_en    = resv_bus.valid;
        end
    end
    
    assign pmp.m_mode = mem_priv == 3;
    assign pmp.addr   = d_addr >> 2;
    
    // Enable RMW logic.
    logic       r_rmw_en;
    // Enable atomic memory access.
    logic       r_amo_en;
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
    // PMP read permission.
    logic       r_pmp_r;
    // PMP write permission.
    logic       r_pmp_w;
    
    // Memory register select.
    wire        rsel    = (r_re || r_we || r_rmw_en) && !ready;
    
    always @(posedge clk) begin
        if (rst || clear) begin
            // Reset.
            r_rmw_en    <= 0;
            r_amo_en    <= 0;
            r_re        <= 0;
            r_we        <= 0;
            r_sign      <= 'bx;
            r_asize     <= 'bx;
            r_addr      <= 'bx;
            r_wdata     <= 'bx;
            r_pmp_r     <= 'bx;
            r_pmp_w     <= 'bx;
        end else if (ready || !(r_re || r_we || r_rmw_en)) begin
            // Set up memory access.
            r_rmw_en    <= d_rmw_en;
            r_amo_en    <= d_amo_en;
            r_re        <= d_re;
            r_we        <= d_we;
            r_sign      <= d_sign;
            r_asize     <= d_asize;
            r_addr      <= d_addr;
            r_wdata     <= d_wdata;
            r_pmp_r     <= pmp.r;
            r_pmp_w     <= pmp.w;
        end
    end
    
    assign amo_en = rsel ? r_amo_en : d_amo_en;
    boa_stage_mem_access#(.has_a(has_a), .rmw_amo_reg(rmw_amo_reg)) mem_if(
        clk, rst,
        rsel ? r_rmw_en && r_pmp_r && r_pmp_w : d_rmw_en && pmp.r && pmp.w,
        rsel ? r_insn[31:29]    : d_insn[31:29],
        rsel ? r_re && r_pmp_r  : d_re && pmp.r,
        rsel ? r_we && r_pmp_w  : d_we && pmp.w,
        rsel ? r_sign           : d_sign,
        rsel ? r_asize          : d_asize,
        rsel ? r_addr           : d_addr,
        rsel ? r_wdata          : d_wdata,
        ealign, ready, rdata,
        dbus
    );
    
    // Permission checking logic.
    wire  pmp_re    = rsel ? r_re : d_re;
    wire  pmp_we    = rsel ? (r_we || r_amo_en) : (d_we || d_amo_en);
    wire  pmp_r     = rsel ? r_pmp_r : pmp.r;
    wire  pmp_w     = rsel ? r_pmp_w : pmp.w;
    
    
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
    assign  mem_vaddr   = r_addr;
    always @(posedge clk) begin
        if (d_trap) begin
            // Trap from an earlier stage.
            trap    <= 1;
            cause   <= d_cause;
            
        end else if (pmp_we && !pmp_w) begin
            // Store/AMO access fault.
            trap    <= 1;
            cause   <= `RV_ECAUSE_SACCESS;
            
        end else if (pmp_re && !pmp_r) begin
            // Load access fault.
            trap    <= 1;
            cause   <= `RV_ECAUSE_LACCESS;
            
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
        if (r_csr_re) begin
            // CSR instructions.
            q_rd_val = r_csr_rdata;
        end else if (r_re || r_rmw_en) begin
            // Memory access.
            q_rd_val = mem_if.rdata;
        end else if (has_a && r_insn[6:2] == `RV_OP_AMO && r_insn[28:27] == 2'b11) begin
            // Store conditional.
            q_rd_val = !sc_success;
        end else begin
            // Other instructions.
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
    input  logic[2:0]   rmw_mode,
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
        automatic bit[31:0] lhs;
        automatic bit[31:0] rhs;
        automatic bit[32:0] res;
        lhs = rdata;
        rhs = wmask;
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
        case(rmw_mode)
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
    parameter has_a         = 1,
    // Enable additional latch for RMW AMOs.
    parameter rmw_amo_reg   = 0
)(
    // CPU clock.
    input  logic        clk,
    // Synchronous reset.
    input  logic        rst,
    
    // Enable RMW AMO logic.
    input  logic        rmw_en,
    // Mode for RMW AMOs.
    input  logic[2:0]   rmw_mode,
    
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
    
    // RMW AMO phase; 0 is read, 1 is delay, 2 is modify/write.
    logic[1:0]  amo_stage;
    // RMW AMO read data latch.
    logic[31:0] amo_rdata_reg;
    // RMW AMO write data.
    logic[31:0] amo_wdata;
    
    // Latch the req.
    logic       sign_reg;
    logic[1:0]  asize_reg;
    logic[1:0]  addr_reg;
    always @(posedge clk) begin
        if (rst) begin
            sign_reg        <= 'bx;
            asize_reg       <= 'bx;
            addr_reg        <= 'bx;
            amo_stage       <= 0;
            amo_rdata_reg   <= 'bx;
        end else begin
            sign_reg    <= sign;
            asize_reg   <= asize;
            addr_reg    <= addr[1:0];
            if (has_a && rmw_en && amo_stage == 0) begin
                // Transistion from read to delay or modify/write.
                amo_stage       <= rmw_amo_reg ? 1 : 2;
            end else if (has_a && rmw_amo_reg && amo_stage == 1) begin
                // Transision from delay to modify/write.
                amo_stage       <= 2;
                amo_rdata_reg   <= bus.rdata;
            end else if (has_a && rmw_en && bus.ready) begin
                // Transition from modify/write to idle or read.
                amo_stage       <= 0;
                amo_rdata_reg   <= bus.rdata;
            end
        end
    end
    
    // Write data logic.
    generate
        if (has_a && !rmw_amo_reg) begin: a0
            boa_stage_mem_rmw rmw(rmw_mode, bus.ready ? bus.rdata : amo_rdata_reg, wmask, amo_wdata);
            assign wdata = rmw_en ? amo_wdata : wmask;
        end else if (has_a) begin: a1
            boa_stage_mem_rmw rmw(rmw_mode, amo_rdata_reg, wmask, amo_wdata);
            assign wdata = rmw_en ? amo_wdata : wmask;
        end else begin: not_a
            assign wdata = wmask;
        end
    endgenerate
    
    // Request logic.
    always @(*) begin
        bit re_tmp, we_tmp;
        if (has_a && rmw_en) begin
            // Divide RMW AMOs into two accesses.
            re_tmp = amo_stage != 2;
            we_tmp = amo_stage == 2;
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
        if (has_a && amo_stage) begin
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
