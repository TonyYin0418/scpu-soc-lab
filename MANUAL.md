# SCPU_SOC 手动操作指南

本文档记录无需自动化脚本即可重复执行的人工操作。每个里程碑完成时，必须同步更新本文档中的命令、文件路径和验收现象。

## 1. 当前状态

目前已经完成 37 条指令单周期 CPU 的 RTL 与自检仿真，也已经按老师原理图建立 `board/top.v`。板级顶层先用老师的 `edf/SCPU.edf` 完成外围基线验证，随后已将 `edf/SCPU.edf` 替换为自己的 `rtl/SCPU.v`，并在 Vivado 中使用 `coe/board/board_io_demo_instr.coe`、`coe/board/board_io_demo_data.coe` 完成 bitstream 生成和 Program Device 实板验证。

当前自研 CPU 板级基线已经能运行参考 IO 程序：跑马灯、0~F 显示、寄存器递增等功能符合要求。此前矩形/图形变化显示异常已确认不是 CPU、顶层、RAM/ROM 或 `SSeg7` 接口问题，而是老师给的矩形变换测试/图形编码本身有误，疑似共阳极/共阴极硬编码混淆；该现象不再作为本项目实现遗留问题。

当前板级代码的端口连接已通过 Icarus 黑盒接口检查。此检查只能发现模块名、端口名和位宽错误，不能仿真 EDF 内部功能，也不能代替 Vivado 综合。自研 CPU 已完成 `testac.coe` 实板验收：`SW[7:5]=000`、`SW[2]=0` 时，阶段标记后进入 `88C6` 成功动画。老师 `SCPU.edf` 在同一 `testac.coe` 下会停在 `FA123456`，后续单周期验收以自研 `rtl/SCPU.v` 的实测结果为准。

当前正在 `feature/pipeline-cpu` 分支推进 70–80 分阶段。该分支采用方案 B：`rtl/SCPU.v` 直接作为五级冒险流水线 CPU，单周期版本通过 `main` 分支和历史 commit 保留。流水线第一版已经通过 Icarus 的 Test-8、AUIPC 补测、Test-37，以及 `board/top.v` 端口级编译检查；实板测试中发现直接使用 `clkdiv[x]` 驱动 CPU 会因未走全局时钟网络产生不稳定现象，已改为 `clkdiv[0] -> BUFG -> Clk_CPU`，当前 50 MHz 下 `testac.coe` 可进入成功动画。

当前 `feature/ps2-keyboard` 分支在已提交的单级中断/异常版本基础上接入 PS/2 键盘。老师提供的 PS2 文件已整理到 `IO/PS2/`；板级系统改用自写 `IO/MIO_BUS.v`，新增 `0xD0000000`/`0xD0000004` 键盘 MMIO 地址，同时保留原 RAM、数码管和 LED 地址行为。

当前 `dino` 分支（从 VGA 里程碑切出）实现 90–100 分阶段的 VGA 恐龙游戏：
软件编程老师 `Counter_x` 产生周期计时中断驱动游戏帧（见 4.5.1），游戏本体
为 C + 汇编启动代码（见 4.5.2、`game/`），实板验收步骤见 7.8。

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
    "IO/PS2/*.v",
    "editor/*.v",
    "edf/SPIO.v",
    "edf/Multi_8CH32.v",
    "edf/SSeg7.v",
    "sim/*.v"
  ],
  "build": "board_own_files.f"
}
```

`indexGlobs` 是旧字段，但 native `slang-server 0.2.7` 仍支持，且当前项目实测最稳定。使用它的原因是：

- 当前 `MIO_BUS` 已改为自写 `IO/MIO_BUS.v`，用于加入 PS/2 键盘 MMIO；不要再把 `edf/MIO_BUS.V` 加回 `board_own_files.f`。
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
7. 在 `board/top.v` 中对 `SCPU`、`clk_div`、`MIO_BUS`、`PS2IO` 右键 Go to Definition。当前已验证应分别跳到 `rtl/SCPU.v`、`IO/clk_div.v`、`IO/MIO_BUS.v`、`IO/PS2/PS2IO.v`。

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

注意：Test-37 末尾不是停机程序。它在 `jalr` 返回后会短暂写出 `dmem[0] <= 0x000007b2`，随后自然落入 `F_Test_JAL` 并继续循环覆盖 `dmem[0]`。单周期旧检查可以卡在固定 PC 点；流水线版本不能依赖固定 PC，当前 testbench 按第一次写出 `0x000007b2` 的事件判定通过。

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

### 4.4 板级 top 动态仿真：从 COE 观察数码管显示

如果目标是观察 `board/top.v` 级别的显示输出，而不是只跑 CPU 自检，使用专用脚本：

```bash
python3 sim/run_top_board_sim.py \
  --imem coe/board/I_testac.coe \
  --dmem coe/board/D_mem.coe \
  --sw 0000 \
  --max-cycles 4200000
