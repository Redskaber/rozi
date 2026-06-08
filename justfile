# =============================================================================
# Justfile for Rozi OS build
# =============================================================================
# Reproduces the full Makefile pipeline:
#   - Platform detection (x86 / Raspberry Pi / macOS)
#   - Compiler prefix selection (GCCPREFIX)
#   - NASM assembly → binary
#   - C kernel compilation (gcc → as → ld) → bootpack.obj → bootpack.rozi
#   - rozios.sys = asmhead.bin ‖ bootpack.rozi
#   - FAT12 floppy image construction
#   - QEMU launch
#   - Clean / src-only
#
# Build graph:
#
#   ipl10.nas  ──[nasm -f bin]────────────────────► ipl10.bin       ─┐
#   asmhead.nas──[nasm -f bin]────────────────────► asmhead.bin      │
#   bootpack.c ──[gcc  -c    ]────────────────────► bootpack.obj     │
#   nasmfunc.nas─[nasm -f elf32 --prefix _]───────► nasmfunc.obj     │
#     bootpack.obj ─┐                                                │
#     nasmfunc.obj ─┴─[ld rozi.lds]──────────────► bootpack.rozi     │
#      asmhead.bin ─┐                                                │
#     bootpack.rozi ┴─[cat]──────────────────────► rozios.sys        │
#   ipl10.bin + rozios.sys ──[dd + mformat + mcopy]────► rozios.img ─┘
#
# Dependencies:
#   - nasm, gcc / i686-linux-gnu-gcc / x86_64-elf-gcc
#   - binutils (ld)
#   - mtools (mformat, mcopy)
#   - dd (coreutils)
#   - qemu-system-i386
# =============================================================================


# =============================================================================
# Platform detection & toolchain prefix
# =============================================================================

# Detect Raspberry Pi: honour explicit RPI env-var, or detect from uname
_is_rpi := if env_var_or_default("RPI", "") != "" {
    "1"
} else if `uname -a | grep -c raspberrypi || true` == "1" {
    "1"
} else {
    "0"
}

# Detect macOS
_is_macos := if `uname -s` == "Darwin" { "1" } else { "0" }

# Select GCCPREFIX:
#   macOS     → x86_64-elf-
#   RPi       → i686-linux-gnu-
#   Linux x86 → (empty)
GCCPREFIX := if _is_macos == "1" {
    "x86_64-elf-"
} else if _is_rpi == "1" {
    "i686-linux-gnu-"
} else {
    ""
}


# =============================================================================
# Debug support
# Usage: DEBUG=1 just run
# =============================================================================
DEBUG             := env_var_or_default("DEBUG", "")
CFLAGS_DEBUG      := if DEBUG != "" { " -g" } else { "" }
QEMU_DEBUG_FLAGS  := if DEBUG != "" { "-gdb tcp::1234 -S" } else { "" }


# =============================================================================
# Toolchain
# =============================================================================

NASM    := "nasm"
CC      := GCCPREFIX + "gcc"
AS      := GCCPREFIX + "as"
LD      := GCCPREFIX + "ld"
OBJCOPY := GCCPREFIX + "objcopy"


# =============================================================================
# Compiler / linker flags
# =============================================================================

# All flags from Makefile CFLAGS — none omitted.
#
# -fleading-underscore: gcc prepends '_' to all C symbols in the object file.
#   e.g. C function write_mem8() → ELF symbol _write_mem8
#        C function RoziMain()   → ELF symbol _RoziMain
#   This must be paired with --prefix _ on the NASM side (see nasmfunc-obj)
#   so that NASM global symbols are also prefixed and the linker finds them.
CFLAGS_BASE := "-fleading-underscore"  + \
               " -ffreestanding"       + \
               " -fno-stack-protector" + \
               " -nostdlib"            + \
               " -nostdinc"            + \
               " -nostartfiles"        + \
               " -Wall"                + \
               " -fno-pie"             + \
               " -m32"                 + \
               " -mtune=i486"          + \
               " -march=i486"          + \
               " -masm=intel"

CFLAGS := CFLAGS_BASE + CFLAGS_DEBUG

# Linker emulation: ELF i386
LDFLAGS := "-m elf_i386"

# Stack size passed to ld --defsym (arithmetic evaluated by ld)
STACK_SIZE := "3136*1024"


# =============================================================================
# Output artifact names
# =============================================================================

# ipl
DEFAULT_IPL_NAME      := "ipl10.bin"      # Boot sector flat binary (512 bytes) → sector 0 of image

