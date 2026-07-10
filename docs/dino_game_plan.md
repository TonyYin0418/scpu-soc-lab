# Chrome Dinosaur 类小游戏设计计划

本计划用于 `feature/dino-game-app` 分支协作。目标不是像素级复刻 Chrome Dino，而是在当前 SCPU SoC 上实现一个可演示、可验收、可扩展的横向跑酷小游戏：键盘输入控制角色跳跃，VGA 显示地面、障碍物、分数和状态，程序运行在自研流水线 CPU 上。

## 1. 阶段目标

### 当前阶段状态

初版已经完成游戏主循环、跳跃物理、障碍、碰撞、计分、难度提升、Game Over
和重开，并通过顶层自动仿真。当前尚未完成的扩展项是像素级美术、声音和
timer interrupt 驱动；它们不影响初版演示。

### 最终演示目标

1. 开机后 VGA 显示游戏标题或静态初始画面。
2. 键盘按键开始游戏或控制跳跃。
3. 障碍物从右向左移动。
4. 角色跳跃避障。
5. 碰撞后显示 Game Over 和分数。
6. 可通过键盘重新开始。
7. 程序主要通过 VGA 输出，数码管可作为调试显示。

## 2. 已有硬件/软件基础

当前 `main` 已具备：

- 五级流水线 RV32I CPU；
- PS/2 键盘 MMIO；
- VGA 文本显示 MMIO；
- 数码管 MMIO；
- LED MMIO；
- top 级 COE 仿真脚本。

关键 MMIO 地址：

| 地址 | 方向 | 用途 |
| --- | --- | --- |
| `0xC0000000 + cell*4` | 写 | VGA 文本显存，`cell = row*80 + col` |
| `0xD0000000` | 读 | PS/2 `{23'b0, ready, key}` |
| `0xD0000004` | 读 | 最近扫描码拼接值 `ps2_scancode` |
| `0xE0000000` | 写/读 | 数码管显示写入口；读 BTN/SW |
| `0xF0000000` | 写/读 | LED/SPIO 写入口；读 LED 状态 |

VGA 当前是 80 列 × 60 行 ASCII 文本模式，不是逐像素 framebuffer。对小游戏足够：用字符块、空格、地面线、障碍物字符、角色字符和分数字符构成画面。

## 3. 推荐实现路线

### 方案选择：先文本游戏，后图形增强

当前建议采用文本/字符块方案：

- 角色：`@`、`D` 或自定义 ASCII 字符；
- 地面：`_`、`=`、`-`；
- 障碍：`|`、`#`、`X`；
- 云/背景：`.`、`'`、空格；
- 分数：右上角 ASCII 数字；
- Game Over：居中字符串。

理由：

- 已有 VGA 文本 MMIO，软件可以直接写；
- 不需要先扩展像素 framebuffer；
- 资源和时序压力低；
- 更容易在短时间内完成演示；
- 后续如果时间够，再扩展到 Pixel 输入或更复杂 VRAM。

### 推荐软件分层

```text
app/dino/
├── include/
│   ├── mmio.h          # MMIO 地址和读写函数
│   ├── vga_text.h      # 文本显存输出接口
│   ├── keyboard.h      # PS/2 扫描码读取接口
│   └── game.h          # 游戏状态结构和核心函数声明
├── src/
│   ├── crt0.S          # 裸机启动入口，初始化 sp 后跳 main
│   ├── main.c          # 主循环
│   ├── vga_text.c      # 清屏、写字符、写字符串、写数字
│   ├── keyboard.c      # 读取键盘扫描码、按键事件转换
│   └── game.c          # 游戏状态更新、碰撞、绘制
├── assets/
│   └── README.md       # 字符画/布局草案
├── tests/
│   └── README.md       # 软件级和板级测试记录
├── linker.ld           # ROM 从 0x0 开始的裸机链接脚本
├── Makefile            # GNU/LLVM 自动选择并生成 COE
└── README.md           # 协作入口
```

上述模块均已实现。

## 4. 游戏循环设计

建议先不用中断，采用轮询：

```text
初始化 VGA
显示标题
等待键盘开始

while (1):
    读取键盘
    更新角色速度/位置
    更新障碍位置
    检测碰撞
    更新分数
    重绘变化区域
    软件延时
```

