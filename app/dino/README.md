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

## 构建约定

协作者本地若已安装 RISC-V 工具链，可在本目录运行：

```bash
make
```

预期输出：

```text
../../coe/app/dino/I_dino_game.coe
```

注意：当前还没有 `src/crt0.S` / `src/main.c`，所以 Makefile 是构建约定草案。等第一个实现 PR 加入源文件后再运行 `make`。

当前用户本机暂不要求配置工具链。

## MMIO 快速参考

```text
VGA 文本显存：0xC0000000 + (row * 80 + col) * 4
PS/2 键盘：   0xD0000000
数码管：      0xE0000000
LED：         0xF0000000
```
