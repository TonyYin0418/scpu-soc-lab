# SCPU_SOC 项目协作说明

## 总体目标

本项目不是只完成一个单周期 CPU，而是以课程评分层次为路线，逐步演进为可运行应用、可处理中断/异常，并具备进一步体系结构或 SoC 扩展能力的 RV32I CPU。当前单周期设计只是第一阶段基线，后续工作不得把“仿真通过”误写成项目最终完成。

代码以可综合 RTL 为主体。每个阶段都必须同时具备可重复仿真、自检测试、综合/时序证据和开发板运行结果；新阶段不得破坏已经通过的低阶段功能。

## 分层目标与验收门禁

### 60–70 分：37 条指令单周期 CPU 下板

- 实现课程规定的 37 条 RV32I 指令。
- Test-8、Test-37 和 AUIPC 补测全部通过。
- 完成指令 ROM 初始化、老师板级外设系统、复位、快慢时钟选择和数码管/LED 显示；后续再根据性能要求优化全速频率。
- Vivado 综合、实现和时序检查通过，生成 bitstream。
- 在开发板上运行测试程序并能观察 PASS 或规定的最终结果。

只有仿真通过但尚未下板，不算完成本阶段。

### 70–80 分：37 条指令冒险流水线 CPU 下板

- 在保留单周期基线的前提下实现流水线 CPU，建议采用 IF、ID、EX、MEM、WB 五级结构。
- 正确处理数据冒险和控制冒险，包括旁路/转发、load-use 暂停、分支/跳转冲刷；结构冒险必须通过资源设计或暂停机制解决。
- 37 条指令的架构可见结果必须与单周期 CPU 一致。
- 增加针对相关指令连续执行、load-use、分支 taken/not-taken、JAL/JALR 的流水线定向测试。
- 通过完整仿真回归、综合、时序检查，并在开发板上成功运行测试程序。

### 80–85 分：流水线 CPU 应用与显示

- 在冒险流水线 CPU 上实现一个可演示应用。
- 应用程序必须实际包含并执行已实现的 37 条指令，不能只把未执行指令放在代码中凑数。
- 增加与应用匹配的板级输入、输出和显示逻辑，并给出可重复的演示流程。
- 应用选择尚未确定，不得在没有用户确认时固定方案。

### 85–90 分：三种单级中断/异常

- 在流水线 CPU 上实现异常指令处理。
- 实现计时中断（timer interrupt）。
- 实现系统调用 SYSCALL；在 RISC-V 指令层面通常对应 ECALL，最终编码和行为以课程要求为准。
- 建立单级 trap 入口、原因记录、异常 PC 保存和返回机制，并保证流水线中的异常具有明确、可验证的提交边界。
- 为每种中断/异常分别提供定向测试和开发板演示。

### 90–100 分：复杂应用或高级体系结构扩展

最终方向暂不确定，候选包括但不限于：

1. 支持键盘操作和图形界面的游戏。
2. L1 I-Cache/D-Cache 子系统、替换策略及 CPU 主频评估。
3. 双发射处理器。
4. 双核处理器。
5. 网口驱动。
6. 移植 FreeRTOS 或 RT-Thread。
7. 其他经确认的复杂应用或架构扩展。

选择本阶段方向前，需要比较工作量、现有板卡资源、验证难度、演示效果和剩余时间，不得提前把某一候选写成既定方案。

## 当前进度

