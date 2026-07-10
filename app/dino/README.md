# Dino Game 应用目录

本目录用于实现 Chrome Dinosaur 类小游戏。当前只放协作骨架和构建约定，完整游戏逻辑由后续 PR 增量加入。

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

加入 `src/crt0.S` 和游戏源文件后，在本目录运行：

```bash
make
```

预期输出：

```text
../../coe/app/dino/I_dino_game.coe
```

当前还没有 `src/crt0.S` / `src/main.c`，因此完整的 `make` 会明确提示缺少应用源文件；交叉编译环境可先用 `make toolchain-check` 独立验证。

## MMIO 快速参考

```text
VGA 文本显存：0xC0000000 + (row * 80 + col) * 4
PS/2 键盘：   0xD0000000
数码管：      0xE0000000
LED：         0xF0000000
```