# sys
DEFAULT_ASMHEAD_NAME  := "asmhead.bin"    # Protected-mode stub         → prepended to rozios.sys
DEFAULT_BOOTPACK_NAME := "bootpack.obj"   # C kernel ELF i386 object    → input to linker
DEFAULT_NASMFUNC_NAME := "nasmfunc.obj"   # NASM utility ELF32 object   → input to linker
DEFAULT_BOOTPACK_ROZI := "bootpack.rozi"  # Linked kernel flat binary   → appended to rozios.sys

# System image = asmhead.bin ‖ bootpack.rozi
DEFAULT_SYS_NAME      := "rozios.sys"     # Kernel/system binary (loaded by boot sector)

# img
DEFAULT_IMG_NAME      := "rozios.img"     # Final floppy disk image (1.44 MB FAT12)

# Generated linker script (inlined below, written to disk before linking)
ROZI_LDS              := "rozi.lds"


# =============================================================================
# Embedded linker script — port of hrb.lds adapted for Rozi
#
# Exported as an environment variable so the _gen-rozi-lds recipe can write
# it to disk with a single printf call. Triple-single-quoted strings in just
# disable all escape processing, making them safe for verbatim file content.
#
# Symbol convention note:
#   ENTRY_ADDR_OFFSET = _RoziMain - 0x20
#   The leading underscore matches what -fleading-underscore causes gcc to
#   emit for the C function RoziMain() in bootpack.c.
#
# SIGNATURE = 0x697A6F52  →  'R'=0x52 'o'=0x6F 'z'=0x7A 'i'=0x69  ("Rozi")
#
# .rozi header layout (from harib01a Day 22, section 5):
#   0x0000  DWORD  OS-requested data segment size
#   0x0004  DWORD  "Rozi" signature
#   0x0008  DWORD  Pre-allocated data segment space
#   0x000c  DWORD  Initial ESP & data segment transfer address
#   0x0010  DWORD  Data segment size in .rozi file
#   0x0014  DWORD  Data segment start in .rozi file
#   0x0018  DWORD  0xe9000000
#   0x001c  DWORD  Application entry address − 0x20
#   0x0020  DWORD  malloc space start address
#
# Orphan sections policy (since binutils ≥ 2.36 may auto‑generate .note.*,
# .comment, .gnu* etc.):
#   - All .note.*, .comment, .gnu*, .eh_frame are explicitly discarded.
#   - For additional safety, link step uses --orphan-handling=discard
#     so that any future orphan sections are silently dropped,
#     preventing LMA overlap errors in flat‑binary output.
# =============================================================================

export _ROZI_LDS_CONTENT := '''
OUTPUT_FORMAT("binary");

STACK_SIZE = DEFINED(STACK_SIZE) ? STACK_SIZE : 64 * 1024;
SIGNATURE = 0x697A6F52;
MMAREA_SIZE = 0;
STACK_INIT = DEFINED(STACK_INIT) ? STACK_INIT : 0x310000;
DATA_SIZE = SIZEOF(.data);
DATA_INIT_ADDR = LOADADDR(.data);
CONSTANT_0xE9000000 = 0xE9000000;
ENTRY_ADDR_OFFSET = _RoziMain - 0x20;
HEAP_START_ADDR = DEFINED(HEAP_START_ADDR) ? HEAP_START_ADDR : 0;

SECTIONS
{
    .head 0x0 : {
        LONG(STACK_SIZE)
        LONG(SIGNATURE)
        LONG(MMAREA_SIZE)
        LONG(STACK_INIT)
        LONG(DATA_SIZE)
        LONG(DATA_INIT_ADDR)
        LONG(CONSTANT_0xE9000000)
        LONG(ENTRY_ADDR_OFFSET)
        LONG(HEAP_START_ADDR)
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
        *(.comment)
        *(.gnu*)
    }
}
'''


# =============================================================================
# Private helpers
# =============================================================================

# Write the embedded linker script to disk.
# All link-stage recipes depend on this.
[private]
_gen-rozi-lds:
  @printf %s "$_ROZI_LDS_CONTENT" > {{ROZI_LDS}}

# Validate cross-toolchain presence on macOS.
[private]
_check-toolchain:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ "$(uname -s)" != "Darwin" ]; then exit 0; fi
  if ! command -v x86_64-elf-gcc &>/dev/null; then
      echo "ERROR: x86_64-elf-gcc not found."
      echo "       Install with: brew install x86_64-elf-gcc"
      exit 1
  fi
  if ! command -v x86_64-elf-ld &>/dev/null; then
      echo "ERROR: x86_64-elf-ld not found."
      echo "       Install with: brew install x86_64-elf-binutils"
      exit 1
  fi


