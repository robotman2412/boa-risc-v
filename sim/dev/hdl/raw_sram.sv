
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`default_nettype none



// Simulated zero-latency synchronous SRAM.
module raw_sram#(
    // Address width of the SRAM.
    parameter  alen  = 8,
    // Storage depth.
    localparam depth = 1 << alen
)(
    // Write clock.
    input  wire             clk,
    
    // Read enable.
    input  wire             re,
    // Write enable.
    input  wire             we,
    // Address.
    input  wire [alen-1:0]  addr,
    // Write data.
    input  wire [7:0]       wdata,
    // Read data.
    output logic[7:0]       rdata
);
    // Data storage.
    logic[7:0]  storage[depth];
    
    // Read access logic.
    assign rdata = re && !we ? storage[addr] : 'bz;
    // Write access logic.
    always @(posedge clk) begin
        if (we) begin
            storage[addr] <= wdata;
        end
    end
endmodule
