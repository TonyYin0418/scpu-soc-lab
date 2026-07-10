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

当前还没有完整游戏程序。