- 已完成：37 条指令单周期 RTL、中文注释、Test-8、课程 Test-37、AUIPC 补测和 Icarus 自检。
- 已完成板级接口基线：整理老师提供的 EDF/IO/汇编工具，按 `docs/schematic.pdf` 创建 `board/top.v`，并用黑盒接口完成 Icarus 端口级编译检查。
- 已完成老师 EDF 板级外壳实板基线：在 Vivado 中使用老师提供的 `edf/SCPU.edf`、外围 EDF、`coe/board/board_io_demo_instr.coe` 和 `coe/board/board_io_demo_data.coe` 生成 bitstream 并 Program Device，板上跑马灯、0~F 显示、寄存器递增等参考功能符合要求。
- 已完成自研单周期 CPU 板级替换验证：在 Vivado 中禁用老师 `edf/SCPU.edf`，加入 `rtl/SCPU.v` 及其依赖后重新生成 bitstream 并 Program Device，板上参考 IO 测试现象符合要求。
- 已校正 `constraints/icf.xdc`：补齐 5 个按钮，删除临时开关时钟网约束，并将板载 100 MHz 时钟周期修正为 10 ns。
- 已确认此前矩形/图形变化显示异常不是 CPU、顶层、RAM/ROM 或 `SSeg7` 接口问题，而是老师给的矩形变换测试/图形编码本身有误，疑似共阳极/共阴极硬编码混淆；该现象不再作为本项目实现遗留问题。
- 已在 `feature/own-scpu-board` 分支完成自研单周期 CPU 的板级接口兼容：`rtl/SCPU.v` 端口对齐老师 `edf/SCPU.v`，`rtl/sccomp.v` 已适配新接口，并新增 `board_own_files.f` 用于 `board/top.v` + 自研 CPU 的 Icarus 端口级检查。
- 当前兼容验证：Test-8、AUIPC 补测、课程 Test-37 均通过；`iverilog -g2012 -Wall -s top -o build/top_own_check -f board_own_files.f` 通过；自研 CPU 替换老师 `SCPU.edf` 后 Vivado bitstream 和实板 IO 演示通过。
- 已完成 `testac.coe` 实板验收：`coe/board/testac.coe` 共 670 条指令，配套 `coe/board/testac模拟.txt` 前 1000 条执行轨迹与 COE 对齐；使用自研 `rtl/SCPU.v` 下板通过，数码管在 `SW[7:5]=000`、`SW[2]=0` 时进入 `88C6` 成功动画。老师提供的 `edf/SCPU.edf` 在同一测试中会停在 `FA123456`，说明该参考 EDF 对当前 `testac.coe` 不可靠，后续单周期基线以自研 `rtl/SCPU.v` 为准。
- `testac.coe` 的判定协议已记录到 `MANUAL.md`：阶段标记为 `00111100`、`00222200`、`00333300`、`00444400`、`00555500`、`00666600`；失败显示为 `FAAAAAA1` 到 `FA123456`；全通过后进入包含 `FF88C6FF`、`FFFF88C6`、`C6FFFF88`、`88C6FFFF` 的循环动画。协议来源是程序写 `0xE0000000` 显示 MMIO、用 RAM[4] 保存阶段进度，并在失败处理处显示 `0xF0000000 | RAM[4]`。
- 已进入 70–80 分阶段并创建 `feature/pipeline-cpu` 分支。当前采用方案 B：直接把 `rtl/SCPU.v` 改为五级冒险流水线版本，单周期版本通过 `main` 分支和历史 commit 保留；不再额外维护一份 `SCPU_PIPE.v`。
- 流水线第一版已实现：IF/ID/EX/MEM/WB 五级，流水线寄存器和 PC 在下降沿更新，分支/跳转在 EX 阶段决策，静态预测 PC+4，taken 时 flush IF/ID 和 ID/EX；新增 `rtl/forward_unit.v` 和 `rtl/hazard_unit.v`，支持 EX/MEM、MEM/WB 转发和 load-use 暂停。
- 当前流水线仿真状态：`iverilog -g2012 -Wall -s sccomp_tb -o build/simv -f files.f` 通过；`vvp -n build/simv`、`vvp -n build/simv +TEST_AUIPC`、`vvp -n build/simv +TEST37` 均通过；`iverilog -g2012 -Wall -s top -o build/top_own_check -f board_own_files.f` 通过。
- 流水线实板时钟问题已定位并修正：直接把 `clkdiv[x]` 或 `SW[2] ? clkdiv[a] : clkdiv[b]` 作为 CPU 时钟时，Vivado 可能让该时钟走普通 routing/LUT mux，导致不同分频位和 mux 组合表现不一致，出现 `FA123456`、全 8 等不稳定现象。当前 `IO/clk_div.v` 固定使用 `clkdiv[0]` 经 `BUFG` 输出 `Clk_CPU`，即 50 MHz；该方案经用户实板测试 `testac.coe` 可进入成功动画。
- 已在 `feature/interrupt-exception` 分支完成单级中断/异常基础实现并提交版本边界 `feat: implement single-level trap handling`：支持非法指令、ECALL/SYSCALL、timer interrupt、SEPC/SCAUSE/STATUS/INTMASK、ERET/ERETN 和 top 级 trap 测试程序。
- 当前进入 `feature/ps2-keyboard` 分支。已把用户提供的 `PS2接口` 文件整理到 `IO/PS2/`，并开始将 PS/2 键盘作为 MMIO 外设接入板级系统。

