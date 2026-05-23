#!/bin/sh
# used qemu-system-x86_64 running img
# qemu-system-x86_64 -fda days/day01/helloos.img
qemu-system-x86_64 -drive format=raw,file=helloos.img
