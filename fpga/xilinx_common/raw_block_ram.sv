/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

`timescale 1ns/1ps



// Single-port block memory.
module raw_block_ram#(
    // Number of address bits.
    parameter int    abits       = 8,
    // Number of data bytes.
    parameter int    dbytes      = 4,
    // Byte size.
    parameter int    blen        = 8,
    // Initialization file, or "none" if not used.
    // The file must contain hexadecimal values seperated by commas.
    parameter string init_file   = "",
    
    // Number of data bits.
    localparam       dbits       = dbytes * blen
)(
    // RAM clock.
    input  logic                clk,
    // Per-byte write enable.
    input  logic[dbytes-1:0]    we,
    // Address.
    input  logic[abits-1:0]     addr,
    // Write data.
    input  logic[dbits-1:0]     wdata,
    // Read data.
    output logic[dbits-1:0]     rdata
);
    xpm_memory_spram#(
        .ADDR_WIDTH_A(abits),
        .AUTO_SLEEP_TIME(0),
        .BYTE_WRITE_WIDTH_A(blen),
        .CASCADE_HEIGHT(0),
        .MEMORY_INIT_FILE(init_file == "" ? "none" : init_file),
        .MEMORY_SIZE(dbits << abits),
        .RAM_DECOMP("power"),
        .READ_DATA_WIDTH_A(dbits),
        .READ_LATENCY_A(1),
        .WRITE_DATA_WIDTH_A(dbits),
        .WRITE_MODE_A("read_first")
    ) bram_inst (
        .addra(addr),
        .clka(clk),
        .dina(wdata),
        .douta(rdata),
        .ena(1),
        .injectdbiterra(0),
        .injectsbiterra(0),
        .regcea(1),
        .rsta(0),
        .sbiterra(),
        .sleep(0),
        .wea(we)
    );
endmodule



// Dual-port block memory.
module raw_dp_block_ram#(
    // Number of address bits.
    parameter int    abits       = 8,
    // Number of data bytes.
    parameter int    dbytes      = 4,
    // Byte size.
    parameter int    blen        = 8,
    // Initialization file, if any.
    // The file must contain hexadecimal values seperated by commas.
    parameter string init_file   = "",
    
    // Number of data bits.
    localparam       dbits       = dbytes * blen
)(
    // RAM clock.
    input  logic                clk,
    
    // Per-byte write enable.
    input  logic[dbytes-1:0]    a_we,
    // Address.
    input  logic[abits-1:0]     a_addr,
    // Write data.
    input  logic[dbits-1:0]     a_wdata,
    // Read data.
    output logic[dbits-1:0]     a_rdata,
    
    // Per-byte write enable.
    input  logic[dbytes-1:0]    b_we,
    // Address.
    input  logic[abits-1:0]     b_addr,
    // Write data.
    input  logic[dbits-1:0]     b_wdata,
    // Read data.
    output logic[dbits-1:0]     b_rdata
);
    xpm_memory_tdpram#(
        .ADDR_WIDTH_A(abits),
        .ADDR_WIDTH_B(abits),
        .AUTO_SLEEP_TIME(0),
        .BYTE_WRITE_WIDTH_A(blen),
        .BYTE_WRITE_WIDTH_B(blen),
        .CLOCKING_MODE("common_clock"),
        .CASCADE_HEIGHT(0),
        .MEMORY_INIT_FILE(init_file == "" ? "none" : init_file),
        .MEMORY_SIZE(dbits << abits),
        .RAM_DECOMP("power"),
        .READ_DATA_WIDTH_A(dbits),
        .READ_DATA_WIDTH_B(dbits),
        .READ_LATENCY_A(1),
        .READ_LATENCY_B(1),
        .WRITE_DATA_WIDTH_A(dbits),
        .WRITE_DATA_WIDTH_B(dbits),
        .WRITE_MODE_A("read_first"),
        .WRITE_MODE_B("read_first")
    )(
        .addra(a_addr),
        .addrb(b_addr),
        .clka(clk),
        .clkb(clk),
        .dina(a_wdata),
        .dinb(b_wdata),
        .douta(a_rdata),
        .doutb(b_rdata),
        .ena(1),
        .enb(1),
        .injectdbiterra(0),
        .injectdbiterrb(0),
        .injectsbiterra(0),
        .injectsbiterrb(0),
        .regcea(1),
        .regceb(1),
        .rsta(0),
        .rstb(0),
        .sbiterra(),
        .sbiterrb(),
        .sleep(0),
        .wea(a_we),
        .web(b_we)
    );
endmodule