支持的指令如下：

- 寄存器运算：ADD、SUB、SLL、SRL、SRA、SLT、SLTU、AND、OR、XOR
- 立即数运算：ADDI、SLLI、SRLI、SRAI、SLTI、SLTIU、ANDI、ORI、XORI
- 高位立即数：LUI、AUIPC
- 访存：LB、LBU、LH、LHU、LW、SB、SH、SW
- 分支：BEQ、BNE、BLT、BGE、BLTU、BGEU
- 跳转：JAL、JALR

## 目录结构

```text
SCPU_SOC/
├── board/               # 板级顶层；Vivado 工程入口为 top
├── editor/              # 仅供编辑器/Icarus 检查使用的 IP stub
├── IO/                  # 老师提供的时钟、输入和计数器 RTL
├── edf/                 # 老师提供的 SCPU/外设网表及接口 stub
├── asm2coe/             # RISC-V 汇编到 COE 的转换工具
├── rtl/                 # 可综合 Verilog RTL
├── sim/
│   ├── sccomp_tb.v      # 自检 testbench
│   └── data/            # 汇编、机器码及 ROM 初始化资料
├── constraints/         # Nexys A7-100T 板级 XDC 约束
├── coe/                 # Vivado ROM/RAM 初始化文件
├── docs/                # 课程 DOCX/PDF 规格、板级原理图和反汇编记录
├── build/               # 仿真可执行文件、结果和波形等生成物
├── MANUAL.md            # 人工仿真与未来 Vivado 下板操作指南
├── files.f              # 原单周期 Icarus 仿真 filelist
├── board_files.f        # 完整板级接口检查 filelist
├── board_own_files.f    # 自研 SCPU 替换老师 SCPU 后的板级接口检查 filelist
├── board_deps.f         # 老师 SCPU.edf 阶段的 slang 依赖 filelist
├── board_own_deps.f     # 当前 VS Code/slang 依赖 filelist（不列 top，避免 duplicate）
└── .slang/server.json   # workspace 级 slang-server 配置
```

所有命令默认从项目根目录执行。不要把生成物写回 `rtl/`、`sim/` 或 `docs/`。

流水线阶段在独立分支上推进，`main` 分支保留当前单周期可运行参考。若需要回退单周期版本，切回 `main` 或检出流水线前的里程碑 commit；不要在流水线分支上手工复制旧文件覆盖，避免丢失实现历史。

## Git 与里程碑维护规则

