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

- `teacher_test_1_instr.coe`
  - 来源：原项目根目录 `test.coe`，文件头注释为 `;1.asm`
  - 用途：老师新给的测试/演示 ROM 程序，适合导入 Vivado `ROM_D`
  - 指令数：659
  - 检查结论：COE 格式可解析，所有条目均为 32 位十六进制指令，数量小于当前 `ROM_D` 1024 深度
  - 注意：当前 Icarus `sccomp_tb` 的指令 ROM 只有 128 words，且没有该程序的自检预期值，因此不能直接用现有 testbench 完整判定 PASS/FAIL

## sim/

- `test8_instr.coe`
  - 来源：原 `sim/data/Test_8_Instr.coe`
  - 用途：保留作 COE 格式参考
  - 当前 Icarus 回归实际使用 `sim/data/Test_8_Instr.dat`

