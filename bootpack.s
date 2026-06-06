	.file	"bootpack.c"
	.text
	.p2align 4
	.globl	RoziMain
	.type	RoziMain, @function
RoziMain:
.LFB0:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	.p2align 4
	.p2align 3
.L2:
	call	io_hlt@PLT
	jmp	.L2
	.cfi_endproc
.LFE0:
	.size	RoziMain, .-RoziMain
	.ident	"GCC: (GNU) 14.3.0"
	.section	.note.GNU-stack,"",@progbits
