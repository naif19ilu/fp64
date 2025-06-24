# fp86 - fprintf function for x86_64
# 24 Jun 2025
# This file gets all the work done

.section .bss
	.buffer: .zero 2048

.section .rodata
	.buffer_length: .quad 2048

.section .data
 	# This is a global flag used to know whether
	# store all r8 throught r9 registers before using
	# them here, in order to save their values
	# 0 means do not back up
	# 1 means do     back up
	fp_reg_backup: .quad 0
	.globl fp_reg_backup

.section .text


.macro BACKUP_A
	movq	%r8,  -8(%rbp)
	movq	%r9,  -16(%rbp)
	movq	%r10, -24(%rbp)
	movq	%r11, -32(%rbp)
	movq	%r12, -40(%rbp)
	movq	%r13, -48(%rbp)
	movq	%r14, -56(%rbp)
	movq	%r15, -64(%rbp)
.endm

.macro BACKUP_Z
	movq	-8(%rbp) , %r8
	movq	-16(%rbp), %r9
	movq	-24(%rbp), %r10
	movq	-32(%rbp), %r11
	movq	-40(%rbp), %r12
	movq	-48(%rbp), %r13
	movq	-56(%rbp), %r14
	movq	-64(%rbp), %r15
.endm

.globl fp86
# fprintf function for x86_64 usage:
# 1st argument (rdi): file descriptor  8 byte
# 2nd argument (rsi): format           8 byte
# 3th argument (rdx): first argument   8 bytes   (if any)
# 4th argument (rcx): second argument  8 bytes   (if any)
# 5th argument (r8 ): third argument   8 bytes   (if any)
# 6th argument (r9 ): fourth argument  8 bytes   (if any)
# if you have to print more than four variables then you will
# have to push them into the stack in the reverse order they
# are nedeed (see README).
fp86:
	pushq	%rbp
	movq	%rsp, %rbp
	movq	(fp_reg_backup), %rax
	cmpq	$1, %rax
	jne	.loop
	subq	$64, %rsp
	BACKUP_A
.loop:

.return:
	movq	$0, (fp_reg_backup)
	leave
	ret

