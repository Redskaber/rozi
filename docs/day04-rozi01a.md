## Rozi OS 开发知识总结与复习指南

本文档基于您当前的工作区状态（`git diff --cached` + 目录结构），系统梳理了从**实模式启动**到**保护模式C内核**再到**磁盘镜像构建**的完整知识点。适合作为开发笔记、复习提纲和概念速查表。

---

### 一、整体架构概览

Rozi OS 是一个极简的 x86 裸机程序，目前实现的功能：

- 从软盘加载并切换到保护模式
- 使用C语言操作显示内存（将VRAM填充为白色）
- 构建完整的 FAT12 格式软盘镜像，可在 QEMU 中运行

**启动流程图**（文本图形）

```
[开机] → BIOS → 加载 MBR (ipl10.bin) → 加载 asmhead.bin + bootpack.rozi → 保护模式 → 跳转到 RoziMain()
         │              │                              │
         │              │                              └── 0x280000 (bootpack)
         │              └── 0x7C00 → 读磁盘 → 0xC200 (asmhead)
         └── 检查启动设备 0x7C00
```

---

### 二、关键组件详解

#### 1. IPL（Initial Program Loader）—— `rozi01a.ipl10.nasm`

**功能**：读取磁盘的第2扇区及之后的内容，加载到内存 `0xC200`，然后跳转。

**代码关键点**

| 行号 | 代码 | 说明 |
|------|------|------|
| 13 | `CYLS EQU 10` | 要读取的柱面数（共10个柱面 → 10×2×18=360扇区） |
| 16 | `ORG 0x7C00` | BIOS将启动扇区加载到此地址 |
| 20-40 | FAT12头 | 必须符合磁盘格式，否则BIOS不认 |
| 50-55 | 设置ES, CH, DH, CL | ES = 0x0820（`0x8200/16`），目标缓冲区起始地址 `0x8200` |
| 62-66 | `MOV AH, 0x02` `INT 0x13` | BIOS读磁盘服务 |
| 80-82 | `ADD AX, 0x20` | 每次读完一个扇区（512字节）后，ES增加0x20（`512/16`） |
| 94 | `MOV [0x0FF0], CH` | 将实际读取的柱面数保存到地址0x0FF0，供后续asmhead使用 |
| 95 | `JMP 0xC200` | 跳转到asmhead（加载器） |

**FAT12头关键字段**（参考代码20-40行）

| 偏移 | 大小 | 值 | 含义 |
|------|------|-----|------|
| 0x03 | 8B | `"ROZI.IPL"` | 卷标（任意） |
| 0x0B | 2B | 512 | 扇区字节数 |
| 0x0D | 1B | 1 | 每簇扇区数 |
| 0x0E | 2B | 1 | 保留扇区数（FAT表前） |
| 0x10 | 1B | 2 | FAT表个数 |
| 0x11 | 2B | 224 | 根目录项数 |
| 0x13 | 2B | 2880 | 总扇区数（1.44MB） |
| 0x16 | 2B | 9 | 每FAT表扇区数 |
| 0x18 | 2B | 18 | 每磁道扇区数 |
| 0x1A | 2B | 2 | 磁头数 |
| 0x1FE | 2B | 0xAA55 | 启动签名 |

---

#### 2. 保护模式加载器 —— `rozi01a.sys.nasm`

**功能**：切换到保护模式、启用A20、加载GDT、将内核复制到高地址、最终跳转到C内核入口。

**重要步骤分解**

