# Dino Game 应用目录

本目录包含可运行的 Chrome Dinosaur 风格文本小游戏初版。程序运行在自研 RV32I 流水线 CPU 上，通过 PS/2 键盘控制，并向 80×60 VGA 文本显存绘图。

## 目录说明

```text
src/       裸机启动、主循环、游戏逻辑
include/   MMIO、VGA、键盘和游戏模块头文件
assets/    字符画、布局草案、资源说明
tests/     软件/仿真/上板测试记录
```

详细设计见：

```text
docs/dino_game_plan.md
```

## 交叉编译环境

构建脚本支持两套 RV32I 裸机工具链，并会自动选择：

1. `riscv64-unknown-elf-gcc`；
2. Homebrew `llvm` + `lld`。

macOS 首次配置：

```bash
brew install llvm lld
cd app/dino
make toolchain-check
```

当前工程固定使用 `rv32i/ilp32`，不会生成 CPU 尚未实现的 M/C 扩展指令。
查看实际选择的编译器路径：

```bash
make toolchain-info
```

也可显式指定工具链：

```bash
make TOOLCHAIN=llvm toolchain-check
make TOOLCHAIN=gnu toolchain-check
```

## 构建约定

在本目录运行：

```bash
make
```

预期输出：

```text
build/dino.elf
build/dino.imem.bin
build/dino.dmem.bin
build/dino.asm
../../coe/app/dino/I_dino_game.coe
../../coe/app/dino/D_dino_game.coe
```

这两个 COE 必须成对使用：指令 ROM 加载 `I_dino_game.coe`，数据 RAM 加载 `D_dino_game.coe`。SoC 是 Harvard 结构，C 字符串和只读数据不能通过指令 ROM 读取，因此由数据 COE 预装到 RAM 的 `0x400` 起始区域。

当前指令镜像 759 个字，数据镜像 330 个字，均小于 1024 字深度。

## 游戏功能

- 标题画面与操作提示；
- Space、W、方向键上：开始或跳跃；
- R、Enter：重新开始；
- 任意板载按钮也可开始/跳跃；
- 障碍物持续左移并随机改变高度；
- 角色具有上升、下落和落地状态；
- 碰撞检测、Game Over、最终分数与重新开始；
- VGA 和数码管同步显示五位分数；
- 分数提高后逐级加速；
- LED 显示运行状态和分数低位。

正常上板时保持 `SW[15]=0`、`SW[14]=0`。`SW[14]=1` 仅用于仿真：缩短障碍距离和帧延时，让碰撞测试快速完成。

## 顶层自动验收

```bash
# 标题 -> 运行 -> 碰撞 -> Game Over -> R 重开
python3 sim/run_top_board_sim.py \
  --imem coe/app/dino/I_dino_game.coe \
  --dmem coe/app/dino/D_dino_game.coe \
  --sw 4000 --max-cycles 600000 \
  --send-ps2-key 29 --send-ps2-key2 2d \
  --send-ps2-key2-delay-ns 2000000 --check-dino

# 第二次 Space 使角色实际升空
python3 sim/run_top_board_sim.py \
  --imem coe/app/dino/I_dino_game.coe \
  --dmem coe/app/dino/D_dino_game.coe \
  --sw 4000 --max-cycles 600000 \
  --send-ps2-key 29 --send-ps2-key2 29 \
  --send-ps2-key2-delay-ns 900000 --check-dino-jump
```

## MMIO 快速参考

```text
VGA 文本显存：0xC0000000 + (row * 80 + col) * 4
PS/2 键盘：   0xD0000000
数码管：      0xE0000000
LED：         0xF0000000
```
