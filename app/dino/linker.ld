OUTPUT_ARCH(riscv)
ENTRY(_start)

/*
 * 当前 SoC 是 Harvard 结构：指令 ROM 与数据 RAM 都有 4 KiB，地址空间可重叠。
 * RAM 从 0x400 起放置可写数据，栈顶设为 0x1400；板级 RAM 只使用地址低 12 位，
 * 因此栈会映射到物理 RAM 高端并向下增长。
 */
MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    RAM (rwx) : ORIGIN = 0x00000400, LENGTH = 4K
}

SECTIONS
{
    .text : ALIGN(4)
    {
        KEEP(*(.text.start))
        *(.text*)
        . = ALIGN(4);
    } > ROM

    .data : ALIGN(4)
    {
        __data_start = .;
        /* Harvard 结构中，C 字符串也必须通过数据 RAM 读取。 */
        *(.rodata*)
        *(.sdata*)
        *(.data*)
        . = ALIGN(4);
        __data_end = .;
    } > RAM

    .bss (NOLOAD) : ALIGN(4)
    {
        __bss_start = .;
        *(.sbss*)
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
    __stack_reserve = 512;

    ASSERT(__bss_end <= (__stack_top - __stack_reserve),
           "DINO data/BSS leaves less than 512 bytes for stack")

    /DISCARD/ :
    {
        *(.comment*)
        *(.eh_frame*)
    }
}
