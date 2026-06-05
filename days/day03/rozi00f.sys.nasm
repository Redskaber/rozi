; path: rozi/days/day03/rozi00f.sys.nasm
; author: redskaber
; format: TAB=2
; datetime: 2026-06-05


; [NEW::START::SYSLOAD] --------------
ORG   0xC200            ; 这个程序装载到内存的位置


  MOV   AL, 0x13        ; VGA 显卡， 320x200x8位彩色
  MOV   AH, 0x00
  INT   0x10
; [NEW::END::SYSLOAD] ----------------


fin:
  HLT
  JMP fin


