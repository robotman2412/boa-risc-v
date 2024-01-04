
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Parametric power of two depth FIFO.
module param_fifo#(
    // Depth of the FIFO, at least 2.
    parameter depth         = 2,
    // Width of the FIFO.
    parameter width         = 8,
    // Accept writes if full, causing the FIFO to return to empty.
    parameter allow_full_we = 1
)(
    // Clock.
    input  logic            clk,
    // Synchronous reset.
    input  logic            rst,
    
    // FIFO write enable.
    input  logic            we,
    // FIFO write data.
    input  logic[width-1:0] wdata,
    
    // FIFO read enable.
    input  logic            re,
    // FIFO read data.
    output logic[width-1:0] rdata,
    
    // FIFO is not empty.
    output logic            has_dat,
    // FIFO is full.
    output logic            full
);
    // FIFO write index.
    logic[$clog2(depth)-1:0]    wpos;
    // FIFO read index.
    logic[$clog2(depth)-1:0]    rpos;
    // FIFO storage.
    logic[width-1:0]            storage[depth];
    
    assign has_dat  = rpos != wpos;
    assign full     = rpos == (wpos+1) % depth;
    assign rdata    = storage[rpos];
    
    always @(posedge clk) begin
        if (rst) begin
            // Reset.
            wpos <= 0;
            rpos <= 0;
        end else begin
            if (re && has_dat) begin
                // Consume a byte from the FIFO.
                rpos            <= rpos + 1;
            end
            if (we && (!full || allow_full_we)) begin
                // Append a byte to the FIFO.
                storage[wpos]   <= wdata;
                wpos            <= wpos + 1;
            end
        end
    end
endmodule
