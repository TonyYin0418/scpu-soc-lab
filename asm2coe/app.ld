SECTIONS {
    . = 0x0;          /* 代码从地址 0x0 开始 */
    .text : { *(.text) }
}