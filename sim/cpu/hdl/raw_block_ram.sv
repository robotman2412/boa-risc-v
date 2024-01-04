
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Single-port block memory.
module raw_block_ram#(
    // Number of address bits.
    parameter int    abits       = 8,
    // Number of data bytes.
    parameter int    dbytes      = 4,
    // Byte size.
    parameter int    blen        = 8,
    // Generate write-before-read instead of read-before-write.
    parameter bit    write_first = 0,
    // Initialization file, if any.
    // The file must contain hexadecimal values seperated by commas.
    parameter string init_file   = "",
    
    // Number of data bits.
    localparam       dbits       = dbytes * blen
)(
    // RAM clock.
    input  logic            clk,
    // Per-byte write enable.
    input  logic[dbytes-1:0] we,
    // Address.
    input  logic[abits-1:0] addr,
    // Write data.
    input  logic[dbits-1:0] wdata,
    // Read data.
    output logic[dbits-1:0] rdata
);
    `include "boa_fileio.svh"
    genvar i;
    
    // Data storage.
    reg[dbits-1:0] storage[1 << abits];
        
    // Initial value in simulation.
    initial begin
        // Initially fill with zeroes.
        integer i, fd, tmp, ord, waddr;
        string data;
        for (i = 0; i < 1 << abits; i = i + 1) begin
            storage[i] = 0;
        end
        
        if (init_file != "") begin
            $display("Loading init file at %s", init_file);
            data = boa_load_file(init_file);
            tmp  = 0;
            for (i = 0; i < data.len(); i = i + 1) begin
                ord = data.getc(i);
                if (ord >= 8'h30 && ord <= 8'h39) begin
                    tmp = tmp << 4;
                    tmp = tmp | ord[3:0];
                end else if (ord >= 8'h41 && ord <= 8'h46) begin
                    tmp = tmp << 4;
                    tmp = tmp | ord - 8'h41 + 8'h0A;
                end else if (ord >= 8'h61 && ord <= 8'h66) begin
                    tmp = tmp << 4;
                    tmp = tmp | ord - 8'h61 + 8'h0A;
                end else if (ord == 8'h2C) begin
                    storage[waddr] = tmp;
                    waddr = waddr + 1;
                    tmp = 0;
                end else if (ord > 32) begin
                    $display("Error: Unexpected character '%s'", ord);
                    $finish;
                end
            end
            storage[waddr] = tmp;
        end
    end
    
    generate
        // Read logic.
        if (write_first) begin: gen_bram_wfirst
            for (i = 0; i < dbytes; i = i + 1) begin
                always @(posedge clk) begin
                    if (we[i]) begin
                        rdata[(i+1)*blen-1:i*blen] <= wdata[(i+1)*blen-1:i*blen];
                    end else begin
                        rdata[(i+1)*blen-1:i*blen] <= storage[addr][(i+1)*blen-1:i*blen];
                    end
                end
            end
        end else begin: gen_bram_rfirst
            always @(posedge clk) begin
                rdata <= storage[addr];
            end
        end
        
        // Write logic.
        for (i = 0; i < dbytes; i = i + 1) begin
            always @(posedge clk) begin
                if (we[i]) begin
                    storage[addr][(i+1)*blen-1:i*blen] <= wdata[(i+1)*blen-1:i*blen];
                end
            end
        end
    endgenerate
    
    // Displaying logic.
    logic[dbits-1:0] smask;
    generate
        for (i = 0; i < dbytes; i = i + 1) begin
            always @(*) begin
                if (we[i]) begin
                    smask[(i+1)*blen-1:i*blen] = wdata[(i+1)*blen-1:i*blen];
                end else begin
                    smask[(i+1)*blen-1:i*blen] = storage[addr][(i+1)*blen-1:i*blen];
                end
            end
        end
    endgenerate
    always @(posedge clk) begin
        if (we != 0) begin
            $display("[%x] = %x", addr, smask);
        end
    end
endmodule
