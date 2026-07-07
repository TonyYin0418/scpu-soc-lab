# SCPU_SOC 手动操作指南

本文档记录无需自动化脚本即可重复执行的人工操作。每个里程碑完成时，必须同步更新本文档中的命令、文件路径和验收现象。

## 1. 当前状态

目前已经完成 37 条指令单周期 CPU 的 RTL 与自检仿真，也已经按老师原理图建立 `board/top.v`。板级顶层先用老师的 `edf/SCPU.edf` 完成外围基线验证，随后已将 `edf/SCPU.edf` 替换为自己的 `rtl/SCPU.v`，并在 Vivado 中使用 `coe/board/board_io_demo_instr.coe`、`coe/board/board_io_demo_data.coe` 完成 bitstream 生成和 Program Device 实板验证。

当前自研 CPU 板级基线已经能运行参考 IO 程序：跑马灯、0~F 显示、寄存器递增等功能符合要求。此前矩形/图形变化显示异常已确认不是 CPU、顶层、RAM/ROM 或 `SSeg7` 接口问题，而是老师给的矩形变换测试/图形编码本身有误，疑似共阳极/共阴极硬编码混淆；该现象不再作为本项目实现遗留问题。

当前板级代码的端口连接已通过 Icarus 黑盒接口检查。此检查只能发现模块名、端口名和位宽错误，不能仿真 EDF 内部功能，也不能代替 Vivado 综合。自研 CPU 已完成一次实板 IO 演示验证；若老师要求 Test-37 专用 COE 下板，还需要单独生成并导入 Test-37 对应 COE。

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

`files.f` 供原单周期 Icarus 仿真使用，`board_own_files.f` 供自研 CPU 替换老师 SCPU 后的完整板级接口检查使用。当前 VS Code/mshr-h Verilog 插件也通过 `.slang/server.json` 使用 `board_own_files.f`，并配合精确 `indexGlobs` 建立跨文件跳转索引。

当前确认可用的 slang-server 方案是：

```json
{
  "flags": "-f board_own_files.f -Wno-duplicate-definition -Wno-unused-port -Wno-undriven-port -Wno-unused-but-set-net",
  "indexGlobs": [
    "board/*.v",
    "rtl/*.v",
    "rtl/*.vh",
    "IO/*.v",
    "editor/*.v",
    "edf/MIO_BUS.V",
    "edf/SPIO.v",
    "edf/Multi_8CH32.v",
    "edf/SSeg7.v",
    "sim/*.v"
  ],
  "build": "board_own_files.f"
}
```

`indexGlobs` 是旧字段，但 native `slang-server 0.2.7` 仍支持，且当前项目实测最稳定。使用它的原因是：

- `edf/MIO_BUS.V` 是大写 `.V`，普通目录索引容易漏掉。
- 不能直接索引整个 `edf/` 目录，否则可能同时看到老师 `edf/SCPU.v` 和自研 `rtl/SCPU.v`，造成同名模块混乱。
- `flags` 中必须包含 `-f board_own_files.f`，否则打开 `board/top.v` 时可能能消除部分红线但无法稳定 Go to Definition。

自研 CPU 替换老师 `SCPU.edf` 的本地端口检查使用 `board_own_files.f`。它用 `rtl/SCPU.v` 及其依赖替代 `edf/SCPU.v`，并使用自研 `rtl/dm_controller.v` 替代老师 `dm_controller` 黑盒；其余外围仍使用老师 EDF stub。

若重启 VS Code 后 Problems 又出现整页 `unknown module`，或 Cmd/F12 跳转一直 Loading，按以下顺序恢复：

1. 确认 VS Code 打开的根目录是项目根目录 `SCPU_SOC`，不是 `board/` 或上一级 `Documents/`。
2. 确认安装并启用 native slang-server：

```bash
~/.local/bin/slang-server --version
```

预期类似：

```text
slang-server version 0.2.7+50b2661
```

3. VS Code User Settings JSON 中应有：

```json
{
  "verilog.slangServer.enabled": true,
  "verilog.slangServer.runtime": "native",
  "verilog.slangServer.path": "/Users/tonyyin/.local/bin/slang-server"
}
```

4. 执行 **Developer: Reload Window**。
5. 执行 **Verilog: Restart slang-server**。
6. 执行 **Verilog: Doctor**，确认 `runtime = native`、`state = running`、`build = board_own_files.f`。
7. 在 `board/top.v` 中对 `SCPU`、`clk_div`、`MIO_BUS` 右键 Go to Definition。当前已验证应分别跳到 `rtl/SCPU.v`、`IO/clk_div.v`、`edf/MIO_BUS.V`。

如果 Doctor 显示还在使用 WASM，或 `build` 不是 `board_own_files.f`，优先修正 native runtime 和 `.slang/server.json`，不要退回旧的 `board_own_deps.f` 方案。

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

## 7. Windows Vivado：老师 EDF 板级基线

