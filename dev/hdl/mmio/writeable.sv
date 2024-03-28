
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`default_nettype none



// A single word of read-only MMIO.
module boa_peri_writeable#(
    // Base address to respond to.
    parameter addr      = 32'h8000_0000,
    // Default value.
    parameter def_val   = 0,
    // Width of value.
    parameter width     = 32
)(
    // CPU clock.
    input  wire         clk,
    // Synchronous reset.
    input  wire         rst,
    
    // Peripheral bus.
    boa_mem_bus.MEM     bus,
    
    // Value to present to the bus.
    output logic[width-1:0]  value
);
    genvar x;
    assign bus.ready = 1;
    
    logic[bus.dlen-1:0] wmask;
    generate
        for (x = 0; x < bus.dlen/8; x = x + 1) begin
            assign wmask[x*8+7:x*8] = bus.we[x] && bus.addr[bus.alen-1:2] == addr[bus.alen-1:2] ? 8'hff : 8'h00;
        end
        for (x = 0; x < width; x = x + 1) begin
            initial begin
                value[x] <= def_val[x];
            end
            always @(posedge clk) begin
                if (rst) begin
                    value[x] <= def_val[x];
                end else if (wmask[x]) begin
                    value[x] <= bus.wdata[x];
                end
            end
        end
    endgenerate
    
    always @(posedge clk) begin
        if (bus.addr[bus.alen-1:2] == addr[bus.alen-1:2]) begin
            bus.rdata <= value;
        end else begin
            bus.rdata <= 0;
        end
    end
endmodule
