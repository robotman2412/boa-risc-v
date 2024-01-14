
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

#ifndef START_NAME
#define START_NAME _start
#endif
#ifndef MAIN_NAME
#define MAIN_NAME main
#endif

    .global MAIN_NAME
    .global __isr_handler



    .section ".boot.text"
    .align 2
    .global START_NAME
START_NAME:
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
    
#if defined(memory_layout_rom) || defined(memory_layout_bootloader)
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
#endif
    
    # Set ISR handler.
    la t0, __isr_handler
    csrw mtvec, t0
    
    # Jump to main function.
    li a0, 0
    li a1, 0
    li a2, 0
    jal MAIN_NAME



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



    .type reset, %function
    .global reset
reset:
    # Wait for UART0 to finish sending.
    lw a0, __uart0_base+4
    andi a0, a0, 3
    bgt a0, x0, reset
    
    # Send PMU reset command.
    li a0, 1
    sw a0, __pmu_base, t0
_reset:
    j _reset



    .section ".noinit", "w"
    .align 4
    .global __stack_size
    .global __stack_bottom
    .global __stack_top
    .equ __stack_size, 4096
__stack_bottom:
    .skip __stack_size
__stack_top:
