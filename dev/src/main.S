/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/

    .global _start
_start:
    la t0, isr
    csrw mtvec, t0
    csrsi mstatus, 8
    li t0, -1
    csrs mie, t0
    
    lw a0, haha
    sw a0, dest, t0
    lb a1, dest+1

halt:
    j halt



isr:
    li a0, 0xdeadbeef
    mret

haha:
    .word 0xcafebabe



    .section ".bss"
    .align 2
    .lcomm dest, 4
