# COE 文件说明

本目录保存 Vivado ROM/RAM IP 使用的初始化文件。Icarus 自检仿真默认使用 `sim/data/*.dat`，不是直接读取这里的 `.coe`。

## board/

- `board_io_demo_instr.coe`
  - 来源：原项目根目录 `I_mem.coe`
  - 用途：Vivado `ROM_D` 初始化文件
  - 现状：已用于老师 EDF 外围和自研单周期 CPU 的板级 IO 演示验证
  - 指令数：103

- `board_io_demo_data.coe`
  - 来源：原项目根目录 `D_mem.coe`
  - 用途：Vivado `RAM_B` 初始化文件
  - 现状：已用于板级 IO 演示；其中包含图形/矩形显示数据表
  - 数据字数：43

- `testac.coe`
  - 用途：当前单周期 CPU 实板验收 ROM 程序，导入 Vivado `ROM_D`
  - 指令数：670
  - 检查结论：COE 格式可解析，所有条目均为 32 位十六进制指令，数量小于当前 `ROM_D` 1024 深度
  - 实板结论：使用自研 `rtl/SCPU.v` 通过，成功后进入 `88C6` 循环动画；老师 `edf/SCPU.edf` 在该测试中停在 `FA123456`

- `testac模拟.txt`
  - 用途：`testac.coe` 的执行轨迹说明，用于核对阶段标记和失败处理逻辑
  - 检查结论：当前文件前 1000 条执行轨迹与 `testac.coe` 的指令索引逐条对齐
  - 关联反汇编：`docs/disasm/testac.disasm.md`

`testac.coe` 的显示协议：

```text
00111100 -> Test 1 阶段标记
00222200 -> Test 2 阶段标记
00333300 -> Test 3 阶段标记
00444400 -> Test 4 阶段标记
00555500 -> Test 5 阶段标记
00666600 -> Test 6 阶段标记

FAAAAAA1 -> Test 1 失败
FAAAAA12 -> Test 2 失败
FAAAA123 -> Test 3 失败
FAAA1234 -> Test 4 失败
FAA12345 -> Test 5 失败
FA123456 -> Test 6 失败
```

全通过后程序进入无限成功动画，常见完整帧包括 `FF88C6FF`、`FFFF88C6`、`C6FFFF88`、`88C6FFFF`。程序通过写 `0xE0000000` 的 MMIO 显示地址驱动数码管，不使用 LED 作为主要 PASS/FAIL 指示。

## sim/

- `test8_instr.coe`
  - 来源：原 `sim/data/Test_8_Instr.coe`
  - 用途：保留作 COE 格式参考
  - 当前 Icarus 回归实际使用 `sim/data/Test_8_Instr.dat`
