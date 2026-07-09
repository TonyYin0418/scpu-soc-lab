    .section .text.start, "ax", @progbits
    .globl _start
    .type _start, @function

_start:
    li sp, 0x1000
    call main

.Lhalt:
    j .Lhalt