当前 `constraints/icf.xdc` 已匹配本顶层端口并按 Nexys A7-100T 管脚补齐。老师的 EDF 由 Vivado 2018.1 为 `xc7a100tcsg324-1` 生成；优先使用相同 Vivado 版本和器件，除非老师随后给出的工程明确指定其他型号。

### 7.1 复制并创建工程

1. 将整个项目复制到 Windows，路径只使用英文、数字和下划线，例如 `D:\\FPGA\\SCPU_SOC`。
2. 在 Vivado 2018.1 中选择 **Create Project → RTL Project**，不要勾选立即添加所有目录。
3. 选择器件 `xc7a100tcsg324-1`。
4. 添加以下 Design Sources：

```text
board/top.v
IO/Enter.v
IO/clk_div.v
IO/Counter_3_IO.v
edf/SCPU.edf
edf/MIO_BUS.edf
rtl/dm_controller.v
edf/SPIO.edf
edf/Multi_8CH32.edf
edf/SSeg7.edf
```

`edf/*.v` 是网表接口 stub，主要供编辑器和接口检查使用。若 Vivado 已能从 EDF 正确识别端口，不必再把 stub 加入综合；不要添加 `rtl/SCPU.v`，否则会与老师的 `SCPU.edf` 重名。不要添加 `edf/dm_controller.edf` 或 `edf/dm_controller.v`，当前 RAM 字节写使能和读数据扩展由自研 `rtl/dm_controller.v` 实现。也不要添加 `sim/sccomp_tb.v`。

`editor/ip_stubs.v` 只用于 VS Code/slang 和 Icarus 的端口检查，不得加入 Vivado Design Sources；Vivado 使用 IP Catalog 实际生成的 `ROM_D`、`RAM_B`。

5. 在 Sources 中右键 `top`，选择 **Set as Top**。

### 7.2 创建 ROM_D

在 IP Catalog 中选择 **Distributed Memory Generator**：

- Component Name：`ROM_D`
- Memory Type：ROM
- Data Width：32
- Depth：1024，对应地址端口 `a[9:0]`
- 输出端口：异步 `spo[31:0]`，不要增加输出寄存器
- 初始化文件：`coe/board/board_io_demo_instr.coe`

生成后检查实例端口恰好是 `a[9:0]` 和 `spo[31:0]`。如果 Vivado 生成了不同端口，不要修改 `top.v` 去迁就错误的 IP 配置，应返回 IP 设置修正。

### 7.3 创建 RAM_B

在 IP Catalog 中选择 **Block Memory Generator**：

- Component Name：`RAM_B`
- Interface Type：Native
- Memory Type：Single Port RAM
- Write Width / Read Width：32
- Depth：1024，对应 `addra[9:0]`
- 启用 Byte Write Enable，得到 `wea[3:0]`
- 不增加额外输出寄存器
- 初始化文件：`coe/board/board_io_demo_data.coe`

生成后端口应为 `clka`、`wea[3:0]`、`addra[9:0]`、`dina[31:0]`、`douta[31:0]`。RAM 的最终读写模式若老师提供的 PPT/IP 截图有明确要求，以老师配置为准。

### 7.4 时钟和显示操作

板载输入 `clk` 是 100 MHz。当前 `IO/clk_div.v` 的真实行为是：

- `SW[2]=0`：CPU 使用 `clkdiv[3]`，频率 6.25 MHz。
- `SW[2]=1`：CPU 使用 `clkdiv[24]`，频率约 2.98 Hz；该位每 `2^24` 个输入周期翻转一次，完整周期为 `2^25` 分频。
- `SW[7:5]`：选择数码管显示源，依次为外设输入、`PC[31:2]`、当前指令、计数器、CPU 地址、CPU 写数据、CPU 读数据、PC。
- `SW[4:3]`：由当前 `coe/board/board_io_demo_instr.coe` 中的 IO 演示程序读取并决定显示效果；已观察到跑马灯、0~F 数据显示、寄存器递增等模式符合参考要求。
- `SW[0]`：传入 `SSeg7` 的文本/图形显示选择。此前矩形/图形变化显示异常已确认来自老师测试/图形编码问题，不作为 CPU 或顶层实现错误。

当前实现是自动慢速运行，不是按钮按一下执行一步。按钮单步等老师基线成功后再增加。

### 7.5 XDC、综合与下载

1. 将 `constraints/icf.xdc` 添加为 Constraints Source。
2. 检查 `clk` 的周期约束为 10 ns；不要把约束改成 CPU 分频后的周期。
3. 依次执行 **Run Synthesis → Run Implementation → Report Timing Summary**。
4. 确认没有 unconstrained top-level port、unresolved black box、关键 DRC 或负的 setup slack 后，再执行 **Generate Bitstream**。
5. 在 Hardware Manager 中 **Open Target → Auto Connect → Program Device**。
6. 先复位，再用 `SW[2]=1` 慢速观察 PC/指令变化；确认基本运行后切换到 `SW[2]=0`。

