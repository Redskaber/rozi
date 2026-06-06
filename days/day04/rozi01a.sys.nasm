; path: rozi/days/day04/rozi01a.sys.nasm
; author: redskaber
; format: TAB=2
; datetime: 2026-06-06


BOTPAK  EQU   0x00280000  ; 加载 bootpack
DSKCAC  EQU   0x00100000  ; 磁盘缓存的位置
DSKCAC0 EQU   0x00008000  ; 磁盘缓存的位置（实模式）


; boot info
CYLS    EQU   0x0FF0    ; 设定启动区
LEDS    EQU   0x0FF1    ; 键盘LED指示灯状态
VMODE   EQU   0x0FF2    ; 关于颜色数目的信息。颜色位数
SCRNX   EQU   0x0FF4    ; 分辨率X （screen x ）
SCRNY   EQU   0x0FF6    ; 分辨率Y （screen y ）
VRAM    EQU   0x0FF8    ; 图像缓冲区的开始地址


ORG   0xC200            ; 这个程序装载到内存的位置


  MOV   AL, 0x13        ; VGA 显卡， 320 x 200 x 8位彩色 （x * y * vmode）
  MOV   AH, 0x00
  INT   0x10

; boot info
  MOV   WORD [SCRNX], 320     ; x
  MOV   WORD [SCRNY], 200     ; y
  MOV   BYTE [VMODE], 8       ; 记录画面模式
  MOV   DWORD [VRAM], 0x000A0000  ; VRAM （video RAM ）; 显示画面的内存， 地址对应画面像素; INT 0x10 => VRAM (0xA0000 - 0xAFFFF); 64KB


; 用 BIOS 取得键盘上的各种LED 指示灯的状态
  MOV   AH, 0x02
  INT   0x16            ; keyboard BIOS （键盘）
  MOV   [LEDS], AL      ; 存储到内存


; 防止PIC接受所有中断
; - AT兼容机的规范、PIC初始化
; - 然后之前在CLI不做任何事就挂起
; - PIC在同意后初始化
  MOV   AL, 0xFF
  OUT   0x21, AL
  NOP                   ; 不断执行 OUT 指令
  OUT   0xA1, AL

  CLI                   ; 进一步中断CPU


; 让 CPU 支持 1M 以上内存、设置 A20GATE
  CALL  waitkbdout
  MOV   AL, 0xD1
  OUT   0x64, AL

  CALL  waitkbdout
  MOV   AL, 0xDF
  OUT   0x60, AL

  CALL  waitkbdout


; 保护模式转换
; [INSTRSET "i486p"]    ; 说明使用 486 指令 (nask)

  LGDT  [GDTR0]         ; 设置临时 GDT
  MOV   EAX, CR0
  AND   EAX, 0x7FFFFFFF ; 使用 bit 31 (禁用分页)
  OR    EAX, 0x00000001 ; bit 0 到 1 转换 （保护模过渡）
  MOV   CR0, EAX
  JMP   pipelineflush


pipelineflush:
  MOV   AX, 1*8         ; 写 32 bit 的段
  MOV   DS, AX
  MOV   ES, AX
  MOV   FS, AX
  MOV   GS, AX
  MOV   SS, AX

; bootpack 传递
  MOV   ESI, bootpack         ; 源
  MOV   EDI, BOTPAK           ; 目标
  MOV   ECX, 512 * 1024 / 4
  CALL  memcpy

; 传输磁盘数据

; 从引导区开始
  MOV   ESI, 0x7C00           ; 源
  MOV   EDI, DSKCAC           ; 目标
  MOV   ECX, 512 / 4
  CALL  memcpy

; 剩下的全部
  MOV   ESI, DSKCAC0 + 512    ; 源
  MOV   EDI, DSKCAC  + 512    ; 目标
  MOV   ECX, 0
  MOV   CL, BYTE [CYLS]
  IMUL  ECX, 512 * 18 * 2 / 4 ; /4 获取字节数
  SUB   ECX, 512 / 4          ; IPL 偏移量
  CALL  memcpy

; 由于还需要asmhead才能完成
; 完成其余的bootpack任务

; bootpack 启动
  MOV   EBX, BOTPAK
  MOV   ECX, [EBX + 16]
  ADD   ECX, 3                ; += 3
  SHR   ECX, 2                ; /= 4
  JZ    skip                  ; 传输完成
  MOV   ESI, [EBX + 20]       ; 源
  ADD   ESI, EBX
  MOV   EDI, [EBX + 12]       ; 目标
  CALL  memcpy


skip:
  MOV   ESP, [EBX + 12]       ; 堆栈初始化
  JMP   DWORD 2 * 8 : 0x1B


waitkbdout:
  IN    AL, 0x64
  AND   AL, 0x02
  JNZ   waitkbdout            ; AND 结果不为 0 jump to waitkbdout
  RET


memcpy:
  MOV   EAX, [ESI]
  ADD   ESI, 4
  MOV   [EDI], EAX
  ADD   EDI, 4
  SUB   ECX, 1
  JNZ   memcpy                ; if ECX - 1 != 0 then jump memcpy
  RET

 ; memcpy 地址 前缀大小
  ALIGNB  16


GDT0:
  times   8    DB 0x00                    ; init value
  DW      0xFFFF, 0x0000, 0x9200, 0x00CF  ; 写 32 bit 位段寄存器
  DW      0xFFFF, 0x0000, 0x9A28, 0x0047  ; 可执行文件的 32 bit 位寄存器 ( bootpack  use )
  DW      0


GDTR0:
  DW      8 * 3 -1
  DD      GDT0

  ALIGNB  16


bootpack:


; 8086 -> 80186 -> 286 -> 386 -> 486 -> Pentium -> PentiumPro -> PentiumII -> PentiumIII -> Pentium4 -> ...


