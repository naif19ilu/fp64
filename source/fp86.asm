# fp86 - fprintf function for x86_64
# 24 Jun 2025
# This file gets all the work done

.section .bss
	.buffer:  .zero 2048
	.totalbt: .zero 8
	.finalfd: .zero 8

	.tempbff: .zero 2048
	.tmp_off: .zero 8

 	# padding: argument's padding
	# pad_twds: either left or right padding
	.padding:  .zero 8
	.pad_twds: .zero 1

 	# indicates if the current argument is a number
	# 1 for yes
	.args_num: .zero 1

	# indicates if the number is negative (in order to put '-' sign)
	.args_neg: .zero

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
	# r11: holds the temporary buffer
	# r12: holds the tempbff's length
	# r15: holds the current argument
	movq	%rsi, %r8
	leaq	.buffer(%rip),  %r9
	xorq	%r10, %r10
	xorq	%rax, %rax
	xorq	%rdi, %rdi
	xorq	%rsi, %rsi
.fp_loop:
	cmpq	$2048, %r10
	jne	.fp_loop_body
.fp_nml_full:
	leaq	.fp_loop(%rip), %rax
	jmp	.fp_full_buff
.fp_loop_body:
	movzbl	(%r8), %eax
	cmpb	$0, %al
	je	.fp_fin
	cmpb	$'%', %al
	je	.fp_format
	# if no format is provided then store this character
	# as it is within buffer
	movb	%al, (%r9)
	incq	%r9
	incq	%r10
	jmp	.fp_resume
.fp_format:
	incq	%r8
	movzbl	(%r8), %edi
	cmpb	$'%', %dil
	# padding is given via function argument, thus
	# if padd is requested an argument must be taken
	je	.fp_fmt_per
	cmpb	$'<', %dil
	je	.fp_fmt_pad
	cmpb	$'>', %dil
	je	.fp_fmt_pad
.fp_fmt_arg:
 	# Setting up temporary buffer
	leaq	.tempbff(%rip), %r11
	xorq	%r12, %r12
	call	.GetArg
	# characters...
	cmpb	$'c', %dil
	je	.fp_fmt_ch
	# strings...
	cmpb	$'s', %dil
	je	.fp_fmt_st
	# numbers...
	cmpb	$'d', %dil
	je	.fp_fmt_dc
	cmpb	$'b', %dil
	je	.fp_fmt_bn
	cmpb	$'o', %dil
	je	.fp_fmt_oc

	jmp	.fatal_1
.fp_fmt_per:
	movb	$'%', (%r9)
	incq	%r9
	incq	%r10
	jmp	.fp_resume
.fp_fmt_pad:
	call	.GetArg
	movq	%r15, (.padding)
	movb	%dil, (.pad_twds)
	# if there's padding indicator edi will not contain the
	# argument type but the padding type, so we need go one
	# character further to know it
	# example: "%>s"
	#            |` this is what specifies arg type
	#            ` this is edi
	incq	%r8
	movzbl	(%r8), %edi
	jmp	.fp_fmt_arg
.fp_fmt_ch:
	movb	%r15b, (%r11)
	movq	$1, %r12
	jmp	.fp_fmt_wrt
.fp_fmt_st:
	cmpq	$0, %r15
	je	.fp_resume
.fp_fmt_st_loop:
	movzbl	(%r15), %edi
	cmpb	$0, %dil
	je	.fp_fmt_wrt
	cmpq	$2048, %r12
	je	.fatal_2
	movb	%dil, (%r11)
	incq	%r11
	incq	%r12
	incq	%r15
	jmp	.fp_fmt_st_loop
.fp_fmt_dc:
	movq	$10, %rbx
	jmp	.fp_fmt_num
.fp_fmt_bn:
	movq	$2, %rbx
	jmp	.fp_fmt_num
.fp_fmt_oc:
	movq	$8, %rbx
	jmp	.fp_fmt_num
.fp_fmt_num:
	cmpq	$0, %r15
	jg	.fp_fmt_num_set
	cmpq	$0, %r15
	jl	.fp_fmt_num_neg
	movb	$'0', (%r11)
	incq	%r12
	jmp	.fp_fmt_wrt
.fp_fmt_num_neg:
	movb	$1, (.args_neg)
	negq	%r15
.fp_fmt_num_set:
 	# We need to start writing the number in the
	# inverse order
	addq	$2048, %r11
	movq	%r15, %rax
	xorq	%rdx, %rdx
	movb	$1, (.args_num)
