/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

    .global main
    .global __isr_handler



    .section ".boot.text"
    .align 2
    .global _start
_start:
    # Set up registers.
    .option push
    .option norelax
    la gp, __global_pointer$
    la sp, __stack_top
    .option pop
    
    # Zero BSS.
    la a0, __start_bss
    la a1, __stop_bss
    bge a0, a1, _stop_bss_loop
_start_bss_loop:
    sw x0,  0(a0)
    sw x0,  4(a0)
    sw x0,  8(a0)
    sw x0, 12(a0)
    addi a0, a0, 16
    blt a0, a1, _start_bss_loop
_stop_bss_loop:
    
    # Initialize DATA.
    la a0, __start_data
    la a1, __start_data_rom
    la a2, __stop_data
    bge a0, a2, _stop_data_loop
_start_data_loop:
    lw t0,  0(a1)
    lw t1,  4(a1)
    lw t2,  8(a1)
    lw t3, 12(a1)
    sw t0,  0(a0)
    sw t1,  4(a0)
    sw t2,  8(a0)
    sw t3, 12(a0)
    addi a0, a0, 16
    addi a1, a1, 16
    blt a0, a2, _start_data_loop
_stop_data_loop:
    
    # Set ISR handler.
    la t0, __isr_handler
    csrw mtvec, t0
    
    # Jump to main function.
    jal main



    .type halt, %function
    .global halt
halt:
    # Wait for UART0 to finish sending.
    lw a0, __uart0_base+4
    andi a0, a0, 3
    bgt a0, x0, halt
    
    # Send PMU poweroff command.
    li a0, 2
    sw a0, __pmu_base, t0
_halt:
    j _halt



    .section ".bss"
    .align 4
    .equ __stack_size, 4096
    .lcomm __stack_bottom, __stack_size
    .equ __stack_top, __stack_bottom + __stack_size
