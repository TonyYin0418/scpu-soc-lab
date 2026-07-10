    .option norvc
    .section .text.start, "ax", @progbits
    .globl _start
    .type _start, @function

_start:
    la sp, __stack_top

    /* .data/只读字符串由 D_dino_game.coe 预装；这里只清零 .bss。 */
    la t1, __bss_start
    la t2, __bss_end
1:
    bgeu t1, t2, 4f
    sw zero, 0(t1)
    addi t1, t1, 4
    jal zero, 1b

4:
    call main

5:
    jal zero, 5b

    .size _start, . - _start