.fp_fmt_num_loop:
	cmpq	$0, %rax
	je	.fp_fmt_num_fini
	cmpq	$2048, %r12
	je	.fatal_2
	divq	%rbx
	movb	%dl, (%r11)
	addb	$'0', (%r11)
	decq	%r11
	incq	%r12
	xorq	%rdx, %rdx
	jmp	.fp_fmt_num_loop
.fp_fmt_num_fini:
	cmpb	$1, (.args_neg)
	jne	.fp_fmt_wrt
	movb	$'-', (%r11)
	decq	%r11
	incq	%r12

	movb	$0, (.args_neg)
	jmp	.fp_fmt_wrt
.fp_fmt_wrt:
	cmpb	$'<', (.pad_twds)
	je	.fp_fmt_wrt_lp
	jmp	.fp_fmt_wrt_ok
.fp_fmt_wrt_lp:
 	# getting the number of spaces the program
	# has to add padding - r12
	movq	(.padding), %rax
	subq	%r12, %rax
	js	.fp_fmt_wrt_ok
	jz	.fp_fmt_wrt_ok
	movq	%rax, %rbx
	xorq	%rcx, %rcx
.fp_fmt_wrt_lp_loop:
	cmpq	%rcx, %rbx
	je	.fp_fmt_wrt_ok
	movb	$' ', (%r9)
	incq	%r9
	incq	%r10
	cmpq	$2048, %r10
	jne	.fp_fmt_wrt_lp_loop_resume	
	leaq	.fp_fmt_wrt_lp_loop(%rip), %rax
	jmp	.fp_full_buff
.fp_fmt_wrt_lp_loop_resume:
	incq	%rcx
	jmp	.fp_fmt_wrt_lp_loop
.fp_fmt_wrt_ok:
	xorq	%rcx, %rcx
	cmpb	$1, (.args_num)
	jne	.fp_fmt_wrt_ok_nonum
	incq	%r11
	movq	%r11, %rdi
	jmp	.fp_fmt_wrt_ok_loop
.fp_fmt_wrt_ok_nonum:
	leaq	.tempbff(%rip), %rdi
.fp_fmt_wrt_ok_loop:
	cmpq	%rcx, %r12
	je	.fp_fmt_wrt_rp
	movzbl	(%rdi), %eax
	movb	%al, (%r9)
	incq	%r9
	incq	%r10
	incq	%rcx
	incq	%rdi
	jmp	.fp_fmt_wrt_ok_loop
.fp_fmt_wrt_rp:
	cmpb	$'>', (.pad_twds)
	jne	.fp_fmt_wrt_reset
	movq	(.padding), %rax
	subq	%r12, %rax
	js	.fp_fmt_wrt_reset
	jz	.fp_fmt_wrt_reset
	movq	%rax, %rbx
	xorq	%rcx, %rcx
.fp_fmt_wrt_rp_loop:
	cmpq	%rcx, %rbx
	je	.fp_fmt_wrt_reset
	movb	$' ', (%r9)
	incq	%r9
	incq	%r10
	cmpq	$1, %r10
	jne	.fp_fmt_wrt_rp_loop_resume
	leaq	.fp_fmt_wrt_rp_loop(%rip), %rax
	jmp	.fp_full_buff
.fp_fmt_wrt_rp_loop_resume:
	incq	%rcx
	jmp	.fp_fmt_wrt_rp_loop
.fp_fmt_wrt_reset:
	movb	$0, (.pad_twds)
	movb	$0, (.args_num)
	jmp	.fp_resume
.fp_resume:
	incq	%r8
	jmp	.fp_loop
.fp_null_fmt:
	movq	$-1, %r10
	jmp	.fp_return
.fp_full_buff:
	pushq	%rax
	WRITE
	addq	%r10, (.totalbt)
	xorq	%r10, %r10
	leaq	.buffer(%rip), %r9
	popq	%rax
	jmp	*%rax
.fp_fin:
	addq	%r10, (.totalbt)
	WRITE
	movq	$8, (.stk_off)
	movq	(.totalbt), %r8
	cmpq	$1, (fp_reg_backup)
	jne	.fp_return
	BACKUP_Z
.fp_return:
	movq	$0, (fp_reg_backup)
	movq	%r8, %rax
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
# example: "%R" like wtf does R mean?
.fatal_1:
	ABORT	$-1

# argument causes buffer overflow
# example: A string is more than 2048 bytes long
.fatal_2:
	ABORT	$-2

