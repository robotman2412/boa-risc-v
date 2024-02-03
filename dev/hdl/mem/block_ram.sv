
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



// Configurable block memory on a boa memory bus.
module block_ram#(
    // Log2 of number of 32-bit words.
    parameter int    abits      = 8,
    // Initialization file, if any.
    parameter string init_file  = "",
    // ROM mode; writes will be rejected in ROM mode.
    parameter bit    is_rom     = 0
)(
    // Memory clock.
    input  logic    clk,
    // Memory bus.
    boa_mem_bus.MEM bus
);
    // Raw block RAM storage.
    raw_block_ram#(abits, 4, 8, init_file) bram_inst(clk, is_rom ? 0 : bus.we, bus.addr[abits+1:2], is_rom ? 'bx : bus.wdata, bus.rdata);
    assign bus.ready = 1;
endmodule



// Configurable dual-port block memory on a boa memory bus.
module dp_block_ram#(
    // Log2 of number of 32-bit words.
    parameter int    abits      = 8,
    // Initialization file, if any.
    parameter string init_file  = "",
    // ROM mode; writes will be rejected in ROM mode.
    parameter bit    is_rom     = 0
)(
    // Memory clock.
    input  logic    clk,
    // Memory bus A.
    boa_mem_bus.MEM a,
    // Memory bus B.
    boa_mem_bus.MEM b
);
    // Raw block RAM storage.
    raw_dp_block_ram#(abits, 4, 8, init_file) bram_inst(
        clk,
        is_rom ? 0 : a.we, a.addr[abits+1:2], is_rom ? 'bx : a.wdata, a.rdata,
        is_rom ? 0 : b.we, b.addr[abits+1:2], is_rom ? 'bx : b.wdata, b.rdata
    );
    assign a.ready = 1;
    assign b.ready = 1;
endmodule
