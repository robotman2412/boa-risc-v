
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

#ifndef START_NAME
#define START_NAME _start
#endif
#ifndef MAIN_NAME
#define MAIN_NAME main
#endif

    .global MAIN_NAME
    .global __isr_handler

#define PROVIDE(x) __addr##x
#define memory_napot(i, mem, tempreg, perm) \
    pmp_write_addr_napot(i, __addr__start_##mem, __addr__stop_##mem-__addr__start_##mem, tempreg); \
    pmp_set_cfg(i, PMPCFG_LOCK + PMPCFG_NAPOT + perm, tempreg)
#include "memory_layout.ld"
#include "pmp.h"



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
    
#if !defined(memory_layout_bootloader) && !defined(pmp_disable)
#ifdef pmp_relax_exec
#define RAM_PERM PMPCFG_RWX
#define ROM_PERM PMPCFG_RX
#else
#define RAM_PERM PMPCFG_RW
#define ROM_PERM PMPCFG_R
#endif
    
    # Set up PMP regions for text and rodata.
#if !defined(pmp_disable_text) && !defined(pmp_disable_seg)
    la   t0, __start_text
    srl  t0, t0, 2
    csrw pmpaddr5, t0
    la   t0, __stop_text
    srl  t0, t0, 2
    csrw pmpaddr6, t0
    pmp_set_cfg(6, PMPCFG_LOCK + PMPCFG_TOR + PMPCFG_RX, t0)
#endif
#if !defined(pmp_disable_rodata) && !defined(pmp_disable_seg)
    la   t0, __start_rodata
    srl  t0, t0, 2
    csrw pmpaddr3, t0
    la   t0, __stop_rodata
    srl  t0, t0, 2
    csrw pmpaddr4, t0
    pmp_set_cfg(4, PMPCFG_LOCK + PMPCFG_TOR + PMPCFG_R, t0)
#endif
    
    # Set up PMP regions for memories.
    memory_napot(14, rom, t0, PMPCFG_RX)
    memory_napot(13, sram, t0, RAM_PERM)
    memory_napot(12, peri, t0, PMPCFG_RW)
    memory_napot(11, cpummio, t0, PMPCFG_RW)
    memory_napot(10, extperi, t0, RAM_PERM)
    
    # Detect and set address for extrom.
    li   t0, __addr__start_extrom
    srl  t0, t0, 2
    lw   t1, __xromctl_base
    srl  t1, t1, 2
    add  t1, t0, t1
    csrw pmpaddr9, t1
    csrw pmpaddr8, t0
    pmp_set_cfg(9, PMPCFG_LOCK + PMPCFG_TOR + ROM_PERM, t0)
    
    # Detect and set address for extram.
    li   t0, __addr__start_extram
    srl  t0, t0, 2
    lw   t1, __xramctl_base
    srl  t1, t1, 2
    add  t1, t0, t1
    csrw pmpaddr7, t1
    csrw pmpaddr6, t0
    pmp_set_cfg(7, PMPCFG_LOCK + PMPCFG_TOR + RAM_PERM, t0)
    
    # Make all other memory inaccessible.
    li   t0, -1; csrw pmpaddr15, t0
    pmp_set_cfg(15, PMPCFG_LOCK + PMPCFG_TOR, t0)
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



    .type softreset, %function
    .global softreset
softreset:
    csrw mstatus, 0
    csrw mie, 0
    sw x0, 0+__mtimecmp, t0
    sw x0, 4+__mtimecmp, t0
    sw x0, 0+__mtime, t0
    sw x0, 4+__mtime, t0
    la ra, __start_rom
    jr ra


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