```

脚本会自动完成：

1. 将 `.coe` 的 `memory_initialization_vector` 转成 `build/top_imem.dat` / `build/top_dmem.dat`。
2. 用 `top_board_sim_files.f` 编译 `board/top.v` 级仿真。
3. 运行 `sim/top_board_tb.v`，打印程序写显示 MMIO 和当前 `Disp_num`。
4. 如指定 `--dump-vcd`，生成波形 `build/top_board_tb.vcd`。

输出中重点看两类行：

```text
[TOP_SIM] cycle=33 pc=00000268 display_write=00111100
[TOP_SIM] cycle=35 pc=0000026c sevenseg_hex=00111100 an=fb seg=f9
```

- `display_write`：CPU 写入显示 MMIO 地址 `0xE0000000` 的 32 位值，是判断“数码管理论显示内容”的最可靠事件。
- `sevenseg_hex`：当前 `Multi_8CH32` 送入 `SSeg7` 的 8 位十六进制显示值。`--sw 0000` 表示 `SW[7:5]=000`，选择程序输出通道 `data0`。
- `an` / `seg`：动态扫描数码管的即时段选/位选信号，适合在 GTKWave 中看波形，不适合直接肉眼读完整八位数。

例如 `I_testac.coe` 当前 top 仿真可看到：

```text
00111100
00222200
00333300
00444400
00555500
00666600
ffffffff
ffefffff
```

这说明六个阶段标记已通过 top 级数据通路写到显示外设，并进入成功动画。`ffffffff` 是动画第一帧，下一帧 `ffefffff` 大约要等到 cycle 3886493；这是测试程序里的软件延时，不是 CPU 卡死。完整动画每帧间隔较长，top 仿真通常只看前几帧即可，实板观察为最终准则。

默认不 dump VCD，文本输出速度更快；需要波形时追加：

```bash
python3 sim/run_top_board_sim.py \
  --imem coe/board/I_testac.coe \
  --dmem coe/board/D_mem.coe \
  --sw 0000 \
  --max-cycles 4200000 \
  --dump-vcd
```

top 仿真中的 `MIO_BUS`、`RAM_B`、`Multi_8CH32`、`SSeg7` 是 `sim/board_sim_models.v` 提供的行为模型，不是老师 EDF/IP 的逐门级模型。

普通板级 IO 程序也可以这样跑：

```bash
python3 sim/run_top_board_sim.py \
  --imem coe/board/I_mem.coe \
  --dmem coe/board/D_mem.coe \
  --sw 0000 \
  --max-cycles 200000
```

查看 top 级波形：

```bash
open -a GTKWave build/top_board_tb.vcd
```

### 4.5 单级中断/异常 top 仿真

当前 `feature/interrupt-exception` 分支实现了单级中断/异常：

- 非法指令异常，向量入口 `0x00000300`；
- `ECALL/SYSCALL`，向量入口 `0x00000320`；
- 计时中断，向量入口 `0x00000340`；
- `ERET = 32'h00100073` 返回 `SEPC`；
- `ERETN = 32'h00200073` 返回 `SEPC + 4`。

`INTMASK` 复位为 0，普通程序默认不会响应计时中断。软件向 `0xFFFF_FF00` 写入 `0x40` 后允许计时中断；写 `INTMASK` 时会清空 pending。

中断/异常测试程序：

```text
coe/board/I_trap_test.coe
```

运行 top 级仿真：

```bash
python3 sim/run_top_board_sim.py \
  --imem coe/board/I_trap_test.coe \
  --sw 0000 \
  --max-cycles 2000 \
  --force-int-start 80 \
  --force-int-end 90
```

预期关键输出：

```text
display_write=11110000  # 主程序开始
display_write=e0000002  # ECALL/SYSCALL handler
display_write=22220000  # ECALL 返回后继续
display_write=e0000001  # 非法指令 handler
display_write=33330000  # 非法指令返回后继续
display_write=e0000006  # 计时中断 handler
display_write=44440000  # 中断返回后继续
```

`--force-int-start/end` 只用于 top 仿真中稳定地产生一次计时中断脉冲；真实上板时应通过计数器外设产生 `SCPU.INT`。