- 项目必须使用 Git 管理；禁止把 `build/`、波形、bitstream、Vivado 临时目录等生成物提交到仓库。
- 每个可验证里程碑使用独立 commit。里程碑不得只描述“写了代码”，必须描述已经达到的可观察结果。
- 推荐提交格式：`milestone: <阶段和结果>`，例如 `milestone: establish 37-instruction single-cycle simulation baseline`。
- 当前 60–70 分阶段可以拆为仿真基线、板级接口、综合时序、实板 Test-37 等子里程碑；只有全部门禁完成后才能提交“单周期下板完成”里程碑。
- 提交前必须运行与改动相关的全部回归；涉及公共数据通路时至少运行 Test-8、Test-37 和 AUIPC 补测。
- 每个里程碑提交前必须更新本文件的“当前进度”，不能让文档状态领先于实际证据。
- 每个里程碑提交前必须更新 `MANUAL.md`，保证人工命令、路径、操作步骤和预期现象与当前工程一致。
- commit 中应同时包含实现、测试、配置和文档更新，避免留下无法复现的中间状态。
- 不修改或重写已经共享的里程碑历史；后续修正使用新 commit 记录原因和验证结果。

## 设计约束

- `x0` 必须始终为 0，任何对 `x0` 的写入都必须忽略。
- 数据存储器采用小端格式；SB/SH 只能更新目标字节通道。
- 有符号比较和算术右移必须使用 `$signed`。
- JAL/JALR 写回 `PC+4`；JALR 目标地址最低位必须清零。
- 分支立即数和跳转立即数必须在最低位补 0 后再符号扩展。
- 不允许为了通过测试而硬编码寄存器或内存结果。
- 修改模块接口后，必须同步所有例化、`files.f` 和相关测试。
- 新增或修改 RTL 时使用简洁、准确的中文注释，说明数据通路意图而不是逐行翻译代码。
- 流水线版本的架构状态必须只在有效提交点更新；暂停、冲刷和旁路控制不得产生重复提交或错误写回。
- 每个评分阶段必须保留前一阶段回归，不能用只覆盖新功能的测试替代完整回归。
- 应用、中断/异常和高级扩展必须有独立程序、预期结果和演示说明。

## 仿真与回归

编译：

```bash
mkdir -p build
iverilog -g2012 -Wall -s sccomp_tb -o build/simv -f files.f
```

运行原始 Test-8 回归：

```bash
vvp -n build/simv
```

运行课程 Test-37：

```bash
vvp -n build/simv +TEST37
```

课程提供的 Test-37 机器码实际覆盖 36 种指令，缺少 AUIPC。完整验收还必须运行：

```bash
vvp -n build/simv +TEST_AUIPC
```

通过标准：终端显示 `[通过] 所有检查均通过`，并且 `build/results.txt` 内容为 `PASS`。任何寄存器、内存或 X/Z 值不匹配都必须判为失败。

查看最后一次仿真波形：

```bash
gtkwave build/sccomp_tb.vcd
```

## 测试数据规则

- `.dat` 每行是一条 32 位十六进制机器指令，不要添加 `0x` 前缀。
- `$readmemh` 的路径按项目根目录解析。
- Test-37 有 71 条机器指令。单周期版本可用 `PC=0x110` 且 `x10=0x7b2` 作为完成点；流水线版本不要依赖固定 PC 点，应以第一次写出 `dmem[0] <= 0x000007b2` 作为通过观察点，因为程序末尾会继续落入 `F_Test_JAL` 并循环覆盖 `dmem[0]`。
- 修改测试程序后，必须重新独立推导预期寄存器和内存结果，不能用被测 RTL 生成标准答案。

## 当前阶段：单级中断/异常分支

- 当前工作分支为 `feature/interrupt-exception`，从 `main` 切出。`main` 已提交 `test: add board top simulation workflow`，包含 top 级 COE 仿真工具；中断/异常实现不要直接混入旧流水线里程碑提交。
- 本阶段不实现 8259，不实现嵌套中断；按课件实现单级中断/异常。
- 当前实现范围：
  - 非法指令异常，`SCAUSE=8'h01`，向量入口 `0x00000300`；
  - `ECALL/SYSCALL`，`SCAUSE=8'h02`，向量入口 `0x00000320`；
  - 计时中断，`SCAUSE=8'h06`，向量入口 `0x00000340`；
  - `SEPC` 保存进入 trap 时当前 EX 阶段 PC；
  - `STATUS[0]` 表示正在 trap 中；
  - `INTMASK[6]` 控制计时中断允许；
  - `ERET=32'h00100073` 返回 `SEPC`；
  - `ERETN=32'h00200073` 返回 `SEPC+4`；
  - 暂不实现 `MRET`，除非后续老师明确要求。
