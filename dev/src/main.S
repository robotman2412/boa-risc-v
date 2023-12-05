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
    li x1, 1
    li x2, 2
    li x3, 3
    li x4, 4
    li x5, 5
    li x6, 6

halt:
    j halt



isr:
    li a0, 0xdeadbeef
    mret

haha:
    .word 0xcafebabe