注意：不要并行运行两个 `sim/run_top_board_sim.py`，默认都会编译到 `build/top_board_simv`，并行写同一个 vvp 文件会导致 `unresolved label` 等无效错误。

上板快速验证 exception 主路径时，优先使用不依赖 timer interrupt 的版本：

```text
coe/board/I_exception_board_smoke.coe
```

该程序只测试 `ECALL/SYSCALL`、非法指令、`ERETN` 返回，不依赖 `Counter_x` 产生中断。top 仿真命令：

```bash
python3 sim/run_top_board_sim.py \
  --imem coe/board/I_exception_board_smoke.coe \
  --sw 0000 \
  --max-cycles 1000
```

预期关键输出：

```text
display_write=11110000
display_write=e0000002
display_write=22220000
display_write=e0000001
display_write=33330000
```

上板时设置 `SW[7:5]=000`，复位释放后最终应停在：

```text
33330000
```

如果只能看到最终值而看不到中间值，也正常；这些阶段写入之间间隔很短。

### 4.5.1 软件编程 Counter_x 计时中断 top 仿真

`dino` 分支起，软件可以直接把老师 `Counter_x` 编程为周期中断源，不再依赖
`--force-int-*`：

- `sw 0xF0000000`：低 2 位经老师 SPIO 锁存为 Counter_x 通道选择（0..2 计数值，3 控制字）；
- `sw 0xF0000004`：把数据写入当前选中通道（自写 `IO/MIO_BUS.v` 新增的 `counter_we` 译码）；
- 通道 0 控制字 `bit[2:1]=01` 为周期模式：减到 0 输出一拍脉冲并自动重装；
- 通道 0 时钟为 `clkdiv[6]`（100 MHz / 128 = 781.25 kHz），计数值 N 时中断周期 = N × 1.28 µs；
- CPU 侧对 `INT` 上升沿置 pending：一个脉冲恰好触发一次中断，不会在 ERET 后重复触发。

冒烟程序源码 `asm2coe/timer_smoke.S`，构建命令（Homebrew 工具链）：

```bash
cd asm2coe && make PREFIX=riscv64-elf- TARGET=timer_smoke
cp timer_smoke.coe ../coe/board/I_timer_smoke.coe
```

top 仿真命令：

```bash
python3 sim/run_top_board_sim.py \
  --imem coe/board/I_timer_smoke.coe \
  --sw 0000 \
  --max-cycles 60000 \
  --check-timer-int
```

预期输出：`display_write` 依次为 1、2、3，其中第 1 次来自计数器复位后的
首次下溢沿，第 2、3 次间隔约 6660 周期（编程值 50 拍）。测试台要求相邻
tick 至少间隔 1000 周期，同一脉冲重复触发（中断风暴）会被判 FAIL：

```text
[TOP_SIM][PASS] timer interrupt fired 3 times with periodic spacing
```

注意：top 仿真现在直接编译 `IO/MIO_BUS.v` 真实译码（`top_board_sim_files.f`），
`sim/board_sim_models.v` 里原来的 MIO_BUS 行为副本已删除。

### 4.5.2 VGA 恐龙游戏构建与 top 仿真

游戏源码在 `game/`：`game.c`（游戏逻辑，C）+ `start.S`（复位入口、中断向量、
计时中断 ISR）+ `linker.ld`。构建（Homebrew 工具链）：

```bash
cd game && make PREFIX=riscv64-elf- install
```

`install` 生成并复制 `coe/board/I_dino.coe`（指令 ROM）和 `coe/board/D_dino.coe`
（数据 RAM；C 的字符串等常量放这里，因为哈佛结构下 lw 读不到指令 ROM）。
Makefile 自带 4KB 尺寸检查，超限报 `SIZE OVERFLOW`。

top 仿真（`SW[14]=1` 选仿真快频，40 拍/帧）：

```bash
python3 sim/run_top_board_sim.py \
  --imem coe/board/I_dino.coe \
  --dmem coe/board/D_dino.coe \
  --sw 4000 \
  --max-cycles 60000 \
  --dump-vga-text-at 55000
```

`--dump-vga-text-at N` 在第 N 周期把 80x60 文本显存打印成 ASCII 画面。
预期：`display_write` 每帧递增（tick 心跳），画面有标题、SCORE、地面和恐龙。

玩法与实现要点：

- 恐龙固定在第 8 列，站立占 38/39 两行；仙人掌 `#`（高 1 或 2，LFSR 随机）
  每帧左移一列，移出左边界 +1 分；
- 任一按钮按下沿或 PS/2 空格（通码 0x29，自动跳过 F0 断码）触发固定弧线
  跳跃（14 帧，最高离地 6 行）；同列且离地高度小于仙人掌高度判定相撞；
