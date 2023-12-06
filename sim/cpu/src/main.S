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

halt:
    addi x1, x1, 0
    addi x2, x2, 0
    addi x3, x3, 0
    addi x4, x4, 0
    addi x5, x5, 0
    j halt



isr:
    li a0, 0xdeadbeef
    mret
