# 从 `.note.gnu.property` 段重叠故障看链接器脚本与 Flat Binary 生成

> 问题关键词：`section .note.gnu.property LMA [00000190,000001b7] overlaps section .data`
> 环境：Nix + binutils 2.44 + gcc + nasm，目标为 32 位 x86 裸机内核，输出 flat binary。

---

## 1. 故障现场与直接原因

链接器在生成 `bootpack.rozi`（flat binary）时，报出段重叠错误：

```
ld: section .note.gnu.property LMA [00000190,000001b7] overlaps section .data LMA [0000018f,000001be]
```

**表象**：两个段在内存地址（LMA）上出现了重叠区间。

**段的大小估算**（基于报错信息）：

- `.data`：LMA 起始 `0x18f`，结束 `0x1be`，占用 **48** 字节（0x30）
- `.note.gnu.property`：LMA 起始 `0x190`，结束 `0x1b7`，占用 **40** 字节（0x28）

重叠区间：`0x190` 到 `0x1b7`，完全覆盖了 `.data` 的前 39 字节。

---

## 2. 为什么会发生重叠？—— Flat Binary 的输出规则

**ld 在生成 flat binary（`--oformat binary`）时，不产生任何文件头**，而是把所有输入段按照 **LMA 从小到大的顺序** 直接拼接成二进制映像。  
任何未被链接脚本显式放置的段（孤儿段）会被链接器自动分配 LMA，容易与已安排好的段冲突。

当前 `rozi.lds` 只显式定义了三个段：

```ld
.head 0x0 : { ... }          /* 固定从 0 开始，36 字节 */
.text : { *(.text) }         /* 紧接 .head */
.data STACK_INIT : AT( ADDR(.text) + SIZEOF(.text) ) {
    *(.data) *(.rodata*) *(.bss)
}
/DISCARD/ : { *(.eh_frame) }
```

- `.note.gnu.property` 没有被放进 `/DISCARD/`，也没有被任何输出段规则捕获。
- 链接器为它安排了 LMA，并可能按默认对齐（16 字节）放置，结果恰好与紧随 `.text` 的 `.data` 起始地址发生了重叠。

### 内存布局示意图（LMA 视角）

```
地址         内容
0x000000 ┌──────────┐
         │ .head    │ 36 字节 (9 个 LONG)
0x000024 ├──────────┤
         │          │
         │ .text    │ 363 字节 (0x16B)
         │          │
0x00018E ├──────────┤ ← .data 的预期起始 (0x18F)
         │          │
         │ .data    │ 48 字节 (0x18F ~ 0x1BE)
         │██████████│ ← 重叠区域：.note.gnu.property (0x190 ~ 0x1B7)
         │██████████│
0x0001BE ├──────────┤
         │  (未用)  │
         └──────────┘
```

蓝色斜线部分代表 `.data` 预期占用的 48 字节，橙色 `X` 部分为 `.note.gnu.property` 实际落点，两者在 `0x190‑0x1B7` 处冲突。

---

## 3. 孤儿段 `.note.gnu.property` 的来源

现代 binutils（≥ 2.36）在编译 32 位 x86 ELF 目标文件时，会自动生成以下元数据段：

- `.note.gnu.property`：记录 Intel CET（控制流强制技术）等硬件特性
- `.note.GNU-stack`：标记栈是否可执行
- `.comment`：编译器版本信息

**这些段对裸机内核的 flat binary 没有任何作用**，因为：

- 裸机程序不使用 ELF 加载器解析 note 段
- 其中的信息只是给操作系统的建议或注解
- 丢弃它们不会改变任何代码或数据的运行时行为

---

## 4. 解决方案对比与最佳实践

### 方案 A：在 `/DISCARD/` 中通配所有 note 段（修补式）

```ld
/DISCARD/ : {
    *(.eh_frame)
    *(.note.gnu.property)
    *(.note.GNU-stack)
}
```

**优点**：精确控制，一目了然。  
**缺点**：工具链升级后若出现新的孤儿段，可能再次报错。

### 方案 B：广泛通配丢弃（预防式）

```ld
/DISCARD/ : {
    *(.eh_frame)
    *(.note.*)
    *(.comment*)
    *(.gnu*)
}
```

**优点**：覆盖绝大多数可能出现的元数据段，长期稳定。  
**缺点**：万一将来需要保留某种 `.note`（极少见），会误删。

### 方案 C：链接器选项 `--orphan-handling=discard`（根治式）

```bash
ld ... --orphan-handling=discard
```

