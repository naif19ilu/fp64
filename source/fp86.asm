# fp86 - fprintf function for x86_64
# 24 Jun 2025
# This file gets all the work done

.section .bss
	.buffer:  .zero 2048
	.buf_off: .zero 8
	.finalfd: .zero 8

	.argbuff: .zero 64

.section .rodata
	.buffer_length: .quad 2048

.section .data
	.stk_off: .quad 8

 	# This is a global flag used to know whether
	# store all r8 throught r9 registers before using
	# them here, in order to save their values
	# 0 means do not back up
	# 1 means do     back up
	fp_reg_backup: .quad 0
	.globl fp_reg_backup

.section .text

.macro BACKUP_A
	movq	%r8 ,  -40(%rbp)
	movq	%r9 ,  -48(%rbp)
	movq	%r10,  -56(%rbp)
	movq	%r11,  -64(%rbp)
	movq	%r12,  -72(%rbp)
	movq	%r13,  -80(%rbp)
	movq	%r14,  -88(%rbp)
	movq	%r15,  -96(%rbp)
.endm

.macro BACKUP_Z
	movq	-40(%rbp), %r8
	movq	-48(%rbp), %r9
	movq	-56(%rbp), %r10
	movq	-64(%rbp), %r11
	movq	-72(%rbp), %r12
	movq	-80(%rbp), %r13
	movq	-88(%rbp), %r14
	movq	-96(%rbp), %r15
.endm

.macro WRITE
	movq	$1, %rax
	movq	(.finalfd), %rdi
	movq	%r10, %rdx
	leaq	.buffer(%rip), %rsi
	syscall
.endm

.macro ABORT status
	movq	\status, %rdi
	movq	$60, %rax
	syscall
.endm

.globl fp86
# fprintf function for x86_64 usage:
# 1st argument (rdi): file descriptor  8 byte
# 2nd argument (rsi): fp_format           8 byte
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
	# These 32 bytes are reserved for storing the
	# four arguments, even if they do not exist as arguments
	subq	$32, %rsp
	movq	%rdx, -8(%rbp)
	movq	%rcx,-16(%rbp)
	movq	%r8, -24(%rbp)
	movq	%r9, -32(%rbp)
	cmpq	$1, (fp_reg_backup)
	jne	.fp_decolle
	subq	$64, %rsp
	BACKUP_A
.fp_decolle:
	cmpq	$0, %rsi
	je	.fp_null_fmt
	movq	%rdi, (.finalfd)
	#  r8: holds fp_format string content
	#  r9: holds buffer
	# r10: holds number of bytes written so far into buffer
	# r15: holds the current argument
	movq	%rsi, %r8
	leaq	.buffer(%rip),  %r9
	movq	.buf_off(%rip), %r10
	xorq	%rax, %rax
	xorq	%rdi, %rdi
	xorq	%rsi, %rsi
.fp_loop:
	cmpq	$2048, %r10
	je	.fp_full_buff
	movzbl	(%r8), %eax
	cmpb	$0, %al
	je	.fp_fiin
	cmpb	$'%', %al
	je	.fp_format
	movb	%al, (%r9)
	incq	%r9
	incq	%r10
	jmp	.fp_resume
.fp_format:
	incq	%r8
	movzbl	(%r8), %eax
	cmpb	$'%', %al
	je	.fp_fmt_per

	call	.GetArg

	cmpb	$'<', %al
	je	.fp_fmt_lt
	cmpb	$'>', %al
	je	.fp_fmt_rg
.fp_fmt_noi:
	cmpb	$'c', %al
	je	.fp_fm_ch
	jmp	.fatal_1
.fp_fmt_per:
	movb	$'%', (%r9)
	incq	%r9
	incq	%r10
	jmp	.fp_resume
.fp_fmt_lt:

.fp_fmt_rg:

.fp_fm_ch:

.fp_resume:
	incq	%r8
	jmp	.fp_loop
.fp_null_fmt:
	movq	$-1, %r10
	jmp	.fp_return
.fp_full_buff:
	WRITE
	movq	$0, (.buf_off)
	xorq	%r10, %r10
	leaq	.buffer(%rip), %r9
	jmp	.fp_loop
.fp_fiin:
	WRITE
	movq	$16, (.stk_off)
	movq	$0,  (.buf_off)
	cmpq	$1, (fp_reg_backup)
	jne	.fp_return
	BACKUP_Z
.fp_return:
	movq	$0, (fp_reg_backup)
	movq	%r10, %rax
	leave
	ret

.GetArg:
	movq	(.stk_off), %rbx
	cmpq	$32, %rbx
	jg	.ga_stack
	leaq	(%rbp), %rax
	subq	%rbx, %rax
	movq	(%rax), %r15
	addq	$8, (.stk_off)
	jmp	.ga_return
.ga_stack:

.ga_return:
	ret


# unknown fp_formatting given
# example "%R" like wtf does R mean?
.fatal_1:
	ABORT	$-1

