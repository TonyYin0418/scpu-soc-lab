    .section .text.start, "ax", @progbits
    .globl _start
    .type _start, @function

_start:
    addi t0, zero, 1
    slli t0, t0, 4
    addi t0, t0, -1

1:
    jal zero, 1b

    .size _start, . - _start
