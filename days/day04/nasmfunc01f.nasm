; path: rozi/days/day04/nasmfunc01f.nasm
; author: redskaber
; format: TAB=2
; datetime: 2026-06-06


; [FORMAT "WCOFF"]        ; 制作目标文件的模式 (nask)
; [INSTRSET "i486p"]      ; 使用到486为止的指令 (nask)
[BITS 32]                 ; 制作 32 位模式用的机器语言


; 制作目标文件的信息
; [FILE "nasmfunc.nasm"]  ; 源文件名信息 (nask)

; 程序中包含的函数名
  GLOBAL  _io_hlt, _io_cli, _io_sti, _io_stihlt
  GLOBAL  _io_in8, _io_in16, _io_in32
  GLOBAL  _io_out8, _io_out16, _io_out32
  GLOBAL  _io_load_eflags, _io_store_eflags


; 以下是实际的函数
[SECTION .text]           ; 目标文件中写了这些之后再写程序

;; nasm commands to c use
_io_hlt:                  ; void io_hlt(void);
  HLT
  RET

_io_cli:                  ; void io_cli(void);
  CLI
  RET

_io_sti:                  ; void io_sti(void);
  STI
  RET

_io_stihlt:               ; void io_stihlt(void);
  STI
  HLT
  RET


;; nasm in commands to c use
_io_in8:                  ; int io_in8(int port);
  MOV   EDX, [ESP + 4]    ; port
  MOV   EAX, 0
  IN    AL, DX            ; AL 8 bits
  RET

_io_in16:                 ; int io_in16(int port)
  MOV   EDX, [ESP + 4]    ; port
  MOV   EAX, 0
  IN    AX, DX            ; AX 16 bits
  RET

_io_in32:                 ; int io_in32(int port)
  MOV   EDX, [ESP + 4]    ; port
  IN    EAX, DX           ; EAX 32 bits
  RET


;; nasm out commands to c use
_io_out8:                 ; void io_out8(int port, int data);
  MOV   EDX, [ESP + 4]    ; port
  MOV   EAX, [ESP + 8]    ; data
  OUT   DX, AL            ; AL 8 bits
  RET

_io_out16:                ; void io_out16(int port, int data);
  MOV   EDX, [ESP + 4]    ; port
  MOV   EAX, [ESP + 8]    ; data
  OUT   DX, AX            ; AX 16 bits
  RET

_io_out32:                ; void io_out32(int port, int data);
  MOV   EDX, [ESP + 4]    ; port
  MOV   EAX, [ESP + 8]    ; data
  OUT   DX, EAX           ; EAX 32 bits
  RET


;; nasm eflages contoller to c use
_io_load_eflags:          ; int io_load_efalgs(void);
  PUSHFD                  ; ps. PUSH EFLAGS  (push flags double-word)
  POP   EAX               ; 根据C语 言的规约，执行 RET 语句时，EAX 中的值就被看作是 函数的返回值
  RET

_io_store_eflags:         ; void io_store_eflags(int eflags);
  MOV   EAX, [ESP + 4]    ; eflags
  PUSH  EAX
  POPFD                   ; ps. POP EFLAGS (pop flags double-word)
  RET