# =============================================================================
# Default target
# =============================================================================

# Usage: just <ipl.nasm> <asmhead.nasm> <bootpack.c> <nasmfunc.nasm>
# Build the full disk image from four source files.
default ipl-path asmhead-path bootpack-path nasmfunc-path:
  @just rozios-img {{ipl-path}} {{asmhead-path}} {{bootpack-path}} {{nasmfunc-path}}


# =============================================================================
# Step 1 — IPL boot sector (ipl10.bin)
# =============================================================================
# Mirrors: $(NASM) -f bin -o ipl10.bin ipl10.nasm -l ipl10.lst
# Output: ipl10.bin  (flat binary, written to sector 0 of the disk image)

# sys::ipl10(boot sector ipl 10)
ipl10-bin ipath: _check-toolchain
  @{{NASM}} -f bin {{ipath}} -o {{DEFAULT_IPL_NAME}} -l {{without_extension(DEFAULT_IPL_NAME)}}.lst


# =============================================================================
# Step 2 — Protected-mode stub (asmhead.bin)
# =============================================================================
# Mirrors: $(NASM) -f bin -o asmhead.bin asmhead.nasm -l asmhead.lst
# Output: asmhead.bin  (flat binary, prepended to rozios.sys)

# sys::asmhead(protected-mode stub)
asmhead-bin apath: _check-toolchain
  @{{NASM}} -f bin {{apath}} -o {{DEFAULT_ASMHEAD_NAME}} -l {{without_extension(DEFAULT_ASMHEAD_NAME)}}.lst


# =============================================================================
# Step 3 — C kernel object (bootpack.obj)
# =============================================================================
# Mirrors: $(CC) $(CFLAGS) -c bootpack.c -o bootpack.obj
# Output: bootpack.obj  (ELF i386 object, fed to the linker in step 5)
#
# -fleading-underscore causes gcc to prepend '_' to every C symbol:
#   RoziMain()   → _RoziMain    (referenced in rozi.lds)
#   write_mem8() → _write_mem8  (must match nasmfunc.obj export, see step 4)

# sys::bootpack(c kernel object)
bootpack-obj bpath: _check-toolchain
  @{{CC}} {{CFLAGS}} -c {{bpath}} -o {{DEFAULT_BOOTPACK_NAME}}


# =============================================================================
# Step 4 — NASM utility functions object  [-f elf32, NOT -f bin]
# =============================================================================
# Mirrors: $(NASM) -f elf32 -o nasmfunc.obj nasmfunc.nasm -l nasmfunc.lst
# Output: nasmfunc.obj  (ELF32 object, fed to the linker in step 5)

# sys::nasmfunc(nasm utility functions object)
nasmfunc-obj npath: _check-toolchain
  @{{NASM}} -f elf32 {{npath}} -o {{DEFAULT_NASMFUNC_NAME}} -l {{without_extension(DEFAULT_NASMFUNC_NAME)}}.lst


# =============================================================================
# Step 5 — Link kernel → bootpack.rozi  (Rozi binary via rozi.lds)
# =============================================================================
# Mirrors original Makefile rule, with one hardening addition:
#   $(LD) $(LDFLAGS) --oformat binary -o bootpack.rozi \
#         --defsym=STACK_SIZE=3136*1024 -T $(ROZI_LDS) \
#         bootpack.obj nasmfunc.obj -Map bootpack.map
#
# Hardening:
#   --orphan-handling=discard
#     Drops any input sections not explicitly placed by the linker script
#     (e.g. .note.gnu.property, .comment, future toolchain‑injected orphans).
#     Prevents "overlaps section .data" errors in flat‑binary output.
#
# Depends on _gen-rozi-lds to materialise rozi.lds before the link step.
# bootpack.obj and nasmfunc.obj must already exist (produced by steps 3 & 4).
# Output: bootpack.rozi  (flat binary in Rozi format, per rozi.lds layout)

