/* 恐龙游戏链接脚本。
 *
 * 板级系统是哈佛结构：指令 ROM（ROM_D，4KB）只被取指访问，数据 RAM
 * （RAM_B，4KB）只被 lw/sw 访问，两者地址都从 0x0 开始、互不冲突。
 * 因此 .text 放 ROM 区（导出为 I_dino.coe），.rodata/.data 放 RAM 区
 * （导出为 D_dino.coe，Vivado 里初始化 RAM_B），.bss 依赖 RAM 上电为 0。
 */
MEMORY {
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    RAM (rw)  : ORIGIN = 0x00000000, LENGTH = 4K
    /* 仅用于给 RAM 段一个不与 ROM 重叠的加载地址（LMA），
     * 让 ld 不报 overlap；实际数据由 objcopy 按段抽取，LMA 不参与运行 */
    LOAD (r)  : ORIGIN = 0x10000000, LENGTH = 4K
}

SECTIONS {
    .text : {
        KEEP(*(.text.init))     /* start.S 的复位入口和中断向量必须在最前 */
        *(.text*)
    } > ROM

    .rodata : { *(.rodata*) *(.srodata*) } > RAM AT> LOAD
    .data   : { *(.data*) *(.sdata*) } > RAM AT> LOAD
    .bss    : { *(.bss*) *(.sbss*) *(COMMON) } > RAM

    /* 栈顶 = RAM 末尾，向下生长 */
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
