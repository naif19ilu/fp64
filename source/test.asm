# fp64 - fprintf function for x64
# 24 Jun 2025
# This file tests fp86 functionallity

.section .rodata
	.test: .string ".%>x (hex).\n"

	.str: .string "string"

.section .text

.globl _start

_start:

	movq	$5, %rdx
	movq	$-15, %rcx

	movq	$1, %rdi
	leaq	.test(%rip), %rsi
	call	fp64

 	movq	%rax, %rdi
	movq	$60, %rax
	syscall
