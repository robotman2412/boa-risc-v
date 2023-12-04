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
    j halt



isr:
    li a0, 0xdeadbeef
    mret
