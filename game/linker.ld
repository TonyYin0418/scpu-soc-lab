ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    DMEM (rwx) : ORIGIN = 0x00000000, LENGTH = 4K
}

SECTIONS
{
    . = ORIGIN(IMEM);

    .text : ALIGN(4)
    {
        KEEP(*(.text.start))
        *(.text*)
        *(.rodata*)
    } > IMEM

    . = ALIGN(4);

    .data : ALIGN(4)
    {
        *(.sdata*)
        *(.data*)
    } > DMEM

    .bss (NOLOAD) : ALIGN(4)
    {
        *(.sbss*)
        *(.bss*)
        *(COMMON)
    } > DMEM

    /DISCARD/ :
    {
        *(.comment*)
        *(.riscv.attributes*)
        *(.eh_frame*)
    }
}
