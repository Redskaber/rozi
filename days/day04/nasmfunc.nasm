; path: rozi/days/day04/nasmfunc.nasm
; author: redskaber
; format: TAB=2
; datetime: 2026-06-06


; [FORMAT "WCOFF"]        ; 制作目标文件的模式 (nask)
; [INSTRSET "i486p"]      ; 使用到486为止的指令 (nask)
[BITS 32]                 ; 制作 32 位模式用的机器语言


; 制作目标文件的信息
; [FILE "nasmfunc.nasm"]  ; 源文件名信息 (nask)

; 程序中包含的函数名
  GLOBAL _io_hlt, _write_mem8


; 以下是实际的函数
[SECTION .text]           ; 目标文件中写了这些之后再写程序

_io_hlt:                  ; void io_hlt(void);
  HLT
  RET


; will data to addr store
_write_mem8:              ; void write_mem8(int addr, int data);
  MOV   ECX, [ESP + 4]    ; [ESP + 4] 中存放的是地址， 将其读入 ECX; bits 32 / 8 = 4 unit
  MOV   AL,  [ESP + 8]    ; [ESP + 8] 中存放的是数据， 将其读入 AL ; etc.
  MOV   [ECX], AL         ; 将数据存入内存
  RET


