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

## 启动与基础驱动 smoke

```bash
cd app/dino
make clean
make
cd ../..
python3 sim/run_top_board_sim.py \
  --imem coe/app/dino/I_dino_game.coe \
  --sw 0000 \
  --max-cycles 100000
```

当前结果：ELF/COE 构建通过，程序大小 756 字节；顶层仿真在第 49177
周期写数码管调试值 `D1000000`，说明复位入口、栈、C 函数调用和 VGA 清屏
路径均已开始正常执行。
