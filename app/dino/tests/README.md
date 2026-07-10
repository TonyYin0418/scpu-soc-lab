# Dino Game 测试记录

## 交叉编译工具链自检

`toolchain_smoke.S` 只使用 RV32I 基础指令，用于验证编译、链接、objcopy、
反汇编以及 ELF32 RISC-V 输出：

```bash
cd app/dino
make toolchain-check
```

成功时最后输出 `RV32I toolchain check passed`，生成物位于 `app/dino/build/`。

后续每次 PR 建议记录：

```text
日期：
分支 / commit：
生成 COE：
top 仿真命令：
Vivado bitstream：
上板现象：
问题：
```

## 完整游戏顶层验收

```bash
cd app/dino
make clean
make
cd ../..
python3 sim/run_top_board_sim.py \
  --imem coe/app/dino/I_dino_game.coe \
  --dmem coe/app/dino/D_dino_game.coe \
  --sw 4000 --max-cycles 600000 \
  --send-ps2-key 29 --send-ps2-key2 2d \
  --send-ps2-key2-delay-ns 2000000 --check-dino
```

预期：`[PASS] DINO title -> running -> game over -> restart completed`。

跳跃验收：

```bash
python3 sim/run_top_board_sim.py \
  --imem coe/app/dino/I_dino_game.coe \
  --dmem coe/app/dino/D_dino_game.coe \
  --sw 4000 --max-cycles 600000 \
  --send-ps2-key 29 --send-ps2-key2 29 \
  --send-ps2-key2-delay-ns 900000 --check-dino-jump
```

预期：`[PASS] DINO jump reached visible height`。

2026-07-10 本地结果：两项均通过。第一项在第 427637 周期完成重开并把
分数清零；第二项在第 259022 周期观察到角色升空。指令镜像 759 字，数据
镜像 330 字，ELF 属性为 `rv32i2p1`，无未解析符号和 M/C 扩展指令。
