# 恐龙游戏启动代码和中断向量。
#
# 布局（与 rtl/exception_unit.v 的固定向量一致）：
#   0x000  复位入口：设 sp 后跳 main
#   0x300  非法指令向量（不应到达，死循环便于数码管定位 PC）
#   0x320  ECALL 向量（不应到达）
#   0x340  计时中断向量：ticks++ 后 ERET
#
# ISR 只递增 ticks，游戏逻辑全部在 main 循环里按 tick 推进；
# 这样中断随时打断主循环都不会破坏正在画一半的画面状态。

    .section .text.init
    .globl _start
_start:
    li   sp, 0x1000             # 栈顶 = 4KB RAM 末尾，向下生长
    call main
1:  j    1b                     # main 不应返回

    .org 0x300                  # 非法指令
    j    .
    .org 0x320                  # ECALL
    j    .
    .org 0x340                  # 计时中断
    addi sp, sp, -8             # 借用被打断上下文的栈保存现场
    sw   t0, 0(sp)
    sw   t1, 4(sp)
    la   t0, ticks
    lw   t1, 0(t0)
    addi t1, t1, 1
    sw   t1, 0(t0)
    lw   t0, 0(sp)
    lw   t1, 4(sp)
    addi sp, sp, 8
    .word 0x00100073            # ERET：返回 SEPC 重新执行被打断的指令