- 相撞显示 GAME OVER，再按一次跳跃键重新开始；
- 渲染是增量式的：每帧只擦/画变化的格子，不整屏重画（整屏重画会让移动
  物体闪烁）。

gameplay 定向仿真（时机数值针对 `SW=4000` 快频与固定 LFSR 种子）：

```bash
# 不按键：仙人掌撞上恐龙，预期画面出现 GAME OVER / PRESS JUMP TO RESTART
python3 sim/run_top_board_sim.py --imem coe/board/I_dino.coe --dmem coe/board/D_dino.coe \
  --sw 4000 --max-cycles 1550000 --dump-vga-text-at 1500000

# PS/2 空格定时起跳：跳过第一个仙人掌，预期 SCORE 00001
python3 sim/run_top_board_sim.py --imem coe/board/I_dino.coe --dmem coe/board/D_dino.coe \
  --sw 4000 --max-cycles 1550000 --send-ps2-key 29 --send-ps2-at 1180000 \
  --dump-vga-text-at 1500000

# 按钮定时起跳：同上，走 BTN 输入路径
python3 sim/run_top_board_sim.py --imem coe/board/I_dino.coe --dmem coe/board/D_dino.coe \
  --sw 4000 --max-cycles 1550000 --press-btn-at 1250000 --dump-vga-text-at 1500000

# GAME OVER 后按键重开：预期画面回到初始状态、SCORE 归零
python3 sim/run_top_board_sim.py --imem coe/board/I_dino.coe --dmem coe/board/D_dino.coe \
  --sw 4000 --max-cycles 1700000 --send-ps2-key 29 --send-ps2-at 1450000 \
  --dump-vga-text-at 1650000
```

### 4.6 PS/2 键盘 MMIO top 仿真

当前 `feature/ps2-keyboard` 分支已接入老师提供的 PS/2 接口文件，并整理为：

```text
IO/PS2/PS2KB.v
IO/PS2/PS2IO.v
```

板级顶层新增端口：

```verilog
inout ps2_clk,
inout ps2_data
```

地址映射由自写 `IO/MIO_BUS.v` 实现：

```text
0xD0000000  读 {23'b0, ps2_ready, ps2_key}
0xD0000004  读最近 4 个扫描码拼成的 ps2_scancode
0xE0000000  写数码管显示 MMIO，读 BTN/SW
0xF0000000  写 LED/SPIO，读 LED 状态
```

PS/2 smoke 测试程序：

```text
coe/board/I_ps2_mmio_smoke.coe
```

该程序轮询 `0xD0000000` 的 ready 位，读到键值后写到 `0xE0000000`。仿真命令：

```bash
python3 sim/run_top_board_sim.py \
  --imem coe/board/I_ps2_mmio_smoke.coe \
  --sw 0000 \
  --max-cycles 100000 \
  --send-ps2-key 1c
```

预期关键输出：

```text
[TOP_SIM] send PS2 scan code=1c
display_write=0000011c
```

