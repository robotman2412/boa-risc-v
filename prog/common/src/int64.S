/*
    Copyright © 2023, Julian Scheffers
    
    This work ("Boa³²") is licensed under a Creative Commons
    Attribution-NonCommercial 4.0 International License:
    
    https://creativecommons.org/licenses/by-nc/4.0/
*/



	# Unsigned 64-bit division.
	.global __umoddi3
	.type __umoddi3, %function
	.section ".text.__umoddi3"
	.align 2
__umoddi3:
	# Save regs.
	addi sp, sp, -16
	sw ra, 12(sp)
	
	# Call implementation.
	jal cudivmoddi
	
	# Get modulo result.
	mv a0, a2
	mv a1, a3
	
	# Restore regs.
	lw ra, 12(sp)
	addi sp, sp, 16
	ret




	# 64-bit division.
	.global __moddi3
	.type __moddi3, %function
	.section ".text.__moddi3"
	.align 2
__moddi3:
	# Save regs.
	addi sp, sp, -16
	sw ra, 12(sp)
	
	# Call implementation.
	jal cdivmoddi
	
	# Get modulo result.
	mv a0, a2
	mv a1, a3
	
	# Restore regs.
	lw ra, 12(sp)
	addi sp, sp, 16
	ret



	.section ".bss"
	.align 3
	# Cached dividend.
	.lcomm cdividend, 8
	# Cached divisor.
	.lcomm cdivisor, 8
	# Cached division result.
	.lcomm cdiv, 8
	# Cached modulo result.
	.lcomm cmod, 8



	# Cached unsigned 64-bit division and modulo.
	# Returns division in a0, a1 and modulo in a2, a3.
	.type cudivmoddi, %function
	.section ".text.cudivmoddi"
	.align 2
cudivmoddi:
	# Check for 32-bit division.
	or   t0, a1, a3
	bne  t0, x0, .un32
	
	# Run 32-bit division.
	divu t0, a0, a2
	remu a2, a0, a2
	mv   a0, t0
	li   a1, 0
	li   a3, 0
	ret
	
	
.un32:
	# Check cache.
	lw   t0, cdividend
	bne  t0, a0, .neq
	lw   t0, cdividend+4
	bne  t0, a1, .neq
	lw   t0, cdivisor
	bne  t0, a2, .neq
	lw   t0, cdivisor+4
	bne  t0, a3, .neq
	
	# Use cached values.
	lw   a0, cdiv
	lw   a1, cdiv+4
	lw   a2, cmod
	lw   a3, cmod+4
	ret
	
	
.neq:
	# Resort to software 64-bit division.
	li   a4, 0 # Division result.
	li   a5, 0
	li   a6, 0 # Remaining bits counter.
	
	# Count number of output bits.
	bne  a3, x0, .shlcheck
	# Shift 32 bits at once.
	mv   a3, a2
	li   a2,  0
	li   a6, 32
	j .shlcheck
	
	
.shlloop:
	# Shift divisor left by 1.
	slli a3, a3, 1
	addi a6, a6, 1
.shlcheck:
	# Test shift left possibility.
	bge  a3, x0, .shlloop
	
	# Determine shift amount for lower 32 bits.
	andi t0, a6, 31
	li   t1, 32
	sub  t1, t1, t0
	beq  t0, x0, .divcheck
	
	# Shift left lower 32 bits.
	srl  t2, a2, t1
	or   a3, a3, t2
	sll  a2, a2, t0
	j .divcheck
	
	
.subcheck:
	# Check whether subtraction is possible for this bit.
	bltu a1, a3, .notsub
	bgtu a1, a3, .yessub
	bltu a0, a2, .notsub
	
.yessub:
	# Subtract bit.
	sltu t0, a0, a2
	sub  a1, a1, a3
	sub  a1, a1, t0
	sub  a0, a0, a2
	
	# Set output bit.
	li   t0, 1
	li   t1, 32
	sll  t0, t0, a6
	bge  a6, t1, .sethi32
	
	# In low 32 bits.
	or   a4, a4, t0
	j .notsub
.sethi32:
	# In high 32 bits.
	or   a5, a5, t0
	
.notsub:
	# Increment bit position.
	slli t0, a3, 31
	srli a2, a2,  1
	or   a2, a2, t0
	srli a3, a3,  1
	addi a6, a6, -1
	
.divcheck:
	# Check whether there are bits left to divide.
	bge  a6, x0, .subcheck
	
	# Copy modulo result.
	mv   a2, a0
	mv   a3, a1
	# Copy division result.
	mv   a0, a4
	mv   a1, a5
	
	# Store values in cache.
	sw   a0, cdiv,   t0
	sw   a1, cdiv+4, t0
	sw   a2, cmod,   t0
	sw   a3, cmod+4, t0
	
	ret



	# Unsigned 64-bit division.
	.global __udivdi3
	.type __udivdi3, %function
	.equ __udivdi3, cudivmoddi



	# Cached signed 64-bit division and modulo.
	# Returns division in a0, a1 and modulo in a2, a3.
	.type cdivmoddi, %function
	.section ".text.cdivmoddi"
	.align 2
cdivmoddi:
	addi sp, sp, -16
	sw ra, 12(sp)
	
	# Check for 32-bit division.
	srai t0, a0, 31
	bne t0, a1, .n32
	srai t0, a2, 31
	bne t0, a2, .n32
	
	# Run 32-bit division.
	divu t0, a0, a2
	remu a2, a0, a2
	mv   a0, t0
	srai a1, a0, 31
	srai a3, a2, 31
	ret
.n32:
	
	# Tell the sign.
	srli t0, a1, 31
	srli t1, a3, 31
	sw   t0, 8(sp)
	xor  t0, t0, t1
	sw   t0, 4(sp)
	
	# Unsigned-ed both nombre.
	bge  a1, x0, .skips0
	neg  t0, a0
	snez a0, a0
	neg  a1, a1
	sub  a1, a1, a0
	mv   a0, t0
.skips0:
	
	bge  a3, x0, .skips1
	neg  t0, a2
	snez a2, a2
	neg  a3, a3
	sub  a3, a3, a2
	mv   a2, t0
.skips1:
	
	# Call the unsigned counterpart.
	jal cudivmoddi
	
	# Apply correct sign for division.
	lw   t0, 4(sp)
	beqz t0, .skipnd
	neg  t0, a0
	snez a0, a0
	neg  a1, a1
	sub  a1, a1, a0
	mv   a0, t0
.skipnd:
	
	# Apply correct sign for modulo.
	lw   t1, 8(sp)
	beqz t1, .skipnm
	neg  t0, a2
	snez a2, a2
	neg  a3, a3
	sub  a3, a3, a0
	mv   a2, t0
.skipnm:
	
	lw   ra, 12(sp)
	addi sp, sp, 16
	ret



	# 64-bit division.
	.global __divdi3
	.type __divdi3, %function
	.equ __divdi3, cdivmoddi
