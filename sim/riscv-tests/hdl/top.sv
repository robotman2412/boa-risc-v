
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps

module top(
    input  logic        clk,
    output logic        is_ecall,
    output logic        is_ebreak,
    output logic[31:0]  regs[31:0],
    output logic[31:1]  epc
);
    `include "boa_fileio.svh"
    `include "boa_defines.svh"
    
    // To host time.
    assign is_ecall   = cpu.csr_ex.ex_trap && cpu.csr_ex.ex_cause == `RV_ECAUSE_M_ECALL;
    assign is_ebreak  = cpu.csr_ex.ex_trap && cpu.csr_ex.ex_cause == `RV_ECAUSE_EBREAK;
    assign epc        = cpu.csr_ex.ex_epc;
    assign regs[0]    = 0;
    assign regs[31:1] = cpu.st_id.regfile.storage;
    
    // Initial reset generation.
    logic rst = 1;
    always @(posedge clk) begin
        rst <= 0;
    end
    
    // Memory buses.
    boa_mem_bus pbus();
    boa_mem_bus dbus();
    
    // Silly, wacky large amounts of memory.
    dp_block_ram#(16, {boa_parentdir(`__FILE__), "/../obj_dir/rom.mem"}) ram(
        clk, pbus, dbus
    );
    
    // Memory access logging.
    logic p_re;
    logic[31:2] p_addr;
    always @(posedge clk) begin
        p_re   <= dbus.re;
        p_addr <= dbus.addr;
        if (p_re) begin
            $display("READ  0x%x = 0x%x", {p_addr, 2'b00}, dbus.rdata);
        end
        if (dbus.we) begin
            $display("WRITE 0x%x = 0x%x mask 0b%b", {dbus.addr, 2'b00}, dbus.wdata, dbus.we);
        end
    end
    
    // The boa CPU core.
    boa32_cpu#(
        .entrypoint(32'h8000_0000),
        .has_c(1),
        .has_m(1)
    ) cpu (
        clk, clk, rst, pbus, dbus, 0
    );
endmodule

