
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
    boa_mem_bus#(24) xmi_bus();
    boa_mem_bus#(24) xmd_bus();
    pmu_bus pmb();
    
    // Fence signals.
    logic fence_rl, fence_aq, fence_i;
    
    // Main microcontroller device.
    main#(
        .rom_file({boa_parentdir(`__FILE__), "/../obj_dir/rom.mem"}),
        .uart_buf(8192),
        .uart_div(4),
        .is_simulator(1)
    ) main (
        clk, rtc_clk, rst,
        tx, rx,
        gpio_out, gpio_oe, gpio_in,
        randomness,
        xmp_bus, xmi_bus, xmd_bus,
        fence_rl, fence_aq, fence_i,
        pmb
    );
    
    // Additional peripherals.
    // Extmem size device.
    boa_peri_readable#('h800) xm_size(clk, rst, xmp_bus, 32'b1 << xm_alen);
    
    // Simulated external SRAM.
    logic               sram_re;
    logic               sram_we;
    logic[xm_alen-1:0]  sram_addr;
    logic[7:0]          sram_wdata;
    logic[7:0]          sram_rdata;
    raw_sram#(xm_alen) sram(clk, sram_re, sram_we, sram_addr, sram_wdata, sram_rdata);
    boa_mem_bus#(xm_alen) sram_bus();
    boa_mem_bus#(xm_alen) sram_bus_out[2]();
    boa_extmem_sram#(xm_alen) sram_ctl(clk, rst, sram_bus, sram_re, sram_we, sram_addr, sram_wdata, sram_rdata);
    
    // External SRAM arbiter.
    boa_mem_demux#(xm_alen) sram_dmx(clk, rst, sram_bus_out, sram_bus);
    
    // Extmem dcache.
    logic dflush_r, dflush_w, dpi_en;
    logic[xm_alen-1:2] dpi_addr;
    boa_cache#(
        .alen(xm_alen)
    ) dcache (
        clk, rst,
        dflush_r, dflush_w, dpi_en, dpi_addr,
        xmd_bus,
        sram_bus_out[0]
    );
    
    // Extmem icache.
    logic iflush_r, iflush_w, ipi_en;
    logic[xm_alen-1:2] ipi_addr;
    boa_cache#(
        .alen(xm_alen),
        .writeable(0)
    ) icache (
        clk, rst,
        iflush_r, iflush_w, ipi_en, ipi_addr,
        xmi_bus,
        sram_bus_out[1]
    );
    
    // Cache flushing logic.
    assign dflush_r = fence_aq;
    assign dflush_w = fence_aq || fence_rl;
    assign dpi_en   = 0;
    assign dpi_addr = 'bx;
    
    assign iflush_r = fence_i;
    assign iflush_w = 0;
    assign ipi_en   = 0;
    assign ipi_addr = 'bx;
    
    always @(posedge clk) begin
        // Create new randomness.
        randomness <= $urandom();
        // Power management bus.
        if (pmb.shdn) begin $display("PMU poweroff"); $finish; end
        if (pmb.rst) rst <= 1;
        else if (rst) rst <= 0;
    end
endmodule
