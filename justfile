# =============================================================================
# Justfile for Rozi OS build
# =============================================================================
# Reproduces the full Makefile pipeline:
#   - Platform detection (x86 / Raspberry Pi / macOS)
#   - Compiler prefix selection (GCCPREFIX)
#   - NASM assembly → binary
#   - C kernel compilation (gcc → as → ld) → bootpack.bin
#   - haribote.sys = asmhead.bin + bootpack.bin
#   - FAT12 floppy image construction
#   - QEMU launch
#   - Clean / src_only
#
# Dependencies:
#   - nasm, gcc / i686-linux-gnu-gcc / x86_64-elf-gcc
#   - binutils (as, ld)
#   - mtools (mformat, mcopy)
#   - dd (coreutils)
#   - qemu-system-x86_64
# =============================================================================

# -----------------------------------------------------------------------------
# Platform detection & toolchain prefix
# -----------------------------------------------------------------------------

# Detect Raspberry Pi from /proc/cpuinfo (works on Linux; safe no-op on others)
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
#   macOS  → x86_64-elf-
#   RPi    → i686-linux-gnu-
#   other  → (empty)
GCCPREFIX := if _is_macos == "1" {
    "x86_64-elf-"
} else if _is_rpi == "1" {
    "i686-linux-gnu-"
} else {
    ""
}


NASM    := "nasm"
CC      := GCCPREFIX + "gcc"
AS      := GCCPREFIX + "as"
LD      := GCCPREFIX + "ld"
CFLAGS  := "-ffreestanding -nostdlib -nostartfiles"
LDFLAGS := "-Ttext 0x1000"


# -----------------------------------------------------------------------------
# Default names for output files
# -----------------------------------------------------------------------------
# ipl
DEFAULT_IPL_NAME      := "ipl10.bin"       # Boot sector binary (512 bytes)  (rozios.bin)

# sys
DEFAULT_ASMHEAD_NAME  := "asmhead.bin"     # asm head and c loader  ==>  *.sys
DEFAULT_BOOTPACK_S    := "bootpack.s"
DEFAULT_BOOTPACK_O    := "bootpack.o"
DEFAULT_BOOTPACK_NAME := "bootpack.bin"    # c to asm               ==>  *.sys

DEFAULT_SYS_NAME      := 'rozios.sys'      # Kernel/system binary (loaded by boot sector)

# img
DEFAULT_IMG_NAME      := 'rozios.img'      # Final floppy disk image (1.44MB FAT12)


# -----------------------------------------------------------------------------
# Default target
# -----------------------------------------------------------------------------
# default build flow
default ipath apath bpath:
  @just img {{ipath}} {{apath}} {{bpath}}


# -----------------------------------------------------------------------------
# Helper: check macOS cross-toolchain availability
# -----------------------------------------------------------------------------
[private]
_check-macos-toolchain:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(uname -s)" = "Darwin" ]; then
        if ! command -v x86_64-elf-gcc &>/dev/null; then
            echo "ERROR: x86_64-elf-gcc not found."
            echo "       brew install x86_64-elf-gcc"
            exit 1
        fi
        if ! command -v x86_64-elf-ld &>/dev/null; then
            echo "ERROR: x86_64-elf-ld not found."
            echo "       brew install x86_64-elf-binutils"
            exit 1
        fi
    fi


# -----------------------------------------------------------------------------
# Assemble a NASM source file into a flat binary
# Usage: just asm <source.nas> <output.bin>
# -----------------------------------------------------------------------------
# Assemble a NASM source file into a flat binary
asm path out:
    @{{NASM}} -f bin {{path}} -o {{out}}


# -----------------------------------------------------------------------------
# ipl10.bin — boot sector (IPL)
# -----------------------------------------------------------------------------
# ipl::boot sector ipl 10
ipl10 path: _check-macos-toolchain
    @just asm  {{path}} {{DEFAULT_IPL_NAME}}


