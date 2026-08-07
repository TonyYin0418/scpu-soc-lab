# SCPU_SOC

本仓库是武汉大学《计算机系统综合设计》课程项目的归档版本。项目以 RV32I
五级流水线 CPU 为核心，在 Nexys A7 FPGA 开发板上连接存储器、PS/2 键盘、
VGA 文本显示、LED 和七段数码管，并运行一个裸机 Dino 跑酷游戏。

当前 `main` 的源码以提交 `be2306c` 为基线。该版本与课程最终提交压缩包中的
核心源码逐文件一致，并保留了后续复现所需的 RTL、测试、COE、约束和参考资料。

## 实现内容

- 37 条课程要求的 RV32I 指令；
- IF、ID、EX、MEM、WB 五级流水线；
- EX/MEM 与 MEM/WB 前推、load-use 暂停和控制流冲刷；
- 字节、半字和字访存，以及相应的数据存储器控制；
- 非法指令、ECALL 和计时中断所需的单级 trap 基础设施；
- PS/2 键盘 MMIO；
- 80 x 60 字符模式 VGA 显示；
- 使用 C 和少量汇编编写的 RV32I 裸机 Dino 游戏；
- Icarus Verilog 自检、板级顶层仿真和 Vivado 下板文件。

归档版游戏采用字符模式画面：恐龙固定在屏幕左侧，仙人掌从右向左移动，
支持跳跃、碰撞、重新开始和计分。游戏源码及其 MMIO 约定见
[`game/README.md`](game/README.md)。

## 目录结构

```text
board/        Nexys A7 板级顶层
constraints/  FPGA 引脚与时钟约束
rtl/          五级流水线 CPU 和数据通路 RTL
IO/           MIO、PS/2、VGA、时钟和板级外设
sim/          CPU、外设和板级顶层测试
coe/          Vivado ROM/RAM 初始化文件
game/         Dino 裸机程序、链接脚本和构建文件
asm2coe/      汇编测试程序到 COE 的转换工具
edf/          课程提供的参考网表和接口声明
docs/         实验报告、演示视频、参考资料和设计记录
```

## 快速验证

环境至少需要 Icarus Verilog 和 `vvp`。所有命令从仓库根目录执行。

```bash
mkdir -p build
iverilog -g2012 -Wall -s sccomp_tb -o build/simv -f files.f
vvp -n build/simv
vvp -n build/simv +TEST_AUIPC
vvp -n build/simv +TEST37
```

检查自研 CPU 与板级顶层的接口：

```bash
iverilog -g2012 -Wall -s top -o build/top_own_check -f board_own_files.f
```

构建 Dino 程序需要裸机 RISC-V GNU 工具链：

```bash
cd game
make
make install-coe
```

更完整的仿真、COE、Vivado IP 配置和开发板操作步骤见
[`MANUAL.md`](MANUAL.md)。其中 Vivado 工程需要按说明生成 `ROM_D` 和
`RAM_B` IP；仓库不会提交 Vivado 缓存、运行目录或 bitstream。

## 报告与演示

- [课程实验报告](docs/2026年计算机系统综合设计实验报告-雷军-2024302131025-尹玉文东.doc)
- [开发板演示视频](docs/demo.mp4)

受课程截止时间和版本整理影响，实验报告记录的部分后续优化方案与本仓库
`main` 上的最终提交代码并不完全一致。阅读游戏定时器、中断驱动帧更新、
像素角色、下蹲和飞鸟等内容时，请结合下面的历史分支谨慎参考；报告作为
当时正式提交的原件保留，未对正文进行追溯修改。

## 历史分支

- `archive/early-dino-attempt`：较早的独立 Dino 方案和实现，未合入最终版本；
- `archive/unfinished-dino-optimization`：在可运行版本之后进行的玩法、构建和
  中断驱动优化，最终未作为课程提交代码；
- `archive/jdsr-dino-experiment`：从最终提交压缩包中恢复的 jdsr 实验历史。

这些分支用于保留设计演进和未完成尝试。学习或复现实验时应以 `main` 为
默认起点，需要研究后续方案时再单独检出相应归档分支。

## 说明

本仓库包含课程提供的接口文件、参考资料和第三方教材资料，仅用于课程学习、
实验复现和非商业交流。引用或再分发相关资料时，请同时遵守原课程与资料来源
的使用要求。
