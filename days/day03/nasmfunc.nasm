; path: rozi/days/day03/nasmfunc.nasm
; author: redskaber
; format: TAB=2
; datetime: 2026-06-06


; [FORMAT "WCOFF"]        ; 制作目标文件的模式 (nask)
[BITS 32]                 ; 制作 32 位模式用的机器语言


; 制作目标文件的信息
; [FILE "nasmfunc.nasm"]  ; 源文件名信息 (nask)
  GLOBAL  _io_hlt         ; 程序中包含的函数名


; 以下是实际的函数
[SECTION .text]           ; 目标文件中写了这些之后再写程序

_io_hlt:                  ; void io_hlt(void);
  HLT
  RET


