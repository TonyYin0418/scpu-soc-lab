# 流水线 CPU 单级中断/异常设计计划

本阶段目标对应 85–90 分要求：在已有五级冒险流水线 CPU 上实现单级中断/异常，不实现 8259，不实现嵌套中断。

## 1. 实现范围

支持三类事件：

- 非法指令异常；
- `SYSCALL`，使用 RISC-V `ECALL` 编码 `32'h00000073`；
- 计时中断，使用 `SCPU.INT` 输入。

新增状态寄存器：

- `SEPC[31:0]`：保存进入 trap 时当前 EX 阶段指令 PC；
- `SCAUSE[7:0]`：保存 trap 原因；
- `STATUS[7:0]`：`STATUS[0]` 表示正在 trap 中；
- `INTMASK[7:0]`：`INTMASK[6]` 表示允许计时中断。

`INTMASK` 复位值为 0，避免普通程序被外部计数器信号意外打断。软件可向内部控制地址 `0xFFFF_FF00` 写入低 8 位更新 `INTMASK`；写入时同时清空 pending。

## 2. 原因码和向量入口

| 事件 | `SCAUSE` | 向量入口 |
| --- | ---: | ---: |
| 非法指令 | `8'h01` | `32'h00000300` |
| SYSCALL / ECALL | `8'h02` | `32'h00000320` |
| 计时中断 | `8'h06` | `32'h00000340` |

采用多个固定向量入口，避免 handler 必须读取 `SCAUSE`，同时贴合课件“NPC 设置为相应的中断向量入口”的说法。

## 3. 返回指令

按课件实现两条课程自定义返回指令：

| 指令 | 编码 | 行为 |
| --- | ---: | --- |
| `ERET` | `32'h00100073` | `PC <= SEPC` |
| `ERETN` | `32'h00200073` | `PC <= SEPC + 4` |

暂不实现 `MRET`。如果后续老师明确要求，可再把 `32'h30200073` 映射为其中一种返回行为。

## 4. 流水线处理规则

课件要求“在指令来到 EX 阶段时检测”。本设计统一在 EX 阶段处理：

1. ID 阶段只识别非法指令、`ECALL`、`ERET`、`ERETN`，并把标记写入 ID/EX；
2. EX 阶段把 `EX_SCAUSE`、`STATUS`、`INTMASK`、计时中断 pending 送入 `ExceptionUnit`；
3. 进入 trap 时：
   - `SEPC <= id_ex_pc`；
   - `SCAUSE <= trap_cause`；
   - `STATUS[0] <= 1'b1`；
   - `PC <= trap_vector`；
   - 清空 IF/ID 和 ID/EX；
   - 当前 EX 指令写入 EX/MEM 时变成 bubble，禁止 `RegWrite/MemWrite` 副作用。
4. 执行 `ERET/ERETN` 时：
   - `PC <= SEPC` 或 `SEPC + 4`；
   - `STATUS[0] <= 1'b0`；
   - 清空 IF/ID 和 ID/EX；
   - 当前返回指令不产生寄存器/内存副作用。

普通 branch/jump 与 trap 不同：branch/jump 的当前 EX 指令本身有效，仍可继续进入 EX/MEM；只清空错误路径上的 IF/ID 和 ID/EX。

## 5. 优先级

同一周期 EX 阶段按以下优先级处理：

1. `ERET/ERETN` 返回；
2. 非法指令 / `ECALL`；
3. 计时中断；
4. branch/jump redirect；
5. load-use stall；
6. 正常推进。

进入 trap 后 `STATUS[0]=1`，`ExceptionUnit` 不再响应新的异常/中断，实现单级模型。

## 6. 计时中断 pending

`SCPU.INT` 置位内部 pending bit：

- `INT` 高时，`int_pending[6]` 置 1；
- 响应计时中断后清 `int_pending[6]`；
- `STATUS[0]=1` 时 pending 可以保留，但不会再次响应；
- 向 `0xFFFF_FF00` 写 `8'h40` 可打开计时中断，写 `8'h00` 可关闭。

完整外设清中断/EOI 暂不做，8259 留作后续增强。

## 7. 测试策略

优先使用 top 级仿真，只观察显示 MMIO 写入值：

```text
display_write=11110000  正常开始
display_write=e0000002  ECALL handler
display_write=22220000  ECALL 返回后继续
display_write=e0000001  非法指令 handler
display_write=33330000  非法指令返回后继续
display_write=e0000006  timer handler
```

top testbench 可用 `FORCE_INT_START/FORCE_INT_END` 在仿真中产生一次计时中断脉冲；实板阶段再通过计数器外设产生 `INT`。