后续若要提高观感，可改为 timer interrupt 驱动游戏 tick，但当前不是第一优先级。

## 5. 坐标与画面建议

VGA 文本坐标：

- `x = 0..79`
- `y = 0..59`

推荐游戏区域：

```text
y=0      分数、状态栏
y=1..47  空中/背景
y=48     角色跳跃最高区域附近
y=52     地面角色基准线
y=53     地面线
y=54..59 调试区或保留
```

角色可以先占 1 个字符，后续扩展成 2×2 字符块。

障碍物可以先占 1×2 或 1×3 字符。

## 6. 键盘输入建议

PS/2 扫描码先只处理最小集合：

| 按键 | Make Code | 用途 |
| --- | --- | --- |
| Space | `0x29` | 跳跃 / 开始 / 重开 |
| W | `0x1D` | 可选跳跃 |
| R | `0x2D` | 可选重开 |

暂时可以忽略 Break Code `0xF0`，只处理按下事件。若出现连续触发问题，再在 `keyboard.c` 中加状态机。

## 7. 编译与 COE 生成约定

本机使用 Homebrew LLVM + LLD；Makefile 也兼容 GNU RISC-V 工具链。先运行：

```bash
cd app/dino
make toolchain-check
```

构建应用：

```bash
cd app/dino
make
```

预期生成：

```text
build/dino.elf
build/dino.imem.bin
build/dino.dmem.bin
build/dino.asm
../../coe/app/dino/I_dino_game.coe
../../coe/app/dino/D_dino_game.coe
```

两个 COE 必须成对使用。指令 ROM 与数据 RAM 相互独立，字符串和只读数据放在 `D_dino_game.coe` 的数据地址 `0x400` 起始区域。

支持的工具链：

```text
riscv64-unknown-elf-gcc
riscv64-unknown-elf-objcopy
riscv64-unknown-elf-objdump
Homebrew llvm + lld
```

编译选项必须满足：

```text
-march=rv32i -mabi=ilp32 -ffreestanding -nostdlib
```

注意：当前 CPU 不实现 M 扩展，C 代码中不要使用乘法、除法、取模，除非确认编译器不会生成 `mul/div/rem` 或已提供软件库实现。

## 8. PR 协作规则

建议另一个人从本分支再切自己的功能分支：

```bash
git checkout feature/dino-game-app
git pull
git checkout -b feature/dino-game-core
```

PR 应尽量按小块提交：

1. `app/dino` 构建脚本和最小启动程序；
2. VGA 文本输出库；
3. 键盘输入库；
4. 游戏状态和渲染；
5. 上板测试 COE 与现象记录。

每个 PR 至少说明：

- 改了哪些文件；
- 是否能生成 COE；
- 是否跑过 top 级仿真；
- 是否上板；
- 预期 VGA/数码管现象。

## 9. 验收标准草案

### 已通过的最小验收

- ROM/RAM 成对使用 `I_dino_game.coe`、`D_dino_game.coe`；
- `SW[15]=0`；
- VGA 有稳定画面；
- 键盘 Space/W 能触发跳跃或开始；
- 障碍物移动；
- 碰撞后状态变化。

### 较好验收

- 分数持续增加；
- Game Over 后可重新开始；
- 画面只刷新变化区域，闪烁较少；
- 数码管显示分数或调试状态；
- 程序代码中实际执行 37 条指令覆盖测试或单独保留测试程序证明 CPU 指令完整性。

### 高分扩展候选

- 多种障碍；
- 随机障碍间距；
- 难度随分数增加；
- 简单动画帧；
- 键盘菜单；
- 使用 timer interrupt 做稳定游戏 tick；
- 如果时间充足，再考虑图形 framebuffer。

## 10. 后续可选决策

需要用户/协作者确认：

1. 是否继续从文本字符块升级到像素/图形块风格？
2. 是否改用 timer interrupt 驱动稳定游戏 tick？
3. 游戏程序本身是否需要覆盖 37 条指令，还是继续用已有 `testac` 独立验收？
4. 正式展示前仍需在开发板确认 VGA 字库初始化和实际按键手感。
