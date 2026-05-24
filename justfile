# This file is make ps


DEFAULT_IMG_NAME  := "helloos.img"


# use nasm make img
make path out=DEFAULT_IMG_NAME:
  @nasm -f bin {{path}} -o {{out}}


# use qemu run img
run:
  @qemu-system-x86_64 -drive format=raw,file={{DEFAULT_IMG_NAME}}


