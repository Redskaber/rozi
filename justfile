# =============================================================================
# Justfile for Rozi OS build
# =============================================================================
# This justfile reproduces the functionality of the original Makefile:
#   - Compile boot sector (NASM) → binary
#   - Compile kernel (NASM) → system binary
#   - Create a 1.44MB FAT12 floppy image
#   - Write boot sector to first 512 bytes
#   - Copy system file into the image
#   - Run the image with QEMU
#   - Clean build artifacts
#
# Dependencies:
#   - nasm         (assembler)
#   - mtools       (mformat, mcopy)
#   - dd           (coreutils)
#   - qemu-system-x86_64
# =============================================================================

# -----------------------------------------------------------------------------
# Default names for output files
# -----------------------------------------------------------------------------
DEFAULT_BIN_NAME := 'rozios.bin'      # Boot sector binary (512 bytes)
DEFAULT_SYS_NAME := 'rozios.sys'      # Kernel/system binary (loaded by boot sector)
DEFAULT_IMG_NAME := 'rozios.img'      # Final floppy disk image (1.44MB FAT12)

# -----------------------------------------------------------------------------
# Generic NASM compilation rule
# Usage: just make <source.nas> [output_file]
# -----------------------------------------------------------------------------
# Assemble a NASM source file into a flat binary
make path out:
    @nasm -f bin {{path}} -o {{out}}

# -----------------------------------------------------------------------------
# Create the full disk image from boot sector and kernel sources
# Usage: just img <boot_source.nas> <kernel_source.nas>
# -----------------------------------------------------------------------------
# Build boot sector, kernel, and create the FAT12 disk image
img bpath spath:
    @just make {{bpath}} {{DEFAULT_BIN_NAME}}
    @just make {{spath}} {{DEFAULT_SYS_NAME}}
    @just _img

# -----------------------------------------------------------------------------
# Internal recipe: create a FAT12 floppy image and write boot sector + system file
# -----------------------------------------------------------------------------
[private]
_img:
    @dd if=/dev/zero of={{DEFAULT_IMG_NAME}} bs=512 count=2880
    @mformat -f 1440 -i {{DEFAULT_IMG_NAME}} ::
    @dd if={{DEFAULT_BIN_NAME}} of={{DEFAULT_IMG_NAME}} bs=512 count=1 conv=notrunc
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
dry bpath spath:
    @just img {{bpath}} {{spath}}
    @just run

# -----------------------------------------------------------------------------
# Clean build artifacts (binaries and listing files) - equivalent to 'make clean'
# -----------------------------------------------------------------------------
# Remove compiled binaries and listing files
clean:
    @rm -rf {{DEFAULT_BIN_NAME}} {{DEFAULT_SYS_NAME}} *.lst

# -----------------------------------------------------------------------------
# Completely clean everything including the final disk image - equivalent to 'make src_only'
# -----------------------------------------------------------------------------
# Remove everything, including the disk image
src_only: clean
    @rm -rf {{DEFAULT_IMG_NAME}}