```assembly
; 1. 设置 VGA 图形模式 320x200x8
MOV AL, 0x13 ; INT 0x10, AH=0x00
INT 0x10

; 2. 保存显示信息到内存（供C内核使用）
MOV WORD [SCRNX], 320   ; 0x0FF4
MOV WORD [SCRNY], 200   ; 0x0FF6
MOV BYTE [VMODE], 8     ; 0x0FF2
MOV DWORD [VRAM], 0xA0000 ; 0x0FF8

; 3. 屏蔽所有中断（PIC）
MOV AL, 0xFF
OUT 0x21, AL
OUT 0xA1, AL
CLI

; 4. 启用 A20 地址线（访问1MB以上内存）
CALL waitkbdout
MOV AL, 0xD1   ; 写输出端口命令
OUT 0x64, AL
...
MOV AL, 0xDF   ; 打开A20
OUT 0x60, AL

; 5. 加载临时GDT（定义了两个段描述符）
LGDT [GDTR0]

; 6. 开启保护模式（CR0.PE = 1）
MOV EAX, CR0
OR EAX, 1
MOV CR0, EAX

; 7. 远跳转刷新流水线
JMP pipelineflush

; 8. 设置所有数据段寄存器为 1*8（第二个GDT条目）
MOV AX, 1*8
MOV DS, AX
...

; 9. 将bootpack从原位置（bootpack符号）复制到 BOTPAK = 0x280000
MOV ESI, bootpack
MOV EDI, BOTPAK
MOV ECX, 512*1024/4
CALL memcpy

; 10. 将磁盘缓存（实模式下读取的内容）复制到 0x100000
... 

; 11. 解析bootpack.rozi头部，完成额外段的复制
MOV EBX, BOTPAK
MOV ECX, [EBX+16]   ; 数据段大小
ADD ECX, 3
SHR ECX, 2
MOV ESI, [EBX+20]   ; 数据段源地址
ADD ESI, EBX
MOV EDI, [EBX+12]   ; 目标地址（栈初始地址）
CALL memcpy

; 12. 设置栈指针并跳转到C入口
MOV ESP, [EBX+12]
JMP DWORD 2*8 : 0x1B   ; 段选择子2*8，偏移0x1B
```

**GDT 描述符定义**

```assembly
GDT0:
    times 8 DB 0x00               ; 空描述符
    DW 0xFFFF, 0x0000, 0x9200, 0x00CF  ; 数据段：base=0, limit=4GB, 32位
    DW 0xFFFF, 0x0000, 0x9A28, 0x0047  ; 代码段：base=0x280000, limit=???
```

> 第二个描述符的基址是 `0x280000`，正好对应 bootpack 加载的地址。

---

#### 3. C 内核 —— `bootpack.c`

```c
void io_hlt(void);
void write_mem8(int addr, int data);

void RoziMain(void) {
    int i;
    // 将 VGA 显存 (0xA0000 - 0xAFFFF) 全部填充为颜色值15（白色）
    for (i = 0xA0000; i <= 0xAFFFF; i++) {
        write_mem8(i, 15);
    }
    for (;;) io_hlt();
}
```

- `write_mem8` 由汇编实现（`nasmfunc.nasm`）
- `io_hlt` 对应 `HLT` 指令，让CPU暂停直到中断

---

#### 4. 汇编辅助函数 —— `nasmfunc.nasm`

```assembly
[BITS 32]                ; 保护模式下使用32位指令
GLOBAL _io_hlt, _write_mem8

_io_hlt:
    HLT
    RET

_write_mem8:
    MOV ECX, [ESP+4]     ; 参数 addr（int, 4字节）
    MOV AL,  [ESP+8]     ; 参数 data（int, 只取低8位）
    MOV [ECX], AL        ; 写入内存
    RET
```

> **注意下划线前缀**：`-fleading-underscore` 编译选项使得C函数 `write_mem8` 在目标文件中变成 `_write_mem8`，汇编中必须用同名导出才能链接。

---

#### 5. 链接脚本 —— `rozi.lds`

**作用**：将 `bootpack.obj` 和 `nasmfunc.obj` 链接成一个纯二进制文件 `bootpack.rozi`，并在开头附加一个 **Rozi 格式头**，供加载器解析。

**头部结构**（从 `0x0` 开始）

| 偏移 | 符号 | 含义 |
|------|------|------|
| 0x00 | STACK_SIZE | 栈大小（由 `--defsym` 传入） |
| 0x04 | SIGNATURE | 固定签名 `0x697A6F52` ("Rozi") |
| 0x08 | MMAREA_SIZE | 预分配数据区大小（暂时为0） |
| 0x0C | STACK_INIT | 初始ESP（和数据段传输目标地址） |
| 0x10 | DATA_SIZE | 数据段（.data/.bss）大小 |
| 0x14 | DATA_INIT_ADDR | 数据段在文件中的起始地址（加载地址） |
| 0x18 | 0xE9000000 | 固定常量（可能是远跳转指令的一部分） |
| 0x1C | ENTRY_ADDR_OFFSET | `_RoziMain - 0x20` |
| 0x20 | HEAP_START_ADDR | 堆起始地址（未使用） |

**链接器命令**（来自 justfile）：

```bash
ld -m elf_i386 --oformat binary \
   -o bootpack.rozi \
   --defsym=STACK_SIZE=3136*1024 \
   -T rozi.lds \
   bootpack.obj nasmfunc.obj \
   -Map bootpack.map
```

