/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial-ShareAlike 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc-sa/4.0/
*/

`include "boa_defines.sv"



/*
    Boa³² RV32IM_Zicsr processor.
    
    Pipeline:   5 stages (IF, ID, EX, MEM, WB)
    IPC:        t.b.d.
    Interrupts: 16 external, 1 internal
    Privileges: M-mode
    
    Implemented CSRs:
        0x300   mstatus
        0x301   misa        (RV32IM)
        0x302   medeleg     (0)
        0x303   mideleg     (0)
        0x304   mie
        0x305   mtvec
        0x310   mstatush    (0)
        
        0x344   mip
        0x340   mscratch
        0x341   mepc
        0x342   mcause
        0x343   mtval       (0)
        
        0xf11   mvendorid   (0)
        0xf12   marchid     (0)
        0xf13   mipid       (0)
        0xf14   mhartid     (parameter)
        0xf15   mconfigptr  (0)
*/
module boa32_cpu#(
    // Entrypoint address.
    parameter entrypoint    = 32'h4000_0000,
    // CSR mhartid value.
    parameter hartid        = 32'h0000_0000
)(
    // CPU clock.
    input  logic    clk,
    // Synchronous reset.
    input  logic    rst,
    
    // Program memory bus.
    boa_mem_bus.CPU pbus,
    // Data memory bus.
    boa_mem_bus.CPU dbus,
    
    // External interrupts 16 to 31.
    input  logic[15:0] irq
);
endmodule
