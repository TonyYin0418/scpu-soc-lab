OUTPUT_ARCH(riscv)
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
        *(.text.pretrap*)
        ASSERT(. <= 0x340, "pre-trap code overlaps timer vector")
        . = 0x340;
        KEEP(*(.text.trap))
        *(.text*)
        . = ALIGN(4);
    } > IMEM

    /* This Harvard SoC cannot read instruction ROM through lw. */
    .rodata : ALIGN(4)
    {
        *(.rodata*)
        . = ALIGN(4);
    } > IMEM

    .data : ALIGN(4)
    {
        *(.sdata*)
        *(.data*)
        . = ALIGN(4);
    } > DMEM

    .bss (NOLOAD) : ALIGN(4)
    {
        __bss_start = .;
        *(.sbss*)
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > DMEM

    __stack_top = ORIGIN(DMEM) + LENGTH(DMEM);

    ASSERT(SIZEOF(.text) <= LENGTH(IMEM), "DINO instruction ROM overflow")
    ASSERT(SIZEOF(.rodata) == 0, "String literals/rodata require a data RAM image")
    ASSERT(SIZEOF(.data) == 0, "Initialized data require a data RAM image")
    ASSERT(__bss_end <= (__stack_top - 1024), "DINO leaves less than 1 KiB stack")

    /DISCARD/ :
    {
        *(.comment*)
        *(.eh_frame*)
    }
}
