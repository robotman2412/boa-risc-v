/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

module top(
    input logic clk
);
    wire rst = 0;
    
    // Program bus.
    boa_mem_bus pbus();
    // Dummy data bus.
    boa_mem_bus dbus();
    
    // The CPU.
    boa32_cpu#(.entrypoint(0)) cpu(
        clk, rst,
        pbus, dbus,
        16'h0000
    );
endmodule
