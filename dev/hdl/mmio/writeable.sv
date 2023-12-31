
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// A single word of read-only MMIO.
module boa_peri_writeable#(
    // Base address to respond to.
    parameter addr      = 32'h8000_0000,
    // Default value.
    parameter def_val   = 0
)(
    // CPU clock.
    input  logic        clk,
    // Synchronous reset.
    input  logic        rst,
    
    // Peripheral bus.
    boa_mem_bus.MEM     bus,
    
    // Value to present to the bus.
    output logic[31:0]  value
);
    assign bus.ready = 1;
    always @(posedge clk) begin
        if (rst) begin
            value <= def_val;
            bus.rdata <= 0;
        end else if (bus.addr == addr[bus.alen-1:2]) begin
            if (bus.we[0]) value[7:0]   <= bus.wdata[7:0];
            if (bus.we[1]) value[15:8]  <= bus.wdata[15:8];
            if (bus.we[2]) value[23:16] <= bus.wdata[23:16];
            if (bus.we[3]) value[31:24] <= bus.wdata[31:24];
            bus.rdata <= value;
        end else begin
            bus.rdata <= 0;
        end
    end
endmodule