# -----------------------------------------------------------------------------
# asmhead.bin — protected-mode stub
# -----------------------------------------------------------------------------
# sys::protected-mode stub
asmhead path: _check-macos-toolchain
    @just asm {{path}} {{DEFAULT_ASMHEAD_NAME}}


# -----------------------------------------------------------------------------
# bootpack.bin — C kernel
# Mirrors the Makefile pipeline: gcc -S → as → ld
# -----------------------------------------------------------------------------
# sys::bootpack.c gcc -S -> as -> ld
bootpack path: _check-macos-toolchain
    #!/usr/bin/env bash
    set -euo pipefail
    {{CC}} -S {{CFLAGS}} {{path}} -o {{DEFAULT_BOOTPACK_S}}
    {{AS}} {{DEFAULT_BOOTPACK_S}} -o {{DEFAULT_BOOTPACK_O}}
    {{LD}} {{LDFLAGS}} {{DEFAULT_BOOTPACK_O}} -o {{DEFAULT_BOOTPACK_NAME}}


# -----------------------------------------------------------------------------
# haribote.sys — concatenate asmhead.bin + bootpack.bin
# -----------------------------------------------------------------------------
# build *.sys file
sys apath bpath:
  @just asmhead {{apath}}
  @just bootpack {{bpath}}
  @cat {{DEFAULT_ASMHEAD_NAME}} {{DEFAULT_BOOTPACK_NAME}} > {{DEFAULT_SYS_NAME}}


# -----------------------------------------------------------------------------
# Create the full disk image from boot sector and kernel sources
# Usage: just img <boot_source.nas> <kernel_source.nas>
# -----------------------------------------------------------------------------
# Build boot sector, kernel, and create the FAT12 disk image
img ipath apath bpath:
  @just ipl10 {{ipath}}
  @just sys {{apath}} {{bpath}}
  @just _img


# -----------------------------------------------------------------------------
# Internal recipe: create a FAT12 floppy image and write boot sector + system file
# -----------------------------------------------------------------------------
# dd + mformat + dd + mcopy pipeline exactly
[private]
_img:
    @dd if=/dev/zero of={{DEFAULT_IMG_NAME}} bs=512 count=2880
    @mformat -f 1440 -i {{DEFAULT_IMG_NAME}} ::
    @dd if={{DEFAULT_IPL_NAME}} of={{DEFAULT_IMG_NAME}} bs=512 count=1 conv=notrunc
    @mcopy -i {{DEFAULT_IMG_NAME}} {{DEFAULT_SYS_NAME}} ::


# -----------------------------------------------------------------------------
# Run the disk image with QEMU (emulates a floppy drive)
# -----------------------------------------------------------------------------
# Launch the disk image in QEMU
run:
    @qemu-system-x86_64 -drive format=raw,file={{DEFAULT_IMG_NAME}},if=floppy

# -----------------------------------------------------------------------------
# Quick single‑file build + run (useful for testing a boot sector only)
# Usage: just dry <source.nas>
# -----------------------------------------------------------------------------
# Build both boot and kernel sources, then run in QEMU
dry ipath apath bpath:
    @just img {{ipath}} {{apath}} {{bpath}}
    @just run

# -----------------------------------------------------------------------------
# Clean build artifacts (binaries and listing files) - equivalent to 'make clean'
# -----------------------------------------------------------------------------
# Remove compiled binaries and listing files
clean:
    @rm -f {{DEFAULT_IPL_NAME}} {{DEFAULT_ASMHEAD_NAME}} {{DEFAULT_BOOTPACK_NAME}} \
      {{DEFAULT_BOOTPACK_S}} {{DEFAULT_BOOTPACK_O}} {{DEFAULT_SYS_NAME}} \
      *.lst *.elf

# -----------------------------------------------------------------------------
# Completely clean everything including the final disk image - equivalent to 'make src_only'
# -----------------------------------------------------------------------------
# Remove everything, including the disk image
src_only: clean
    @rm -f {{DEFAULT_IMG_NAME}}


