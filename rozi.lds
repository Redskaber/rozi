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
