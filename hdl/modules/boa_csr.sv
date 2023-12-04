/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

`timescale 1ns/1ps
`include "boa_defines.svh"



// Boa³² CSR exception event bus.
interface boa_csr_ex_bus;
    // CPU -> CSR: Synchronous trap.
    logic       ex_trap;
    // CPU -> CSR: Asynchrounous interrupt.
    logic       ex_irq;
    // CPU -> CSR: Exception is serviced in M-mode.
    logic       ex_priv;
    // CPU -> CSR: Exception program counter.
    logic[31:2] ex_epc;
    // CPU -> CSR: Exception cause.
    logic[4:0]  ex_cause;
    // CSR -> CPU: Exception vector address.
    logic[31:1] ex_tvec;
    
    // CPU -> CSR: Return from exception.
    logic       ret;
    // CPU -> CSR: Returning to M-mode.
    logic       ret_priv;
    // CSR -> CPU: Exception program counter.
    logic[31:1] ret_epc;
    
    // CPU -> CSR: Interrupts pending.
    logic[31:0] irq_ip;
    // CSR -> CPU: M-mode interrupts enabled.
    logic[31:0] irq_mie;
    // CSR -> CPU: M-mode interrupts delegated.
    logic[31:0] irq_mideleg;
    // CSR -> CPU: M-mode exceptions delegated.
    logic[31:0] irq_medeleg;
    // CSR -> CPU: Masked interrupts pending.
    logic[31:0] irq_sie;
    
    // Directions from CPU perspective.
    modport CPU (output ex_trap, ex_irq, ex_priv, ex_epc, ex_cause, input  ex_tvec, output ret, ret_priv, input  ret_epc, output irq_ip, input  irq_mie, irq_mideleg, irq_medeleg, irq_sie);
    // Directions from CSR perspective.
    modport CSR (input  ex_trap, ex_irq, ex_priv, ex_epc, ex_cause, output ex_tvec, input  ret, ret_priv, output ret_epc, input  irq_ip, output irq_mie, irq_mideleg, irq_medeleg, irq_sie);
endinterface



// Boa³² CSR access bus.
// Latency: 0.
interface boa_csr_bus;
    // CPU -> CSR: Write enable.
    logic       we;
    // CPU -> CSR: CSR address.
    logic[11:0] addr;
    // CPU -> CSR: Write data.
    logic[31:0] wdata;
    // CSR -> CPU: CSR exists.
    logic       exists;
    // CSR -> CPU: CSR is read-only.
    logic       rdonly;
    // CSR -> CPU: CSR privilege requirement.
    logic[1:0]  priv;
    // CSR -> CPU: Read data.
    logic[31:0] rdata;
    
    // Directions from CPU perspective.
    modport CPU (output we, addr, wdata, input exists, rdonly, priv, rdata);
    // Directions from CSR perspective.
    modport CSR (output exists, rdonly, priv, rdata, input we, addr, wdata);
endinterface



// Boa³² CSR write data helper.
module boa_csrw_helper(
    // RS1 / immediate value.
    input  logic[31:0]  wmask,
    // Read data.
    input  logic[31:0]  rdata,
    // Write mode.
    input  logic[1:0]   wmode,
    // Write data.
    output logic[31:0]  wdata
);
    always @(*) begin
        case (wmode)
            default: wdata = 'bx;
            2'b01:   wdata = wmask;
            2'b10:   wdata = rdata |  wmask;
            2'b11:   wdata = rdata & ~wmask;
        endcase
    end
endmodule
