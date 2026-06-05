; path: rozi/days/day01/helloos.nasm
; author: redskaber
; format: TAB=2
; datetime: 2026-05-21
; hello-os

ORG 0x7C00
xor ax, ax
mov ds, ax                ; 让 DS=0，则地址计算为 0x7C00+偏移

; standrad FAT12 format
  DB    0xeb, 0x4e, 0x90
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
  DB    0xb8, 0x00, 0x00, 0x8e, 0xd0, 0xbc, 0x00, 0x7c
  DB    0x8e, 0xd8, 0x8e, 0xc0, 0xbe, 0x74, 0x7c, 0x8a
  DB    0x04, 0x83, 0xc6, 0x01, 0x3c, 0x00, 0x74, 0x09
  DB    0xb4, 0x0e, 0xbb, 0x0f, 0x00, 0xcd, 0x10, 0xeb
  DB    0xee, 0xf4, 0xeb, 0xfd

; 信息显示部分
  DB    0x0a, 0x0a        ; 2 个换行
  DB    "hello, world"
  DB    0x0a              ; 换行
  DB    0

  times  0x1fe-($-$$) DB 0x00   ; RESB 0x1fe-$; 填写0x00,直到 0x001fe  (nask)
                                ; nasm: $  表示当前 section 的起始地址（默认从 0 开始）（段内偏移）
                                ; nasm: $$ 表示从开始到当前位置的字节数                 (段基址)
  DB    0x55, 0xaa

; 以下是启动区以外部分的输出
  DB    0xf0, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00
  times 4600 DB 0x00            ; RESB  4600
  DB    0xf0, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00
  times 0x168000-($-$$) DB 0    ; RESB  1469432
                                ; 1474560 = 1.44MB 总字节数


