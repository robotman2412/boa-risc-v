
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps
`default_nettype none



module mmio_vga_periph(
    // VGA core clock.
    input  wire             vga_clk,
    // Memory bus clock.
    input  wire             mem_clk,
    // Reset.
    input  wire             rst,
    
    // Memory bus.
    boa_mem_bus.MEM         mem_bus,
    // Peripheral bus.
    boa_mem_bus.MEM         vga_pbus,
    // VGA output port.
    saph_vidport_vga.GPU    vga_port
);
    localparam div_len = 6;
    localparam x_len   = 10;
    localparam y_len   = 10;
    
    // Configuration values.
    logic[div_len:0]    raw_clk_div;
    wire                enable  = raw_clk_div[0];
    wire [div_len-1:0]  clk_div = raw_clk_div[div_len:1];
    logic[3:0]          shr_width;
    logic[x_len-1:0]    h_fp_width;
    logic[x_len-1:0]    h_vid_width;
    logic[x_len-1:0]    h_sync_width;
    logic[x_len-1:0]    h_bp_width;
    logic[y_len-1:0]    v_fp_width;
    logic[y_len-1:0]    v_vid_width;
    logic[y_len-1:0]    v_sync_width;
    logic[y_len-1:0]    v_bp_width;
    
    // Configuration registers.
    boa_mem_bus#(12) cr[10]();
    boa_mem_overlay#(32, 10) ovl(vga_pbus, cr);
    boa_peri_writeable#('h700, 0,   div_len+1) clk_div_reg (mem_clk, rst, cr[0], raw_clk_div);
    boa_peri_writeable#('h704, 3,   4)         shr_reg     (mem_clk, rst, cr[1], shr_width);
    boa_peri_writeable#('h708, 39,  x_len)     h_fp_reg    (mem_clk, rst, cr[2], h_fp_width);
    boa_peri_writeable#('h70c, 799, x_len)     h_vid_reg   (mem_clk, rst, cr[3], h_vid_width);
    boa_peri_writeable#('h710, 127, x_len)     h_sync_reg  (mem_clk, rst, cr[4], h_bp_width);
    boa_peri_writeable#('h714, 87,  x_len)     h_bp_reg    (mem_clk, rst, cr[5], h_sync_width);
    boa_peri_writeable#('h718, 0,   y_len)     v_fp_reg    (mem_clk, rst, cr[6], v_fp_width);
    boa_peri_writeable#('h71c, 599, y_len)     v_vid_reg   (mem_clk, rst, cr[7], v_vid_width);
    boa_peri_writeable#('h720, 3,   y_len)     v_sync_reg  (mem_clk, rst, cr[8], v_bp_width);
    boa_peri_writeable#('h724, 22,  y_len)     v_bp_reg    (mem_clk, rst, cr[9], v_sync_width);
    
    // Video memory.
    saph_pixreadport#(1) pix_port();
    boa_mem_bus#(17) vga_mbus();
    logic[7:0] vram_r, vram_g, vram_b;
    logic msel;
    wire [15:0] rdata = msel ? vga_mbus.rdata[31:16] : vga_mbus.rdata[15:0];
    always @(posedge vga_clk) msel <= pix_port.d_x[shr_width];
    dpdc_block_ram#(15) vram(mem_clk, mem_bus, vga_clk, vga_mbus);
    assign vga_mbus.re          = 1;
    assign vga_mbus.we          = 0;
    assign vga_mbus.addr[8:2]   = pix_port.d_x[9:1] >> shr_width;
    assign vga_mbus.addr[16:9]  = pix_port.d_y >> shr_width;
    assign vga_mbus.wdata       = 'bx;
    assign vram_r               = {rdata[11:8], 4'b0000};
    assign vram_g               = {rdata[7:4],  4'b0000};
    assign vram_b               = {rdata[3:0],  4'b0000};
    assign pix_port.d_ready     = 1;
    assign pix_port.q_res       = '{8'hff, vram_r, vram_g, vram_b};
    
    // VGA generator.
    saph_vidgen_vga#(div_len, x_len, y_len) vga_core(
        vga_clk, rst, enable,
        clk_div,
        h_fp_width, h_vid_width, h_bp_width, h_sync_width,
        v_fp_width, v_vid_width, v_bp_width, v_sync_width,
        pix_port, vga_port
    );
endmodule