- `INTMASK` 复位为 0，避免普通程序被 `Counter_x`/`INT` 意外打断。软件可向 `0xFFFF_FF00` 写低 8 位更新 `INTMASK`；写入时清空 pending。
- `rtl/exception_unit.v` 是新增异常控制模块。新增 RTL 必须同步 `files.f`、`board_own_files.f`、`board_own_deps.f`、`top_board_sim_files.f`。
- `coe/board/I_trap_test.coe` 是中断/异常专用 top 仿真程序。预期输出：

```text
11110000 -> e0000002 -> 22220000 -> e0000001 -> 33330000 -> e0000006 -> 44440000
```

- top 仿真命令：

```bash
python3 sim/run_top_board_sim.py \
  --imem coe/board/I_trap_test.coe \
  --sw 0000 \
  --max-cycles 2000 \
  --force-int-start 80 \
  --force-int-end 90
```

- `--force-int-start/end` 只用于仿真强制产生一次 timer INT；上板阶段应改用计数器外设产生 `SCPU.INT`。
- 用户提供的老师 `MIO_BUS.v` 已整理为 `docs/reference/MIO_BUS_reference.v`，只作地址译码参考，不得加入任何 filelist，避免与 `edf/MIO_BUS.V` 或仿真模型重复定义。

## 当前阶段：PS/2 键盘 MMIO 外设分支

- 当前工作分支为 `feature/ps2-keyboard`。该分支从单级中断/异常版本边界切出，目的是在不改 CPU 指令逻辑的前提下，把键盘接入板级 MMIO。
- `board/top.v` 是当前 Vivado 顶层，连接自研 `rtl/SCPU.v`、自写 `IO/MIO_BUS.v`、`IO/PS2/PS2IO.v`、`IO/PS2/PS2KB.v`、老师 `SPIO.edf`、`Multi_8CH32.edf`、`SSeg7.edf`、自研 `rtl/dm_controller.v` 以及 `IO/` 中的时钟/输入/计数器 RTL。
- 当前不再使用老师提供的 `edf/MIO_BUS.edf` / `edf/MIO_BUS.V` 参与自研 CPU 板级构建；原因是键盘需要新增 `0xD0000000`/`0xD0000004` 地址映射和 `ps2_read` 握手信号，老师黑盒接口无法扩展。
- PS/2 地址映射：
  - `0xD0000000`：读 `{23'b0, ps2_ready, ps2_key}`，并向 PS2IO 发出读确认；
  - `0xD0000004`：读最近四个扫描码拼成的 `ps2_scancode`；
  - `0xE0000000`、`0xF0000000`、普通 RAM 地址行为保持原板级系统兼容。
