; path: rozi/days/day02/helloos.ipl.nasm
; author: redskaber
; format: TAB=2
; datetime: 2026-05-22
; hello-os


ORG 0x7C00

; standrad FAT12 format
  JMP entry
  DB    0x90
  DB    "HELLOIPL"        ; 启动区的名称可以是任意的字符串(8字节)
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
  DB    "HELLO-OS   "     ; 磁盘的名称(11字节)
  DB    "FAT12   "        ; 磁盘格式名称（8字节）
  times 18 DB 0x00        ; RESB  18 ; 空出18 字节


; 程序主体
entry:
  MOV   AX, 0             ; 初始化寄存器 (stack, data, extra)
  MOV   SS, AX            ; stack segment
  MOV   SP, 0x7C00        ; stak pointer
  MOV   DS, AX            ; data segment
  MOV   ES, AX            ; extra segment

  MOV   SI, msg           ; source index
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


; 信息显示部分
msg:
  DB    0x0a, 0x0a        ; 2 个换行
  DB    "hello, world"
  DB    0x0a              ; 换行
  DB    0

  times  0x1fe-($-$$) DB 0x00   ; RESB 0x1fe-$; 填写0x00,直到 0x001fe  (nask)
                                ; nasm: $  表示当前 section 的起始地址（默认从 0 开始）（段内偏移）
                                ; nasm: $$ 表示从开始到当前位置的字节数                 (段基址)
  DB    0x55, 0xaa              ; 512 字节


; only 512 bytes