含义：仿真 testbench 通过 PS/2 串行时序发送扫描码 `0x1c`，CPU 从 `0xD0000000` 读到 `{ready=1,key=0x1c}`，然后显示 `0000011c`。
程序最后会停在自循环中，后续出现 `[TOP_SIM][TIMEOUT] ... display=0000011c` 是预期现象；判断是否通过看前面是否出现 `display_write=0000011c`。

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
- `if_id_valid`、`if_id_pc`、`if_id_inst`
- `id_ex_valid`、`id_ex_pc`、`id_ex_rs1_data`、`id_ex_rs2_data`、`id_ex_imm`
- `ex_mem_valid`、`ex_mem_alu_result`、`ex_mem_store_data`
- `mem_wb_valid`、`mem_wb_rd`、`wb_data`、`wb_reg_write`
- `stall_load_use`、`forward_a_sel`、`forward_b_sel`
- `ex_redirect`、`ex_redirect_pc`
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
IO/MIO_BUS.v
IO/PS2/PS2KB.v
IO/PS2/PS2IO.v
edf/SCPU.edf
rtl/dm_controller.v
edf/SPIO.edf
edf/Multi_8CH32.edf
edf/SSeg7.edf
```

`edf/*.v` 是网表接口 stub，主要供编辑器和接口检查使用。若 Vivado 已能从 EDF 正确识别端口，不必再把 stub 加入综合；不要添加 `rtl/SCPU.v`，否则会与老师的 `SCPU.edf` 重名。不要添加 `edf/MIO_BUS.edf`，当前为了 PS/2 键盘地址映射已改用自写 `IO/MIO_BUS.v`。不要添加 `edf/dm_controller.edf` 或 `edf/dm_controller.v`，当前 RAM 字节写使能和读数据扩展由自研 `rtl/dm_controller.v` 实现。也不要添加 `sim/sccomp_tb.v`。

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

- CPU 固定使用 `clkdiv[0]` 经 `BUFG` 后的 `Clk_CPU`，频率为 50 MHz。
- `SW[2]` 端口当前保留给 `clk_div` 接口兼容，但流水线阶段不再用它运行时切换快/慢 CPU 时钟。
- 原先直接 `assign Clk_CPU = clkdiv[x]` 或 `SW[2] ? clkdiv[a] : clkdiv[b]` 的写法可能让 CPU 时钟走普通 routing 或普通 LUT mux。该写法曾出现 `clkdiv[1]`、`clkdiv[2]`、`clkdiv[3]` 表现不一致，以及 mux 组合变化导致 `FA123456` 等不稳定现象。修正方法是显式实例化 `BUFG`，让 CPU 时钟走 FPGA 全局时钟网络。
- `SW[7:5]`：选择数码管显示源，依次为外设输入、`PC[31:2]`、当前指令、计数器、CPU 地址、CPU 写数据、CPU 读数据、PC。
- `SW[4:3]`：由当前 `coe/board/board_io_demo_instr.coe` 中的 IO 演示程序读取并决定显示效果；已观察到跑马灯、0~F 数据显示、寄存器递增等模式符合参考要求。
- `SW[0]`：传入 `SSeg7` 的文本/图形显示选择。此前矩形/图形变化显示异常已确认来自老师测试/图形编码问题，不作为 CPU 或顶层实现错误。

当前实现是自动运行，不是按钮按一下执行一步。按钮单步等后续需要时再增加。

### 7.5 XDC、综合与下载

1. 将 `constraints/icf.xdc` 添加为 Constraints Source。当前 XDC 已包含 `ps2_clk`、`ps2_data` 端口约束；如果暂时不接键盘，也可以保留这两个端口和约束，不影响原测试程序运行。
2. 检查 `clk` 的周期约束为 10 ns；不要把约束改成 CPU 分频后的周期。
3. 依次执行 **Run Synthesis → Run Implementation → Report Timing Summary**。
4. 确认没有 unconstrained top-level port、unresolved black box、关键 DRC 或负的 setup slack 后，再执行 **Generate Bitstream**。
5. 在 Hardware Manager 中 **Open Target → Auto Connect → Program Device**。
6. 复位后观察数码管输出；当前 CPU 时钟固定为 50 MHz，`SW[2]` 不再用于切换 CPU 快慢。

当前 `feature/vga-redesign` 分支重新实现了 VGA 文本显示输出。Vivado Design Sources 需要额外加入：

```text
IO/VGA/vga_timing.v
IO/VGA/vga_font_rom.v
IO/VGA/vga_text_ram.v
IO/VGA/vga_text_renderer.v
IO/VGA/vga_top.v
```

顶层新增端口：

```text
VGA_R[3:0]
VGA_G[3:0]
VGA_B[3:0]
VGA_HS
VGA_VS
```

不要把 `docs/reference/vga/*.v` 加入 Vivado Design Sources；那里只保存老师原始参考文件。当前 active 编译路径使用 `IO/VGA/` 下按职责拆分后的重新实现版本。

同时把下面这个字库初始化文件加入 Vivado 工程，或至少保证综合运行目录能找到它：

```text
coe/vga/font_ascii_8_8.mem
```

`constraints/icf.xdc` 已按 `docs/reference/xdc/Nexys-A7-100T-Master.xdc` 增加这些管脚约束。

VGA 有两个测试模式：

1. `SW[15]=1`：强制绿色全屏测试画面。这个模式不依赖 CPU 写显存，优先用于确认线缆、显示器输入源、管脚约束和 HS/VS 同步。
2. `SW[15]=0`：显示 CPU 可写文本显存。复位后默认左上角应显示 `SCPU VGA READY`；后续程序可以写 `0xC0000000` 地址段输出字符。

VGA 文本显存地址约定：

```text
base = 0xC0000000
addr = base + (row * 80 + col) * 4
data[15:8] = 颜色属性；高半字节 7/A/B/C/E/F 分别为暗灰/绿/青/红/黄/白，其他值回退为同亮度灰色
data[7:0]  = ASCII 字符码
```

例子：

```text
向 0xC0000000 写 0x0000ff41  # 左上角显示白色 A
向 0xC0000004 写 0x0000ff42  # 第 2 个字符显示白色 B
```

当前只保证 8x8 ASCII 文本模式，80 列 × 60 行。`Hzk16.coe` 暂不进入 active 编译路径，复杂中文显示不是当前门禁。

VGA 使用 `vga_timing` 在 100 MHz 主时钟下生成 4 分频 clock-enable，等效 25 MHz 像素节拍；没有把分频计数器输出作为新的派生时钟。若后续遇到显示器兼容性或时序问题，再考虑用 MMCM/Clocking Wizard 生成标准 25.175 MHz 像素时钟。

VGA 相关 top 级仿真：

```bash
# 绿屏测试路径：验证 VGA 同步/RGB 输出
python3 sim/run_top_board_sim.py \
  --imem coe/board/I_mem.coe \
  --dmem coe/board/D_mem.coe \
  --sw 8000 \
  --max-cycles 200000 \
  --check-vga

# CPU 写文本显存路径：验证 0xC0000000 MMIO
python3 sim/run_top_board_sim.py \
  --imem coe/board/I_vga_text_smoke.coe \
  --sw 0000 \
  --max-cycles 200 \
  --check-vga-text
```

预期分别看到：

```text
[TOP_SIM][PASS] VGA green test active
[TOP_SIM][PASS] VGA text MMIO wrote OK into cells 0 and 1
```

如果要在开发板上专门验证 CPU 写 VGA 文本显存，把 `ROM_D` 的 COE 换成：

```text
coe/board/I_vga_text_smoke.coe
```

下载后设置：

```text
SW[15] = 0
rstn 复位后释放
```

预期 VGA 左上角显示白色 `OK`。该程序只用于 VGA smoke，不代表应用程序。

当前顶层没有独立的 PASS 灯或自动停机逻辑。`coe/board/board_io_demo_instr.coe`/`coe/board/board_io_demo_data.coe` 当前是老师板级 IO 演示程序和数据，不是 Icarus 仿真使用的 `sim/data/Test_37_Instr8.dat`。因此本阶段的实板结果用于确认 CPU 与板级 IO 外围可运行；课程 Test-37 的指令正确性仍以 Icarus 自检为主要证据。如需 Test-37 实板验收，应另行导入 Test-37 对应 COE。

已完成的实板观察：

- Vivado bitstream 生成成功，Program Device 成功。
- 使用老师 `edf/SCPU.edf`、`coe/board/board_io_demo_instr.coe`、`coe/board/board_io_demo_data.coe` 时，跑马灯、0~F 数据显示、寄存器递增等参考功能符合要求。
- 替换为自己的 `rtl/SCPU.v` 后，重新生成 bitstream 并 Program Device，参考 IO 测试现象仍符合要求。
- 使用自己的 `rtl/SCPU.v` 和 `coe/board/testac.coe` 后，实板验收通过：`SW[7:5]=000` 观察 MMIO data0，流水线 CPU 使用 `clkdiv[0] -> BUFG` 的 50 MHz 时钟，复位释放后程序经过六个阶段标记并进入 `88C6` 成功动画。老师 `edf/SCPU.edf` 在该测试中会停在 `FA123456`，该现象记录为参考 EDF 与当前测试不匹配，不作为自研 CPU 错误。
- 老师给的矩形/图形变化测试代码或图形编码存在问题，疑似共阳极/共阴极硬编码混淆；该问题不影响 CPU、顶层或自研 `dm_controller` 的正确性判断。

### 7.6 testac.coe 实板验收程序

`coe/board/testac.coe` 是当前单周期下板验收程序，共 670 条指令，导入 Vivado `ROM_D` 使用。配套执行轨迹保存在 `coe/board/testac模拟.txt`，当前前 1000 条执行轨迹与 COE 指令索引逐条对齐。反汇编保存在 `docs/disasm/testac.disasm.md`。

运行设置：

```text
SW[7:5] = 000    # 数码管显示 Multi_8CH32 的 data0，即 MMIO 显示数据
SW[2]   = 任意   # 当前流水线时钟固定为 clkdiv[0] 经 BUFG 后的 50 MHz
SW[0]   = 0      # 文本/十六进制显示
```

复位并释放后，程序会快速经过六个阶段标记：

```text
00111100
00222200
00333300
00444400
00555500
00666600
```

这些值不是人工猜测，而是程序显式写入 `0xE0000000` 显示 MMIO。例如第一阶段在反汇编中为：

```asm
00000250:  e0000737    lui  a4,0xe0000
00000254:  001117b7    lui  a5,0x111
00000258:  10078793    addi a5,a5,256
0000025c:  00f72023    sw   a5,0(a4)       # 写 0x00111100 到 0xE0000000
```

第二阶段同理写 `0x00222200`：

```asm
000002e4:  e0000737    lui  a4,0xe0000
000002e8:  002227b7    lui  a5,0x222
000002ec:  20078793    addi a5,a5,512
000002f0:  00f72023    sw   a5,0(a4)       # 写 0x00222200 到 0xE0000000
```

全通过后程序不会停机，而是进入无限成功动画。完整帧会移动 `88C6` 图案，常见帧包括：

```text
FF88C6FF
FFFF88C6
C6FFFF88
88C6FFFF
```

失败时程序会冻结在固定错误码，并在内部把 PC 锁在 `0x218` 的死循环处。错误处理逻辑位于 `0x204`：

```asm
00000204:  f0000737    lui  a4,0xf0000
00000208:  00402783    lw   a5,4(zero)
0000020c:  00e7e7b3    or   a5,a5,a4
00000210:  e0000737    lui  a4,0xe0000
00000214:  00f72023    sw   a5,0(a4)       # 显示 0xF0000000 | RAM[4]
00000218:  0000006f    j    .
```

程序用 RAM[4] 保存阶段进度；因此错误码含义如下：

```text
FAAAAAA1  Test 1 失败
FAAAAA12  Test 2 失败
FAAAA123  Test 3 失败
FAAA1234  Test 4 失败
FAA12345  Test 5 失败
FA123456  Test 6 失败
```

Test 6 的关键判断位于 `0xA50` 到 `0xA74`：输入 `a0=0x12345678`，调用 `0x938` 后期望 `a0=0x7c223fb2`。若不相等则跳到错误处理，显示 `FA123456`。

### 7.7 后续替换为自己的 CPU

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
IO/MIO_BUS.v
IO/PS2/PS2KB.v
IO/PS2/PS2IO.v
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

### 7.8 恐龙游戏实板验收（dino 分支）

`dino` 分支相对上一次板级基线没有增删 Verilog 文件，Vivado 工程源文件集
不变，但以下三个文件内容有改动，工程里必须是最新版本：

```text
IO/MIO_BUS.v   # 新增 0xF0000004 counter_we 译码
rtl/SCPU.v     # INT 改上升沿置 pending
board/top.v    # vga_text_ram 写时钟改 Clk_CPU
```

操作步骤：

1. 同步以上三个文件到 Vivado 工程（其余源文件、XDC 不变）。
2. `ROM_D` 的 COE 换成 `coe/board/I_dino.coe`，重新生成 IP。
3. `RAM_B` 的 COE 换成 `coe/board/D_dino.coe`（游戏的常量数据放在数据
   RAM；不换这个 COE 屏幕上标题/提示文字会是乱码）。
4. 综合、实现、生成 bitstream，Program Device（或 macOS 侧
   `openFPGALoader -b nexys_a7_100 top.bit`）。

开关设置：

```text
SW[15] = 0   # 显示文本显存（=1 是绿屏排错）
SW[14] = 0   # 板上 30 Hz 帧率（=1 是仿真快频，板上会快到没法玩）
SW[7:5] = 000  # 数码管显示游戏帧号心跳
```

预期现象：

- 复位后屏幕显示 `DINO GAME`、`SCORE 00000`、地面线和恐龙 `D`；
- 数码管持续递增（计时中断心跳）；仙人掌 `#` 从右向左移动；
- 按任意按钮或 PS/2 空格起跳；跳过仙人掌 SCORE +1；
- 撞上仙人掌显示 `GAME OVER` / `PRESS JUMP TO RESTART`，再按跳跃键重开。

若画面不动但数码管在增长，优先检查 `RAM_B` 是否用了 `D_dino.coe`；
若数码管也不动，说明计时中断没起来，检查 `IO/MIO_BUS.v` 和 `rtl/SCPU.v`
是否为 dino 分支版本。

## 8. 从汇编生成 COE

### 8.1 构建 Dinosaur 游戏

游戏位于 `game/`。Makefile 优先使用 `riscv64-elf-gcc`，本机未安装时自动
使用 Homebrew LLVM + LLD：

```bash
cd game
make clean
make toolchain-info
make
make install-coe
```

`make` 会验证 RV32I 属性、禁止 M 扩展、无未解析符号以及 1024-word ROM
容量。`make install-coe` 更新 `coe/board/I_dino_game.coe`。当前完整玩法版本为
869/1024 words：包含自定义恐龙/仙人掌/飞鸟像素字模、站立与下蹲碰撞盒、
READY/RUNNING/PAUSED/GAME OVER 状态和局部重绘。操作键为 Space/W/↑ 跳跃、
S/↓ 下蹲、P 暂停、R/Enter 回到 READY；空中按住下蹲会加速落地。
Vivado 的 `ROM_D` 需要重新选择更新后的 COE 后重新生成 IP。

帧节拍不再由 C 忙等延时决定。`IO/game_timer.v` 复位后默认关闭，游戏向
`0xFFFFFE00` 写 1 后，在 50 MHz CPU 时钟下产生 25 Hz 单周期 IRQ；软件再向
`0xFFFFFF00` 写 `0x40` 打开 CPU 定时中断。固定向量 `0x340` 的汇编 ISR 保存/
恢复全部整数寄存器，只累加 `frame_ticks`，物理、键盘和 VGA 写入仍在主循环。
旧 `Counter_x` 只有在软件实际配置通道 0 后才允许接入 CPU，避免其上电下溢
形成持续高电平中断。

已有 Vivado 工程升级到这个游戏版本时，必须先确认 CPU。中断版不能继续使用
`edf/SCPU.edf`：它与当前软件没有共同验证过 `0x340` 定时向量、课程 ERET 编码
和 `0xFFFFFF00` 中断掩码。应禁用或移除 `edf/SCPU.edf`，并加入：

```text
rtl/SCPU.v
rtl/ctrl.v
rtl/alu.v
rtl/EXT.v
rtl/NPC.v
rtl/PC.v
rtl/RF.v
rtl/forward_unit.v
rtl/hazard_unit.v
rtl/exception_unit.v
rtl/dm_controller.v
```

`rtl/ctrl_encode_def.v` 是这些 RTL 的 include 文件，需保证 `rtl/` 位于 include
搜索路径。不得让 `edf/SCPU.edf` 与 `rtl/SCPU.v` 同时存在，否则会发生同名模块
冲突或错误绑定。然后替换以下现有文件：

```text
board/top.v
IO/VGA/vga_text_renderer.v
IO/VGA/vga_font_rom.v
```

并新增：

```text
IO/game_timer.v
```

最后把指令 ROM 初始化文件更新为：

```text
coe/board/I_dino_game.coe
```

`game/*.c`、`game/*.S`、`game/linker.ld`、`sim/*` 和仓库根目录的 `*.f` 是构建/
仿真输入，不加入 Vivado Design Sources。`IO/VGA/vga_text_ram.v` 本轮只有注释
更新，已有工程无需因此替换；`IO/MIO_BUS.v` 和 PS/2 RTL 本轮没有功能改动。
CPU RTL 即使仓库内容没有新改动，也必须按上面的列表替换老师 EDF，这是中断版
的运行前提。更新 COE 后应在 `ROM_D` 的 IP 配置中重新选择该文件并重新生成
Output Products，再重新综合、实现和生成 bitstream。

若实板能看见恐龙/仙人掌，但背景文字随机乱码和闪烁，必须使用最新版
`board/top.v`。VGA 文本 RAM 的 CPU 写时钟应为 `Clk_CPU`：CPU 总线在下降沿
更新，显存在下一上升沿写入，具有半周期建立时间。旧连接使用 `~Clk_CPU`，与
总线更新处于同一边沿，在 RTL 仿真中可能正常，但实板会随机写坏显存。

对应的本地门禁为：

```bash
cc -std=c11 -Wall -Wextra -Werror sim/game_logic_test.c -o build/game_logic_test
build/game_logic_test
iverilog -g2012 -Wall -s vga_text_renderer_tb -o build/vga_text_renderer_tb \
  sim/vga_text_renderer_tb.v IO/VGA/vga_font_rom.v IO/VGA/vga_text_renderer.v
vvp -n build/vga_text_renderer_tb
python3 sim/run_top_board_sim.py --imem game/build/game.coe \
  --max-cycles 300000 --check-dino-ready
iverilog -g2012 -Wall -s game_timer_tb -o build/game_timer_tb \
  sim/game_timer_tb.v IO/game_timer.v
vvp -n build/game_timer_tb
python3 sim/run_top_board_sim.py --imem game/build/game.coe \
  --max-cycles 4300000 --send-ps2-key 29 --check-dino-tick
```

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
│   ├── testac.coe                # 当前单周期实板验收程序，670 条指令
│   └── testac模拟.txt            # testac 的执行轨迹说明，前 1000 条与 COE 对齐
├── docs/disasm/
│   └── testac.disasm.md          # testac.coe 反汇编，用于查阶段标记和失败处理
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
