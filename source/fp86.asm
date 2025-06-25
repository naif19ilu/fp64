# fp86 - fprintf function for x86_64
# 24 Jun 2025
# This file gets all the work done

.section .bss
	.buffer:  .zero 2048
	.buf_off: .zero 8
	.finalfd: .zero 8

.section .rodata
	.buffer_length: .quad 2048

.section .data
	.stk_off: .quad 16

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

.macro WRITE
	movq	$1, %rax
	movq	(.finalfd), %rdi
	movq	%r10, %rdx
	leaq	.buffer(%rip), %rsi
	syscall
.endm

.macro ABORT status
	movq	$60, %rax
	movq	\status, %rdi
	syscall
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
	cmpq	$1, (fp_reg_backup)
	jne	.decolle
	subq	$64, %rsp
	BACKUP_A
.decolle:
	cmpq	$0, %rsi
	je	.null_rdi
	movq	%rdi, (.finalfd)
	#  r8: holds format string content
	#  r9: holds buffer
	# r10: holds number of bytes written so far into buffer
	movq	%rsi, %r8
	leaq	.buffer(%rip),  %r9
	movq	.buf_off(%rip), %r10
	xorq	%rax, %rax
	xorq	%rdi, %rdi
	xorq	%rsi, %rsi
.loop:
	cmpq	$2048, %r10
	je	.full
	movzbl	(%r8), %eax
	cmpb	$0, %al
	je	.fini
	cmpb	$'%', %al
	je	.format
	movb	%al, (%r9)
	incq	%r9
	incq	%r10
	jmp	.resume
.format:
	incq	%r8
	movzbl	(%r8), %eax
	cmpb	$'%', %al
	je	.fmt_per

	jmp	.fmt_unk

.fmt_per:
	movb	$'%', (%r9)
	incq	%r9
	incq	%r10
	jmp	.resume

.fmt_unk:
	ABORT	$-1

.resume:
	incq	%r8
	jmp	.loop
.null_rdi:
	movq	$-1, %r9
	jmp	.return
.full:
	WRITE
	movq	$0, %r10
	leaq	.buffer(%rip), %r9
	jmp	.loop
.fini:
	WRITE
	movq	$16, (.stk_off)
	movq	$0,  (.buf_off)
	cmpq	$1, (fp_reg_backup)
	jne	.return
	BACKUP_Z
.return:
	movq	$0, (fp_reg_backup)
	movq	%r10, %rax
	leave
	ret

