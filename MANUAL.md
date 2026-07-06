# SCPU_SOC 手动操作指南

本文档记录无需自动化脚本即可重复执行的人工操作。每个里程碑完成时，必须同步更新本文档中的命令、文件路径和验收现象。

## 1. 当前状态

目前已经完成 37 条指令单周期 CPU 的 RTL 与自检仿真，但尚未完成 FPGA 板级顶层、时钟分频、ROM 固化、显示和实板验证。因此当前可执行的是 Icarus Verilog 仿真流程，Vivado 下板流程仅列出后续框架，不能据此宣称已经完成下板。

所有命令默认在项目根目录 `SCPU_SOC` 中执行。

## 2. 环境检查

确认 Icarus Verilog 和 GTKWave 已安装：

```bash
iverilog -V
vvp -V
gtkwave --version
```

GTKWave 在 macOS 上也可以通过应用方式打开，因此 `gtkwave --version` 不可用时不代表应用一定未安装。

## 3. 编译仿真程序

```bash
mkdir -p build
iverilog -g2012 -Wall -s sccomp_tb -o build/simv -f files.f
```

预期结果：命令退出且没有 error。当前基线下也不应出现 warning。

`files.f` 同时供 Icarus Verilog 和 slang-server 使用，不要在命令中手工维护另一份 RTL 文件列表。

## 4. 运行回归测试

### 4.1 Test-8

```bash
vvp -n build/simv
```

预期终端输出：

```text
[通过] 所有检查均通过
```

### 4.2 AUIPC 补充测试

课程提供的 Test-37 实际没有 AUIPC，因此必须单独运行：

```bash
vvp -n build/simv +TEST_AUIPC
```

预期终端输出：

```text
[通过] 所有检查均通过
```

### 4.3 课程 Test-37

```bash
vvp -n build/simv +TEST37
```

预期可看到 71 条机器指令程序的访存记录，最后输出：

```text
[通过] 所有检查均通过
```

建议按 Test-8、AUIPC、Test-37 的顺序运行，使最后保留的结果和波形对应 Test-37。

检查最后一次测试结果：

```bash
cat build/results.txt
```

预期内容：

```text
PASS
```

注意：只看到 `vvp` 进程退出不代表测试通过，必须同时检查终端的 `[通过]` 和 `build/results.txt` 的 `PASS`。

## 5. 查看波形

命令行安装的 GTKWave：

```bash
gtkwave build/sccomp_tb.vcd
```

macOS 应用方式：

```bash
open -a GTKWave build/sccomp_tb.vcd
```

调试时优先观察：

- `clk`、`rstn`
- `pc`、`instr`
- `RD1`、`RD2`、`immout`
- `ALUOp`、`aluout`、`Zero`
- `RegWrite`、`write_data`
- `mem_write`、`dm_addr`、`dm_write_data`、`dm_type`

波形用于定位失败原因，整体 PASS/FAIL 以自检 testbench 为准。

## 6. 使用自定义机器码文件

`.dat` 文件每行放置一条 32 位十六进制机器指令，不要添加 `0x` 前缀。运行时可以覆盖默认文件和指令数：

```bash
vvp -n build/simv +MEM_FILE=sim/data/your_program.dat +WORDS=71
```

仅替换机器码不会自动产生正确答案。修改测试程序后，还需要在 testbench 中加入独立推导的寄存器和内存期望值。

## 7. Windows Vivado 下板流程（待板级代码完成后维护）

当前还不能直接执行完整下板。后续拿到课程 `CLK_DIV.v`、确认开发板型号并完成板级顶层后，应把本节更新为逐步可执行的正式流程。

计划中的人工步骤如下：

1. 将整个项目目录复制或通过 Git 克隆到 Windows，路径尽量只使用英文、数字和下划线。
2. 安装并启动课程指定版本的 Vivado。
3. 创建 RTL Project，选择准确的开发板或 FPGA part；在型号未确认前不要猜测。
4. 添加可综合 RTL、板级顶层和课程提供并修改后的 `CLK_DIV.v`，不要把 `sim/sccomp_tb.v` 加入综合源。
5. 添加 `constraints/icf.xdc`，并检查顶层端口与 XDC 中 `clk`、`rstn`、`sw_i`、`led_o`、`disp_seg_o`、`disp_an_o` 完全一致。
6. 将 Test-37 固化到指令 ROM。若课程要求 COE/IP，则添加正确的 COE；若允许推断 ROM，则添加 `$readmemh` 使用的初始化文件。
7. 将板载输入时钟按真实 100 MHz、10 ns 周期约束。CPU 全速目标为 50 MHz/25 MHz，慢速观察模式为 `2^24` 分频约 5.96 Hz。
8. 设置正确的板级顶层，依次执行 Run Synthesis、Run Implementation、Open Implemented Design 和 Report Timing Summary。
9. 只有在无关键 DRC、时序满足要求后执行 Generate Bitstream。
10. 连接开发板，在 Hardware Manager 中 Open Target、Program Device，按规定操作复位、运行/慢速模式和寄存器选择开关。
11. 记录 LED/数码管显示、PASS 停机状态、实际 CPU 频率和测试程序结果。

板级代码完成后，本节必须补充以下具体信息：

- Windows 上使用的 Vivado 版本
- 开发板与 FPGA part
- 工程创建方式或 Tcl 命令
- 需要添加的确切源文件
- ROM/COE 文件及配置方式
- 顶层模块名
- 开关、按键、LED 和数码管映射
- 综合、时序和下载时的预期结果

## 8. 常见问题

### 找不到 include 文件

确认从项目根目录执行命令，并检查 `files.f` 中存在：

```text
+incdir+./rtl
```

### 找不到 `.dat` 文件

默认路径位于 `sim/data/`。不要进入 `build/` 后再运行 `vvp`；应始终在项目根目录运行。

### GTKWave 显示时间单位异常

testbench 已设置 `` `timescale 1ns/1ps``。重新编译和运行后再打开最新的 `build/sccomp_tb.vcd`。