- `constraints/icf.xdc` 已新增 `ps2_clk`、`ps2_data` 管脚约束。Vivado 工程中如果暂时不接键盘，也可以保留这两个顶层端口和约束。
- `coe/board/I_ps2_mmio_smoke.coe` 是 PS/2 MMIO smoke 程序；仿真命令见 `MANUAL.md`，预期 `--send-ps2-key 1c` 后显示 `0000011c`。
- `coe/board/I_exception_board_smoke.coe` 是上板用 exception 主路径 smoke 程序；只测 ECALL/SYSCALL、非法指令和 ERETN，不依赖 timer interrupt。预期显示 `11110000 -> e0000002 -> 22220000 -> e0000001 -> 33330000`，最终停在 `33330000`。
- VS Code Verilog 跳转当前使用 mshr-h Verilog-HDL 插件 + native `slang-server 0.2.7`。`.slang/server.json` 使用 `flags: -f board_own_files.f` 和精确 `indexGlobs`，已验证 `board/top.v` 中 `Enter`、`clk_div`、`ROM_D`、`SCPU`、`MIO_BUS`、`PS2IO`、`dm_controller`、`RAM_B`、`SPIO`、`Counter_x`、`Multi_8CH32`、`SSeg7` 均应可 Go to Definition。不要退回旧的 `board_own_deps.f + index.dirs` 方案；该方案曾出现重启 VS Code 后 No Definitions。
- `ROM_D` 使用 Distributed Memory Generator，`RAM_B` 使用 Block Memory Generator；两者必须在 Vivado 中生成，仓库当前只有连接接口，没有伪造可综合实现。
- `SCPU` 与 CPU 外围系统必须保持边界清晰。第一步只验证老师 EDF 能在外围系统中运行；替换自己的 CPU 时，接口需匹配 `edf/SCPU.v`，不要修改外围网表。
- 当前流水线分支的 `IO/clk_div.v` 在 100 MHz 输入下固定使用 `clkdiv[0]` 经 `BUFG` 后作为 CPU 时钟，频率 50 MHz。`SW[2]` 端口保留给原理图接口兼容，但当前不再用于运行时快/慢时钟选择。
- 时钟排查结论：`clkdiv[x]` 是计数器输出，直接扇出到大量 CPU 触发器时可能未走全局时钟网络；普通三目表达式做 clock mux 还会引入 LUT mux 和开关选择不确定性。流水线下板必须通过 `BUFG` 分发 `Clk_CPU`。
- `SW[7:5]` 选择数码管观察内容，`SW[0]` 传给数码管显示模块；管脚由 `constraints/icf.xdc` 约束。
- `coe/board/board_io_demo_instr.coe`/`coe/board/board_io_demo_data.coe` 当前是老师板级 IO 演示程序和数据，不等同于 `sim/data/Test_37_Instr8.dat`。上板现象用于验证板级 IO 外围系统；课程 Test-37 的指令正确性当前由 Icarus 自检覆盖，若需 Test-37 实板验收应单独导入 Test-37 COE。
- 已完成一次实板验证：Vivado 生成 bitstream 并 Program Device 成功；使用老师 `SCPU.edf` 时，`SW[7:5]=000` 可观察程序输出，`SW[4:3]` 可切换跑马灯、0~F 数据显示、寄存器递增等模式。
- 已完成 `testac.coe` 实板验收：当前 `coe/board/testac.coe` 与 `coe/board/testac模拟.txt` 对齐，反汇编保存在 `docs/disasm/testac.disasm.md`。使用自研 `rtl/SCPU.v` 能进入成功动画；老师 `SCPU.edf` 会停在 `FA123456`，不再作为该测试的正确性依据。
- 已替换老师 `dm_controller` 黑盒：当前使用自研 `rtl/dm_controller.v`，接口保持 `dm_controller(mem_w, Addr_in, Data_write, dm_ctrl, Data_read_from_dm, Data_read, Data_write_to_dm, wea_mem)` 不变，功能按 `docs/dm_ctrl说明.pdf` 实现读数据扩展、写数据对齐和 4 位字节写使能。
- 自研 CPU 兼容策略：`rtl/SCPU.v` 必须保持老师板级端口名，包括 `MIO_ready`、`dm_ctrl`、`CPU_MIO`、`INT`。当前 60–70 分阶段暂不实现中断，`INT` 和 `MIO_ready` 只保留接口；`CPU_MIO` 初版固定为 `1'b0`。
- 计时中断和按钮单步暂不属于本次基线。50 MHz 运行已通过 `clkdiv[0] -> BUFG` 实板验证；如未来恢复 SW[2] 快慢切换，应使用专用时钟 mux（如 BUFGMUX）或确保只在 reset 时选择，不能回到普通 `?:` clock mux。

当前下一步是以现有单周期 CPU 为黄金参考，准备 70–80 分阶段的冒险流水线 CPU 方案。macOS 上的 Icarus 端口检查不能验证 EDF 网表、IP 或时序，最终仍以 Vivado 和开发板确认为准。
