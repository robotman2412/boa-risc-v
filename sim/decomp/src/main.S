
# Copyright © 2023, Julian Scheffers, see LICENSE for more information



#ifdef RVC
    .option rvc
#define INSN(x, ...) x  __VA_OPT__(,) __VA_ARGS__ ; .half 0x0000
#else
    .option norvc
#define INSN(x, ...) x __VA_OPT__(,) __VA_ARGS__
#endif



    .text
    .global _start
    .type _start, %function
    .option norelax
_start:
    INSN(nop)
    INSN(li a0, 0x11)
    INSN(j _start)
    INSN(andi a2, a2, 0x0c)
    INSN(ebreak)
    INSN(lw a3, 4(sp))
    INSN(sw a3, 252(sp))
    INSN(slli a0, a0, 17)
    INSN(srli a0, a0, 17)
    INSN(srai a0, a0, 17)
    INSN(sub  s0, s0, a0)
    INSN(xor  s1, s1, a0)
    INSN(or   s0, s0, a3)
    INSN(and  a5, a5, a0)
    INSN(addi sp, sp, -512)
    INSN(addi sp, sp, 496)
    INSN(addi sp, sp, -496)
    INSN(addi a0, a0, -13)
    INSN(addi a0, a0, 11)
    INSN(lui  a1, 16)
    INSN(lw   a0, 16(a1))
    INSN(sw   a0, 16(a1))
    INSN(jr   a5)
    INSN(jalr a5)
    INSN(mv   a4, a3)
    INSN(add  a4, a4, a3)
