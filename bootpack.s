	.file	"bootpack.c"
	.text
	.p2align 4
	.globl	RoziMain
	.type	RoziMain, @function
RoziMain:
.LFB0:
	.cfi_startproc
	.p2align 1
	.p2align 4
	.p2align 3
.L2:
	jmp	.L2
	.cfi_endproc
.LFE0:
	.size	RoziMain, .-RoziMain
	.ident	"GCC: (GNU) 14.3.0"
	.section	.note.GNU-stack,"",@progbits
