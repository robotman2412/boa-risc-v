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
    li t0, 0x00010000
    csrs mie, t0
    
    li t0, 0x800
    
    li a0, 'H'
    sb a0, 0(t0)
    li a0, 'e'
    sb a0, 0(t0)
    li a0, 'l'
    sb a0, 0(t0)
    li a0, 'l'
    sb a0, 0(t0)
    li a0, 'o'
    sb a0, 0(t0)
    li a0, ','
    sb a0, 0(t0)
    # csrsi mstatus, 8
    li a0, ' '
    sb a0, 0(t0)
    li a0, 'W'
    sb a0, 0(t0)
    li a0, 'o'
    sb a0, 0(t0)
    li a0, 'r'
    sb a0, 0(t0)
    li a0, 'l'
    sb a0, 0(t0)
    li a0, 'd'
    sb a0, 0(t0)
    li a0, '!'
    sb a0, 0(t0)
    li a0, '\r'
    sb a0, 0(t0)
    li a0, '\n'
    sb a0, 0(t0)

halt:
    j halt



isr:
    li a0, 0xdeadbeef
ok:
    j ok

haha:
    .word 0xcafebabe



    .section ".bss"
    .align 2
    .lcomm dest, 4
