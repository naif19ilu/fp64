# fp86 - fprintf function for x86_64
# 24 Jun 2025
# This file tests fp86 functionallity

.section .text

.globl _start

_start:
	movq	$60, %rax
	movq	$60, %rdi
	syscall