# sys::bootpack-rozi(flat binary in Rozi format)
bootpack-rozi: _gen-rozi-lds
  @{{LD}} {{LDFLAGS}}                                   \
    --oformat binary                                    \
    -o {{DEFAULT_BOOTPACK_ROZI}}                        \
    --defsym=STACK_SIZE={{STACK_SIZE}}                  \
    -T {{ROZI_LDS}}                                     \
    --orphan-handling=discard                           \
    {{DEFAULT_BOOTPACK_NAME}} {{DEFAULT_NASMFUNC_NAME}} \
    -Map {{without_extension(DEFAULT_BOOTPACK_ROZI)}}.map


# =============================================================================
# Step 6 — System image (asmhead.bin ‖ bootpack.rozi → rozios.sys)
# =============================================================================
# Mirrors:
#   cat asmhead.bin > rozios.sys
#   cat bootpack.rozi >> rozios.sys
#
# Orchestrates steps 2–5 in dependency order so that bootpack-rozi finds
# bootpack.obj and nasmfunc.obj already on disk when the linker runs.
# Output: rozios.sys

# sys::rozios.sys(sys build flow)
rozios-sys asmhead-path bootpack-path nasmfunc-path:
  @just asmhead-bin  {{asmhead-path}}
  @just bootpack-obj {{bootpack-path}}
  @just nasmfunc-obj {{nasmfunc-path}}
  @just bootpack-rozi
  @cat {{DEFAULT_ASMHEAD_NAME}} {{DEFAULT_BOOTPACK_ROZI}} > {{DEFAULT_SYS_NAME}}


# =============================================================================
# Step 7 — Full disk image (ipl + sys → rozios.img)
# =============================================================================
# Orchestrates steps 1 + 6, then writes the FAT12 floppy image.
# Output: rozios.img  (1.44 MB FAT12 floppy disk image)

# img::rozios.img(full image build flow)
rozios-img ipl-path asmhead-path bootpack-path nasmfunc-path:
  @just ipl10-bin   {{ipl-path}}
  @just rozios-sys  {{asmhead-path}} {{bootpack-path}} {{nasmfunc-path}}
  @just _img


# Write the FAT12 image and plant boot sector + system file.
# Mirrors the haribote.img recipe exactly:
#   dd if=/dev/zero ...   → blank 1.44 MB image
#   mformat -f 1440 ...   → FAT12 filesystem (not mkfs.fat — see Makefile note)
#   dd if=ipl10.bin ...   → overwrite sector 0 with IPL
#   mcopy ...             → copy rozios.sys into the FAT12 root

# img::build-commands
[private]
_img:
  @dd if=/dev/zero of={{DEFAULT_IMG_NAME}} bs=512 count=2880
  @mformat -f 1440 -i {{DEFAULT_IMG_NAME}} ::
  @dd if={{DEFAULT_IPL_NAME}} of={{DEFAULT_IMG_NAME}} bs=512 count=1 conv=notrunc
  @mcopy -i {{DEFAULT_IMG_NAME}} {{DEFAULT_SYS_NAME}} ::


# =============================================================================
# Run — launch disk image in QEMU (floppy drive emulation)
# =============================================================================
# Mirrors: qemu-system-i386 -drive file=rozios.img,format=raw,if=floppy

# Launch the disk image in QEMU
run:
  @qemu-system-x86_64 {{QEMU_DEBUG_FLAGS}} -drive format=raw,file={{DEFAULT_IMG_NAME}},if=floppy


# =============================================================================
# Build + run in a single step
# =============================================================================

# Build both boot and kernel sources, then run in QEMU
dry ipl-path asmhead-path bootpack-path nasmfunc-path:
  @just rozios-img {{ipl-path}} {{asmhead-path}} {{bootpack-path}} {{nasmfunc-path}}
  @just run


# =============================================================================
# Clean
# =============================================================================
# Mirrors 'make clean': remove compiled artefacts and listing/map files.
# Also removes the generated rozi.lds (generated artefact, not a source file).

# Remove compiled binaries and listing files
clean:
  @rm -f                        \
    {{DEFAULT_IPL_NAME}}        \
    {{DEFAULT_ASMHEAD_NAME}}    \
    {{DEFAULT_BOOTPACK_NAME}}   \
    {{DEFAULT_NASMFUNC_NAME}}   \
    {{DEFAULT_BOOTPACK_ROZI}}   \
    {{DEFAULT_SYS_NAME}}        \
    {{ROZI_LDS}}                \
    ipl10.lst                   \
    asmhead.lst                 \
    nasmfunc.lst                \
    bootpack.map


# Mirrors 'make src_only': remove everything including the disk image.

# Remove everything, including the disk image
src-only: clean
  @rm -f {{DEFAULT_IMG_NAME}}