当前顶层没有独立的 PASS 灯或自动停机逻辑。`coe/board/board_io_demo_instr.coe`/`coe/board/board_io_demo_data.coe` 当前是老师板级 IO 演示程序和数据，不是 Icarus 仿真使用的 `sim/data/Test_37_Instr8.dat`。因此本阶段的实板结果用于确认 CPU 与板级 IO 外围可运行；课程 Test-37 的指令正确性仍以 Icarus 自检为主要证据。如需 Test-37 实板验收，应另行导入 Test-37 对应 COE。

已完成的实板观察：

- Vivado bitstream 生成成功，Program Device 成功。
- 使用老师 `edf/SCPU.edf`、`coe/board/board_io_demo_instr.coe`、`coe/board/board_io_demo_data.coe` 时，跑马灯、0~F 数据显示、寄存器递增等参考功能符合要求。
- 替换为自己的 `rtl/SCPU.v` 后，重新生成 bitstream 并 Program Device，参考 IO 测试现象仍符合要求。
- 老师给的矩形/图形变化测试代码或图形编码存在问题，疑似共阳极/共阴极硬编码混淆；该问题不影响 CPU、顶层或自研 `dm_controller` 的正确性判断。

### 7.6 后续替换为自己的 CPU

老师 EDF 外围系统和自研单周期 CPU 都已经完成一次实板基线验证。后续继续保持同一个板级外壳：外围的 MIO、RAM 控制、数码管和计数器保持不变，CPU 实现可以在老师 `SCPU.edf`、自研单周期 CPU、后续流水线 CPU 之间替换。

当前 `feature/own-scpu-board` 分支已经做了最小兼容：

- `rtl/SCPU.v` 端口对齐老师 `edf/SCPU.v`，使用 `dm_ctrl` 替代原 `DMType` 外部端口。
- `MIO_ready`、`CPU_MIO`、`INT` 已补齐。当前 37 条单周期阶段暂不实现中断或 ready/stall 机制，`CPU_MIO` 初版固定为 `1'b0`。
- `reg_sel`、`reg_data` 不再属于 `SCPU` 板级端口；仿真 wrapper `rtl/sccomp.v` 保留自己的调试输出。
- 新增 `board_own_files.f`，用于检查 `board/top.v` 能否直接例化自研 `rtl/SCPU.v`。

本地验证命令：

```bash
iverilog -g2012 -Wall -s sccomp_tb -o build/simv -f files.f
vvp -n build/simv
vvp -n build/simv +TEST_AUIPC
vvp -n build/simv +TEST37
iverilog -g2012 -Wall -s top -o build/top_own_check -f board_own_files.f
```

进入 Vivado 替换时：

1. 禁用或移除 `edf/SCPU.edf`。
2. 加入以下自研 CPU RTL：

```text
rtl/SCPU.v
rtl/ctrl.v
rtl/alu.v
rtl/EXT.v
rtl/NPC.v
rtl/PC.v
rtl/RF.v
rtl/ctrl_encode_def.v
```

3. 保持以下外围不变：

```text
edf/MIO_BUS.edf
rtl/dm_controller.v
edf/SPIO.edf
edf/Multi_8CH32.edf
edf/SSeg7.edf
ROM_D
RAM_B
constraints/icf.xdc
board/top.v
```

4. 重新执行综合、实现、生成 bitstream 和 Program Device。

如果 Vivado 报 `duplicate definition of SCPU`，说明老师 `edf/SCPU.edf` 和自研 `rtl/SCPU.v` 被同时加入了工程；必须只保留其中一个。

## 8. 从汇编生成 COE

老师提供的工具位于 `asm2coe/`，需要 RISC-V GNU 工具链。Linux/WSL 中执行：

```bash
cd asm2coe
make
```

默认由 `Test_37_Instr8.S` 生成 `Test_37_Instr8.coe`、反汇编和机器码。生成后先检查反汇编，再在 Vivado 的 `ROM_D` 中选择该 COE。不要用新的测试 COE 覆盖现有 `coe/board/board_io_demo_instr.coe`，除非已经确认两者用途和预期结果。

当前 COE 文件整理如下：

```text
coe/
├── board/
│   ├── board_io_demo_instr.coe   # 原 I_mem.coe，已完成实板 IO 演示验证
│   ├── board_io_demo_data.coe    # 原 D_mem.coe，板级 IO 演示数据
│   └── teacher_test_1_instr.coe  # 原 test.coe，659 条指令，适合 1024 深度 ROM_D
└── sim/
    └── test8_instr.coe           # 原 Test_8_Instr.coe，仅保留作 COE 参考；Icarus 使用 .dat
```

## 9. 常见问题

### 找不到 include 文件

确认从项目根目录执行命令，并检查 `files.f` 中存在：

```text
+incdir+./rtl
```

### 找不到 `.dat` 文件

默认路径位于 `sim/data/`。不要进入 `build/` 后再运行 `vvp`；应始终在项目根目录运行。

### GTKWave 显示时间单位异常

testbench 已设置 `` `timescale 1ns/1ps``。重新编译和运行后再打开最新的 `build/sccomp_tb.vcd`。
