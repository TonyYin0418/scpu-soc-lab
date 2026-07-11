# 计时中断端到端 smoke 程序。
#
# 目标：不用测试台强制 INT，完全靠软件把老师 Counter_x 编程为周期模式，
# 验证 MIO_BUS 译码 -> Counter_x -> SCPU.INT -> trap 向量 -> ERET 整条链路。
#
# 外设协议（老师 Counter_8253 注释 + SPIO 通道锁存）：
#   sw 0xF0000000  低 2 位 = 通道选择（0..2 计数值，3 控制字）
#   sw 0xF0000004  向当前选中通道写入数值（本工程新增 counter_we 译码）
#   通道 0 控制字 bit[2:1]=01 -> 周期模式：减到 0 输出 1 拍脉冲并自动重装
#   sw 0xFFFFFF00  写 INTMASK（bit6 = 允许计时中断），写入同时清 pending
#
# 现象：计时中断服务程序把递增的 tick 写到 0xE0000000 显示 MMIO。
# 测试台看到 display_write 依次为 1、2、3 即判 PASS。

    .section .text
    .globl _start
_start:
    # 通道选择 = 3，写控制字：通道 0 模式 01（周期方波脉冲）
    lui  t0, 0xf0000
    li   t1, 3
    sw   t1, 0(t0)              # SPIO: counter_set <= 3
    li   t1, 0b010              # counter_Ctrl[2:1] = 01
    sw   t1, 4(t0)              # Counter_x: counter_Ctrl
    # 通道选择 = 0，写通道 0 计数初值
    li   t1, 0
    sw   t1, 0(t0)              # SPIO: counter_set <= 0
    li   t1, 50                 # clk0=781.25kHz，50 拍 ≈ 64us 一次中断（仿真用）
    sw   t1, 4(t0)              # Counter_x: counter0_Lock
    # tick 存放在数据 RAM 0x100
    li   s0, 0x100
    sw   zero, 0(s0)
    # 打开计时中断（最后一步，此前的杂散 pending 会被这次写入清掉）
    li   t0, -256               # 0xFFFFFF00
    li   t1, 0x40
    sw   t1, 0(t0)              # INTMASK[6] = 1
main_loop:
    j    main_loop              # 主程序空转，一切动作都发生在中断里

    .org 0x300                  # 非法指令向量（本程序不应到达）
    j    .
    .org 0x320                  # ECALL 向量（本程序不应到达）
    j    .
    .org 0x340                  # 计时中断向量
    lw   t0, 0(s0)              # tick++
    addi t0, t0, 1
    sw   t0, 0(s0)
    lui  t1, 0xe0000
    sw   t0, 0(t1)              # 把 tick 写到显示 MMIO，供测试台观察
    .word 0x00100073            # ERET：返回 SEPC，重新执行被打断的指令
