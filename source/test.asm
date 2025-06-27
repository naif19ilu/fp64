# fp64 - fprintf function for x64
# 24 Jun 2025
# This file tests fp86 functionallity

.section .rodata
	.test: .string "%d %d %d %d\n"

	.str: .string "string"

.section .text

.globl _start

_start:

	movq	$1, %rdx
	movq	$2, %rcx
	movq	$3, %r8
	movq	$4, %r9
	pushq	$6
	pushq	$5

	movq	$1, %rdi
	leaq	.test(%rip), %rsi
	call	fp64

 	movq	%rax, %rdi
	movq	$60, %rax
	syscall