---

### 三、构建系统 —— justfile 精要

Justfile 是一个替代 Make 的现代构建工具。您的 justfile 实现了完整的交叉编译流水线。

**主要目标**：

| 目标 | 作用 |
|------|------|
| `rozios-img` | 生成最终的 `rozios.img` 磁盘镜像 |
| `rozios-sys` | 生成 `rozios.sys`（asmhead + bootpack.rozi） |
| `bootpack-rozi` | 调用链接器生成 `bootpack.rozi` |
| `run` | 启动 QEMU |
| `dry` | 完整构建并运行 |
| `clean` / `src-only` | 清理编译产物 |

**关键编译选项**

```make
CFLAGS = "-fleading-underscore"       # C符号加下划线
         "-ffreestanding"            # 无标准库环境
         "-fno-stack-protector"      # 关闭栈保护
         "-nostdlib -nostdinc"       # 不链接标准库/头文件
         "-m32 -mtune=i486 -march=i486" # 生成i486代码
         "-masm=intel"               # 使用Intel汇编语法
```

**完整的构建流水线**（对应 `rozios-img` 依赖链）：

```
ipl10.nasm  → [nasm -f bin] → ipl10.bin
asmhead.nasm → [nasm -f bin] → asmhead.bin
bootpack.c   → [gcc -c]      → bootpack.obj
nasmfunc.nasm→ [nasm -f elf32] → nasmfunc.obj
bootpack.obj + nasmfunc.obj + rozi.lds → [ld] → bootpack.rozi
asmhead.bin + bootpack.rozi → [cat] → rozios.sys
ipl10.bin + rozios.sys + [dd + mformat + mcopy] → rozios.img
```

---

### 四、内存布局与加载地址总结

| 地址范围 | 内容 | 来源 |
|----------|------|------|
| 0x00007C00 - 0x00007DFF | IPL (boot sector) | BIOS 加载 |
| 0x00008200 - 0x00034FFF | 磁盘数据（asmhead + bootpack原始） | IPL 读取 |
| 0x0000C200 - 0x???????? | asmhead 自身执行地址 | IPL 跳转目标 |
| 0x000A0000 - 0x000AFFFF | VGA 显存（VRAM） | 硬件映射 |
| 0x00100000 - 0x???????? | 磁盘缓存（备份） | asmhead 复制 |
| 0x00280000 - 0x???????? | bootpack.rozi 最终加载位置 | asmhead 复制 |
| 0x00310000 - 0x???????? | 栈（STACK_INIT） | 链接脚本定义 |

> 注：`STACK_INIT` 默认 `0x310000`，约在 3MB 处。

---

### 五、常见问题与调试技巧

1. **符号未定义**：检查 `-fleading-underscore` 与汇编 `GLOBAL _func` 是否一致。
2. **链接器报错**：确保 `bootpack.obj` 和 `nasmfunc.obj` 都是 ELF32 格式（`file` 命令查看）。
3. **QEMU 黑屏**：检查 VGA 模式设置是否正确，或 `write_mem8` 是否写对了 VRAM 地址。
4. **IPL 读取失败**：确认软盘镜像制作正确（`mformat` 不可省略），可以用 `xxd rozios.img | head` 查看引导扇区签名 `55 AA`。
5. **A20 未生效**：在保护模式前必须启用，否则无法访问 0x100000 以上地址。

**调试命令**：

```bash
# 查看生成的二进制
objdump -D -m i386 -b binary bootpack.rozi | less

# 查看链接映射
cat bootpack.map

# 使用QEMU调试
qemu-system-x86_64 -s -S -drive file=rozios.img,if=floppy
# 另开终端：gdb -ex "target remote localhost:1234"
```

---

### 六、下一步学习方向

- **中断处理**：设置 IDT，实现键盘/鼠标输入
- **内存管理**：分页机制，malloc 实现
- **多任务**：任务切换，用户态保护
- **文件系统**：解析 FAT12，加载更多程序

当前项目已具备一个极简内核的基础框架，后续可参考《30天自制操作系统》或《x86汇编语言：从实模式到保护模式》继续扩展。

---

**总结**：本次代码变更展示了一个从零开始的操作系统引导、保护模式切换、C与汇编混合编程、自定义链接脚本和磁盘镜像生成的完整范例。掌握这些知识点，就掌握了 x86 裸机开发的核心基础。
