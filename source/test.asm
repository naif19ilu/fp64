# fp86 - fprintf function for x86_64
# 24 Jun 2025
# This file tests fp86 functionallity

.section .rodata
	.test: .string "%s\n"

	.str: .string "string"

.section .text

.globl _start

_start:

	leaq	.str(%rip), %rdx

	movq	$1, %rdi
	leaq	.test(%rip), %rsi
	call	fp86

 	movq	%rax, %rdi
	movq	$60, %rax
	syscall
