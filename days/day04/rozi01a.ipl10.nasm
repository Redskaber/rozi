; path: rozi/days/day04/rozi01a.ipl10.nasm
; author: redskaber
; format: TAB=2
; datetime: 2026-06-06
;
; 左移 4 位这种设计本质上就是为了解决当时的 16位存储和 20位地址之间转换关系设计
; 段寄存器：
;   段寄存器 × 16 + 偏移”的规则，只在 8086/8088 以及所有 x86 CPU 的实模式 下适用.
;   适用于所有段寄存器（CS、DS、ES、SS)


; EQU: 相当于 c 中的 #define, 用来声明常数; EQU == "equal"
CYLS EQU 10               ; cylinders


ORG 0x7C00


; standrad FAT12 format
  JMP entry
  DB    0x90
  DB    "ROZI.IPL"        ; 启动区的名称可以是任意的字符串(8字节)
  DW    512               ; 每一个扇区 (sector) 的大小(必须为512字节)
  DB    1                 ; 簇（cluster）的大小（必须为1个扇区

  DW    1                 ; FAT的起始位置(一般从第一个扇区开始)
  DB    2                 ; FAT的个数(必须为2个)
  DW    224               ; 根目录大大小（一般设置成224项）
  DW    2880              ; 该磁盘的大小（必须为2880扇区）
  DB    0xf0              ; 磁盘的种类（必须是0xf0）
  DW    9                 ; FAT的长度（必须是9扇区）
  DW    18                ; 1个磁道（track）有几个扇区(必须是18)
  DW    2                 ; 磁头数(必须是2)
  DD    0                 ; 不使用分区，必须是0
  DD    2880              ; 重写一次磁盘大小
  DB    0,0,0x29          ; 扩展引导标志（BS_BootSig）,结构上是为了对齐
  DD    0xffffffff        ; 卷序列号（BS_VolID）
  DB    "ROZI       "     ; 磁盘的名称(11字节)
  DB    "FAT12   "        ; 磁盘格式名称（8字节）
  times 18 DB 0x00        ; RESB  18 ; 空出18 字节


; 程序主体
entry:
  MOV   AX, 0             ; 初始化寄存器 (stack, data, extra)
  MOV   SS, AX            ; stack segment
  MOV   SP, 0x7C00        ; stak pointer
  MOV   DS, AX            ; data segment

  ; read disk
  MOV   AX, 0x820         ; 0x8200 / 16
  MOV   ES, AX            ; extra segment
  MOV   CH, 0             ; 柱面 0
  MOV   DH, 0             ; 磁头 0
  MOV   CL, 2             ; 扇区 2


readloop:
  MOV   SI, 0             ; 记录失败次数的寄存器

retry:
  MOV   AH, 0x02          ;  AH=0x02 : 读盘
  MOV   AL, 1             ; 1 个扇区
  MOV   BX, 0             ;
  MOV   DL, 0x00          ; A 驱动器
  INT   0x13              ; 调用磁盘 BIOS 的 0x13 号函数
  JNC   next              ; if carry-flag == 0 then jump next tag
  ADD   SI, 1             ; 失败计数加1
  CMP   SI, 5             ; compare SI, 5
  JAE   error             ; if SI >= 5 then jump error tag

  ; reset
  MOV   AH, 0x00
  MOV   DL, 0x00
  INT   0x13
  JMP   retry


next:
  MOV   AX, ES             ; 获取disk 当前扇区的地址
  ADD   AX, 0x20           ; 地址偏移 0x200 = 512 bytes; 0x200 / 16 = 0x20;
  MOV   ES, AX             ; 更新 ES (extra segment)
  ADD   CL, 1              ; 扇区加1
  CMP   CL, 18             ; compare CL, 18
  JBE   readloop           ; if CL <= 18 then jump readloop tag
  MOV   CL, 1              ; reset 扇区为1
  ADD   DH, 1              ; 磁头加1 (背面)
  CMP   DH, 2              ; compare DH, 2
  JB    readloop           ; if DH < 2 then jump readloop tag
  MOV   DH, 0              ; reset 磁头0 （正面）
  ADD   CH, 1              ; 柱面+1
  CMP   CH, CYLS           ; compare CH, CYLS
  JB    readloop           ; if CH < CYLS then jump readloop tag
  MOV   [0x0FF0], CH       ; 磁盘装载内容的结束地址告诉给 sys
  JMP   0xC200             ; load 10 cylinders to jump 0xC200 (sys data)


putloop:
  MOV   AL, [SI]          ; get source index address internal value to AL
  ADD   SI, 1             ; source index offset next address
  CMP   AL, 0             ; compare si value eq 0
  JE    fin               ; je = if compare is true then jump to fin label
  MOV   AH, 0x0e          ; else
  MOV   BX, 15
  INT   0X10              ; interrupt (int): call `id` number function (bios builtins)
  JMP   putloop
fin:
  HLT                     ; quite-stop: stop run-forever, to cpu sleep; htl => halt => stop
  JMP   fin


error:
  MOV SI, errmsg          ; source index

errmsg:
  DB    0x0a, 0x0a        ; 2 个换行
  DB    "load error"
  DB    0x0a              ; 换行
  DB    0

  times  0x1fe-($-$$) DB 0x00   ; RESB 0x1fe-$; 填写0x00,直到 0x001fe  (nask)
                                ; nasm: $  表示当前 section 的起始地址（默认从 0 开始）（段内偏移）
                                ; nasm: $$ 表示从开始到当前位置的字节数                 (段基址)
  DB    0x55, 0xaa              ; 512 字节


; only 512 bytes

; C0-H0-S1              : 0x7C00 -- (0x200     ) --> 0x7E00
; C0-H0-S(2-18)         : 0x8200 -- (0x200 * 17) --> 0xA3FF
; C(0-9)-H(0-1)-S(1-18) : 0x8200 -- (0x200 * 2 * 18 * 10 - 0x200) --> 0x34FFF  !(C0-H0-S1)
