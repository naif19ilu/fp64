# fp86 - fprintf function for x86_64
# 24 Jun 2025
# This file tests fp86 functionallity

.section .rodata
	.test: .string "123456789009876543211234567890098765432112345678900987654321\n"

.section .text

.globl _start

_start:
	movq	$1, %rdi
	leaq	.test(%rip), %rsi
	call	fp86

	movq	$60, %rax
	movq	$60, %rdi
	syscall
