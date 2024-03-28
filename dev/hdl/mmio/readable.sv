
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`default_nettype none



// A single word of read-only MMIO.
module boa_peri_readable#(
    // Base address to respond to.
    parameter addr      = 32'h8000_0000
)(
    // CPU clock.
    input  wire         clk,
    // Synchronous reset.
    input  wire         rst,
    
    // Peripheral bus.
    boa_mem_bus.MEM     bus,
    
    // Value to present to the bus.
    input  wire [31:0]  value
);
    assign bus.ready = 1;
    always @(posedge clk) begin
        if (bus.addr[bus.alen-1:2] == addr[bus.alen-1:2]) begin
            bus.rdata <= value;
        end else begin
            bus.rdata <= 0;
        end
    end
endmodule
