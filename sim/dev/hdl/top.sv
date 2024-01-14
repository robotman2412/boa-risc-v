
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



module top(
    input  logic clk,
    output logic tx,
    input  logic rx
);
    `include "boa_fileio.svh"
    logic rst = 1;
    logic rtc_clk;
    param_clk_div#(10, 1) rtc_div(clk, rtc_clk);
    
    localparam xm_alen = 19;
    
    // Bus definitions.
    logic[31:0]  gpio_out;
    logic[31:0]  gpio_oe;
    logic[31:0]  gpio_in;
    assign gpio_in = gpio_out;
    logic[31:0] randomness = $urandom();
    boa_mem_bus#(12) xmp_bus();
    boa_mem_bus#(xm_alen) extrom_bus();
    boa_mem_bus#(xm_alen) extram_bus();
    pmu_bus pmb();
    
    // Fence signals.
    logic fence_rl, fence_aq, fence_i;
    
    // Main microcontroller device.
    main#(
        .rom_file({boa_parentdir(`__FILE__), "/../obj_dir/rom.mem"}),
        .uart_buf(65536),
        .uart_div(4),
        .is_simulator(1),
        .extrom_alen(xm_alen),
        .extram_alen(xm_alen)
    ) main (
        clk, rtc_clk, rst,
        tx, rx,
        gpio_out, gpio_oe, gpio_in,
        randomness,
        xmp_bus, extrom_bus, extram_bus,
        fence_rl, fence_aq, fence_i,
        pmb
    );
    
    // Additional peripherals.
    // Extmem size device.
    boa_peri_readable#('h600) xm_size(clk, rst, xmp_bus, 32'b1 << xm_alen);
    
    // Simulated external SRAM.
    logic               sram_re;
    logic               sram_we;
    logic[xm_alen-1:0]  sram_addr;
    logic[7:0]          sram_wdata;
    logic[7:0]          sram_rdata;
    raw_sram#(xm_alen) sram(clk, sram_re, sram_we, sram_addr, sram_wdata, sram_rdata);
    boa_extmem_sram#(xm_alen) sram_ctl(clk, rst, extram_bus, sram_re, sram_we, sram_addr, sram_wdata, sram_rdata);
    
    // External ROM stub.
    assign extrom_bus.ready = 1;
    assign extrom_bus.rdata = 0;
    
    always @(posedge clk) begin
        // Create new randomness.
        randomness <= $urandom();
        // Power management bus.
        if (pmb.shdn) begin $display("PMU poweroff"); $finish; end
        if (pmb.rst) rst <= 1;
        else if (rst) rst <= 0;
    end
endmodule
