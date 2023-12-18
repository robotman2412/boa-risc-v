/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

    .global real_test_end
    .global __global_pointer$
    .global __stack_top

    .section ".text"
    .align 2
    .global isr
isr:
    j real_test_end

    .section ".text"
    .align 2
    .global test_end
test_end:
    .option push
    .option norelax
    la gp, __global_pointer$
    la sp, __stack_top
    .option pop
    j real_test_end