**优点**：无需修改链接脚本，**所有未被脚本显式放置的段都会被自动丢弃**，完美解决孤儿段问题。  
**要求**：binutils ≥ 2.36（你的 2.44 完全支持）。

### 组合推荐方案

- 在链接脚本中保留 `*(.note.*) *(.comment) *(.eh_frame)` 的丢弃声明（提高可读性）。
- 在 `ld` 命令行添加 `--orphan-handling=discard`（作为最终保险）。

这样，无论是现在还是将来，任何未被脚本安排的段都会直接丢弃，永不产生重叠。

---

## 5. 知识点串联：链接器脚本与裸机二进制生成

### 5.1 关键概念

| 术语 | 含义 |
|------|------|
| **LMA** (Load Memory Address) | 段在最终二进制映像中的装入地址，flat binary 按此顺序拼接 |
| **VMA** (Virtual Memory Address) | 段在运行时的虚拟地址，对于裸机通常与 LMA 一致或通过 AT 指定 |
| **孤儿段 (Orphan Section)** | 输入文件中存在，但未被链接脚本显式分配给任何输出段的节 |
| **Flat Binary** | 无文件头、无重定位信息的纯二进制映像，直接映射到内存执行 |

### 5.2 你的 `rozi.lds` 结构分析

```
┌────────────┐
│ .head 0x0  │  手工构造的 Rozi 头，包含栈大小、签名、入口偏移等
├────────────┤
│ .text      │  代码段（来自 bootpack.obj 和 nasmfunc.obj）
├────────────┤
│ .data      │  数据段，VMA = STACK_INIT，LMA = 紧接 .text 之后
├────────────┤
│ /DISCARD/  │  丢弃不需要的节（如 .eh_frame、.note.*）
└────────────┘
```

链接器流程：

1. 按脚本定义，从 0 开始放置 `.head`。
2. `.text` 紧接着 `.head`，收集所有 `*(.text)`。
3. `.data` 的 LMA 设为 `.text` 结束位置，VMA 设为 `STACK_INIT`（通常在高地址，供初始化时复制）。
4. 孤儿段如 `.note.gnu.property` 未被 `/DISCARD/` 捕获，链接器自动分配 LMA，造成重叠。

### 5.3 为什么 `.data` 的 LMA 从 0x18F 开始？

因为 `.text` 的结束地址正好是 `0x18E`，且 `.data` 使用的 `AT()` 表达式就是 `ADDR(.text) + SIZEOF(.text)`，没有额外的对齐填充。  
而 `.note.gnu.property` 被放置时，可能按 16 字节对齐到了 `0x190`，正好跨入 `.data` 的范围。

---

## 6. 预防未来隐患的通用原则

1. **始终在链接脚本中显式丢弃不需要的段**，如 `.note.*`、`.comment`、`.eh_frame`。
2. **使用 `--orphan-handling=discard`** 作为安全网（若链接器支持）。
3. **保留 `-Map` 输出**，定期检查是否有新的孤儿段出现。
4. **理解 flat binary 的生成机制**：它不是简单的拼接，而是基于 LMA 排序，因此段重叠会直接导致链接失败。

---

## 7. 速查卡：常见可丢弃的段

```ld
/DISCARD/ : {
    *(.eh_frame)         /* DWARF 异常展开表 */
    *(.note.gnu.property) /* GNU 属性 note */
    *(.note.GNU-stack)   /* 栈可执行标记 */
    *(.note.*)           /* 所有 note 段 */
    *(.comment)          /* 编译器版本信息 */
    *(.gnu*)             /* 其他 GNU 扩展段 */
}
```

---

## 8. 修复后的链接脚本完整示例

```ld
OUTPUT_FORMAT("binary");

STACK_SIZE = DEFINED(STACK_SIZE) ? STACK_SIZE : 64 * 1024;
SIGNATURE = 0x697A6F52;
/* ... 其他符号定义 ... */

SECTIONS
{
    .head 0x0 : {
        LONG(STACK_SIZE)
        LONG(SIGNATURE)
        /* ... 剩余 7 个 LONG ... */
    }

    .text : { *(.text) }

    .data STACK_INIT : AT ( ADDR(.text) + SIZEOF(.text) ) {
        *(.data)
        *(.rodata*)
        *(.bss)
    }

    /DISCARD/ : {
        *(.eh_frame)
        *(.note.*)
        *(.comment*)
        *(.gnu*)
    }
}
```

命令行额外加 `--orphan-handling=discard`（可选但推荐）。

---

**结语**：这次排错不仅修复了一个链接错误，更揭示了 flat binary 链接的底层机理。掌握孤儿段的处理原则后，无论工具链如何升级，你都能从容应对。
