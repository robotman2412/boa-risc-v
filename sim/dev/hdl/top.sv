
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

`timescale 1ns/1ps



module top(
    input  logic clk,
    output logic tx,
    input  logic rx
);
    `include "boa_fileio.svh"
    logic[1:0] rst = 3;
    logic rtc_clk;
    logic[31:0]  gpio_out;
    logic[31:0]  gpio_oe;
    logic[31:0]  gpio_in;
    assign gpio_in = gpio_out;
    param_clk_div#(10, 1) rtc_div(clk, rtc_clk);
    pmu_bus pmb();
    logic[31:0] randomness = $urandom();
    main#(
        .rom_file({boa_parentdir(`__FILE__), "/../obj_dir/rom.mem"}),
        .uart_buf(8192),
        .uart_div(4),
        .is_simulator(1)
    ) main (
        clk, rtc_clk, rst!=0,
        tx, rx,
        gpio_out, gpio_oe, gpio_in,
        randomness,
        pmb
    );
    always @(posedge clk) begin
        randomness <= $urandom();
        if (pmb.shdn) begin $display("PMU poweroff"); $finish; end
        if (pmb.rst) rst <= 3;
        else if (rst) rst <= rst - 1;
    end
endmodule
