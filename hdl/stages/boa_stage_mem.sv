/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

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
    input  logic        fw_stall_mem
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
    // EX/MEM: Trap raised.
    logic       r_trap;
    // EX/MEM: Trap cause.
    logic[3:0]  r_cause;
    
    // Pipeline barrier register.
    always @(posedge clk) begin
        if (rst) begin
            r_valid     <= 0;
            r_pc        <= 'bx;
            r_insn      <= 'bx;
            r_use_rd    <= 'bx;
            r_rs1_val   <= 'bx;
            r_rs2_val   <= 'bx;
            r_trap      <= 0;
            r_cause     <= 'bx;
        end else if (!fw_stall_mem) begin
            r_valid     <= d_valid;
            r_pc        <= d_pc;
            r_insn      <= d_insn;
            r_use_rd    <= d_use_rd;
            r_rs1_val   <= d_rs1_val;
            r_rs2_val   <= d_rs2_val;
            r_trap      <= d_trap;
            r_cause     <= d_cause;
        end
    end
    
    // Raise a trap.
    logic      trap;
    // Trap cause.
    logic[3:0] cause;
    
    // Alignment error.
    logic       ealign;
    // Ready.
    logic       ready;
    // Read data.
    logic       rdata;
    
    // Read enable.
    wire        d_re    = d_valid && d_insn[6:2] == `RV_OP_LOAD;
    // Write enable.
    wire        d_we    = d_valid && d_insn[6:2] == `RV_OP_STORE;
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
            r_asize <= 'bx;
            r_addr  <= 'bx;
            r_wdata <= 'bx;
        end else if (ready || !(r_re || r_we)) begin
            r_re    <= d_re;
            r_we    <= d_we;
            r_asize <= d_asize;
            r_addr  <= d_addr;
            r_wdata <= d_wdata;
        end
    end
    
    // Memory access logic.
    boa_mem_helper mem_if(
        rsel ? r_re : d_re, rsel ? r_we : d_we, rsel ? r_asize : d_asize, rsel ? r_addr : d_addr, rsel ? r_wdata : d_wdata,
        ealign, ready, rdata,
        dbus
    );
    
    
    // Pipeline barrier logic.
    assign  q_valid     = r_valid && !trap && !clear;
    assign  q_pc        = r_pc;
    assign  q_insn      = r_insn;
    assign  q_use_rd    = r_use_rd;
    assign  q_rd_val    = r_rs1_val;
    assign  q_trap      = (r_trap || trap) && !clear;
    assign  q_cause     = r_trap ? r_cause : cause;
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
            end else if (d_insn[14]) begin
                // CSR*I instructions.
                use_rs1 = 1;
                use_rs2 = 0;
            end else begin
                // CSR* instructions.
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
    // Read enable.
    input  logic        re,
    // Write enable.
    input  logic        we,
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
    output logic        rdata,
    
    // Memory bus.
    boa_mem_bus.CPU     bus
);
    // Latch the req.
    logic[1:0] asize_reg;
    logic[1:0] addr_reg;
    always @(posedge clk) begin
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
            bus.we[0]           = we && !addr[0] &&  addr[1];
            bus.we[1]           = we && !addr[0] &&  addr[1];
            bus.we[2]           = we && !addr[0] && !addr[1];
            bus.we[3]           = we && !addr[0] && !addr[1];
            bus.wdata[15:0]     = wdata[15:0];
            bus.wdata[31:16]    = wdata[15:0];
            
        end else if (asize == 2'b10) begin
            // 32-bit access.
            ealign              = addr != 2'b00;
            bus.re              = re && (addr == 2'b00);
            bus.we              = we && (addr == 2'b00) ? 4'b1111 : 4'b0000;
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
        if (asize == 2'b00) begin
            // 8-bit access.
            ready           = bus.ready;
            case (addr_reg)
                2'b00: rdata[7:0] = bus.rdata[7:0];
                2'b01: rdata[7:0] = bus.rdata[15:8];
                2'b10: rdata[7:0] = bus.rdata[23:16];
                2'b11: rdata[7:0] = bus.rdata[31:24];
            endcase
            rdata[31:8]     = 'bx;
            
        end else if (asize == 2'b01) begin
            // 16-bit access.
            ready           = bus.ready || addr_reg[0];
            if (!addr_reg[1]) begin
                rdata[15:0] = bus.rdata[15:0];
            end else begin
                rdata[15:0] = bus.rdata[31:16];
            end
            rdata[31:16]    = 'bx;
            
        end else if (asize == 2'b10) begin
            // 32-bit access.
            ready           = bus.ready || (addr_reg != 2'b00);
            rdata           = bus.rdata;
            
        end else begin
            // Illegal instruction.
            ready   = 1;
            rdata   = 'bx;
        end
    end
endmodule
