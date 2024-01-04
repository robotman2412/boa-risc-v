
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Simulated zero-latency synchronous SRAM.
module raw_sram#(
    // Address width of the SRAM.
    parameter  alen  = 8,
    // Storage depth.
    localparam depth = 1 << alen
)(
    // Write clock.
    input  logic            clk,
    
    // Read enable.
    input  logic            re,
    // Write enable.
    input  logic            we,
    // Address.
    input  logic[alen-1:0]  addr,
    // Write data.
    input  logic[7:0]       wdata,
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
