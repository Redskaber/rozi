; path: rozi/days/day03/rozi00g.sys.nasm
; author: redskaber
; format: TAB=2
; datetime: 2026-06-05


; [NEW::START::BOOT_INFO] ----------------
; boot info
CYLS    EQU   0x0FF0    ; 设定启动区
LEDS    EQU   0x0FF1    ; 键盘LED指示灯状态
VMODE   EQU   0x0FF2    ; 关于颜色数目的信息。颜色位数
SCRNX   EQU   0x0FF4    ; 分辨率X （screen x ）
SCRNY   EQU   0x0FF6    ; 分辨率Y （screen y ）
VRAM    EQU   0x0FF8    ; 图像缓冲区的开始地址
; [NEW::END::BOOT_INFO] ------------------


ORG   0xC200            ; 这个程序装载到内存的位置


  MOV   AL, 0x13        ; VGA 显卡， 320 x 200 x 8位彩色 （x * y * vmode）
  MOV   AH, 0x00
  INT   0x10

; [NEW::START::BOOT_INFO] ----------------
  MOV   WORD [SCRNX], 320     ; x
  MOV   WORD [SCRNY], 200     ; y
  MOV   BYTE [VMODE], 8       ; 记录画面模式
  MOV   DWORD [VRAM], 0xA0000 ; VRAM （video RAM ）; 显示画面的内存， 地址对应画面像素; INT 0x10 => VRAM (0xA0000 - 0xAFFFF); 64KB


; 用 BIOS 取得键盘上的各种LED 指示灯的状态
  MOV   AH, 0x02
  INT   0x16            ; keyboard BIOS （键盘）
  MOV   [LEDS], AL      ; 存储到内存
; [NEW::END::BOOT_INFO] ------------------


fin:
  HLT
  JMP fin


