
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Simple GPIO matrix peripheral.
module boa_peri_gpio#(
    // Base address to respond to.
    parameter addr      = 32'h8000_0000,
    // Number of GPIO pins, 2 to bus.dlen.
    parameter pins      = 32,
    // Number of external signals for GPIO matrix, 1 to 65536.
    parameter num_ext   = 1
)(
    // Peripheral bus clock.
    input  logic                clk,
    // Synchronous reset.
    input  logic                rst,
    // Peripheral bus interface.
    boa_mem_bus.MEM             bus,
    
    // External signals for GPIO matrix.
    input  logic[num_ext-1:0]   ext,
    // External output enable signals for GPIO matrix.
    input  logic[num_ext-1:0]   ext_oe,
    
    // Outputs.
    output logic[pins-1:0]      pin_out,
    // Output enable.
    output logic[pins-1:0]      pin_oe,
    // Inputs.
    input  logic[pins-1:0]      pin_in
);
    genvar x;
    assign bus.ready = 1;
    
    // Basic output register.
    logic[pins-1:0]             out_reg;
    // Output enable register.
    logic[pins-1:0]             oe_reg;
    // Pin signal selections.
    logic[$clog2(num_ext-1):0]  sel_reg[pins];
    // Pin signal enable.
    logic                       ext_reg[pins];
    
    // Pin output logic.
    generate
        for (x = 0; x < pins; x = x + 1) begin
            assign pin_out[x] = ext_reg[x] ? ext   [sel_reg[x]] : out_reg[x];
            assign pin_oe [x] = ext_reg[x] ? ext_oe[sel_reg[x]] : oe_reg [x];
        end
    endgenerate
    
    // Memory access logic.
    logic[pins-1:0] pin_in_reg;
    always @(posedge clk) begin
        pin_in_reg <= pin_in;
        if (rst) begin
            integer i;
            out_reg <= 0;
            oe_reg  <= 0;
            for (i = 0; i < pins; i = i + 1) begin
                sel_reg[i] <= 0;
                ext_reg[i] <= 0;
            end
            bus.rdata <= 0;
        end else if (bus.addr<<2 == addr) begin
            // Parallel output.
            bus.rdata               <= pin_in_reg;
            if (bus.we == 15) begin
                out_reg                 <= bus.wdata;
            end
        end else if (bus.addr<<2 == addr+4) begin
            // Parallel output enable.
            bus.rdata               <= oe_reg;
            if (bus.we == 15) begin
                oe_reg                  <= bus.wdata;
            end
        end else if (bus.addr[bus.alen-1:7] == addr[31:7]+1) begin
            // Pin configuration.
            bus.rdata[15:0]         <= sel_reg[bus.addr[6:2]];
            bus.rdata[16]           <= ext_reg[bus.addr[6:2]];
            bus.rdata[31:17]        <= 0;
            if (bus.we == 15) begin
                sel_reg[bus.addr[6:2]]  <= bus.wdata[15:0];
                ext_reg[bus.addr[6:2]]  <= bus.wdata[16];
            end
        end
    end
endmodule
