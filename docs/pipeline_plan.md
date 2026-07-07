# 冒险流水线 CPU 设计计划

本文档用于规划 70–80 分阶段的 37 条指令冒险流水线 CPU。当前只确定设计方案和验收路径，不开始修改 RTL。

目标是：在保留现有单周期 CPU 可用基线的前提下，实现可下板的 5 级冒险流水线 CPU，并成功运行课程 37 条指令测试程序。

## 1. 当前基线

已完成并保留的基线：

- 37 条 RV32I 单周期 CPU。
- Test-8、Test-37、AUIPC 补测通过。
- 自研 `rtl/SCPU.v` 已兼容老师板级 `SCPU` 接口。
- Vivado 下板已验证基本 IO 演示程序可运行。
- `dm_ctrl` 编码已和老师补充文档一致。

流水线阶段不得破坏上述基线。所有改动都应能回退到当前单周期版本。

## 2. 固定目标

流水线 CPU 固定采用经典 5 级结构：

```text
IF -> ID -> EX -> MEM -> WB
取指  译码  执行  访存  写回
```

必须支持课程当前 37 条指令：

- R 型：ADD、SUB、SLL、SRL、SRA、SLT、SLTU、AND、OR、XOR
- I 型运算：ADDI、SLLI、SRLI、SRAI、SLTI、SLTIU、ANDI、ORI、XORI
- U 型：LUI、AUIPC
- 访存：LB、LBU、LH、LHU、LW、SB、SH、SW
- 分支：BEQ、BNE、BLT、BGE、BLTU、BGEU
- 跳转：JAL、JALR

暂不实现：

- 中断。
- 异常。
- SYSCALL/ECALL。
- Cache。
- 分支预测。
- 多周期总线等待。

这些属于后续 85 分以上阶段，不能提前混进第一版流水线。

## 3. 固定外部接口

流水线 CPU 最终必须继续兼容老师 `SCPU` 接口：

```verilog
module SCPU(
    input             clk,
    input             reset,
    input             MIO_ready,
    input      [31:0] inst_in,
    input      [31:0] Data_in,

    output            mem_w,
    output     [31:0] PC_out,
    output     [31:0] Addr_out,
    output     [31:0] Data_out,
    output     [2:0]  dm_ctrl,
    output            CPU_MIO,
    input             INT
);
```

当前阶段固定处理：

```text
MIO_ready 暂不使用
CPU_MIO   固定为 1'b0
INT       暂不使用
```

板级输出信号来源固定如下：

| 外部信号 | 流水线来源 | 说明 |
|---|---|---|
| `PC_out` | IF 阶段当前 PC | 送指令 ROM 取指 |
| `Addr_out` | MEM 阶段访存地址 | 来自 EX/MEM.alu_result |
| `Data_out` | MEM 阶段写存储器数据 | 来自 EX/MEM.store_data |
| `mem_w` | MEM 阶段 store 写使能 | 必须受 valid 控制 |
| `dm_ctrl` | MEM 阶段访存类型 | LB/LH/LW/LBU/LHU/SB/SH/SW |
| `Data_in` | MEM 阶段读存储器数据 | load 指令写回来源 |

关键约束：

```verilog
mem_w = EX_MEM_valid && EX_MEM_MemWrite;
```

任何被 flush 的 store 都不能写外部 RAM 或 IO。

## 4. 固定流水线寄存器

每级流水寄存器都必须有 `valid` 位。`valid=0` 表示 bubble，该指令不能写寄存器、不能写内存、不能改变外设状态。

### 4.1 IF/ID

保存：

```text
valid
pc
inst
```

用途：

- 给 ID 阶段译码。
- hazard 检测时读取 `rs1/rs2`。
- flush 时清空错误取到的指令。

### 4.2 ID/EX

保存：

```text
valid
pc
inst
rs1
rs2
rd
rd1
rd2
imm
funct3

RegWrite
MemWrite
ALUSrc
ALUOp
NPCOp 或 BranchType
WDSel
dm_ctrl
```

用途：

- EX 阶段执行 ALU、分支比较、JAL/JALR 目标计算。
- forwarding 单元比较 `ID_EX.rs1/rs2`。
- load-use hazard 检测当前 EX 阶段是否是 load。

### 4.3 EX/MEM

保存：

```text
valid
pc
rd
alu_result
store_data
pc_plus4
branch_taken
branch_target

RegWrite
MemWrite
WDSel
dm_ctrl
```

用途：

- MEM 阶段访问数据 RAM/IO。
- 给 EX 阶段提供 EX/MEM forwarding。
- 给控制逻辑提供 branch/jump flush 信息。

### 4.4 MEM/WB

保存：

```text
valid
pc
rd
alu_result
mem_data
pc_plus4

RegWrite
WDSel
```

用途：

- WB 阶段写回寄存器堆。
- 给 EX 阶段提供 MEM/WB forwarding。

## 5. 固定控制策略

### 5.1 PC 更新

正常情况：

```text
PC = PC + 4
```

stall 情况：

```text
PC 保持不变
IF/ID 保持不变
ID/EX 插入 bubble
```

branch/jump 成立：

```text
PC = branch_target 或 jump_target
IF/ID 清空
ID/EX 清空
```

### 5.2 分支和跳转决策阶段

第一版固定在 EX 阶段决定：

- BEQ/BNE/BLT/BGE/BLTU/BGEU 在 EX 阶段比较。
- JAL 在 EX 阶段产生 `PC + imm`。
- JALR 在 EX 阶段产生 `(rs1 + imm) & ~1`。

优点：

- 简单。
- 旁路路径集中在 EX 阶段。
- 容易调试。

代价：

- taken branch/jump 会产生 bubble。

第一版不做 ID 阶段提前分支判断。

### 5.3 写回

WB 阶段写回来源固定：

| `WDSel` | 写回数据 |
|---|---|
| ALU | `MEM_WB.alu_result` |
| MEM | `MEM_WB.mem_data` |
| PC | `MEM_WB.pc_plus4` |

写回必须满足：

```text
MEM_WB.valid == 1
MEM_WB.RegWrite == 1
MEM_WB.rd != 0
```

`x0` 必须始终保持 0。

## 6. 固定冒险处理

### 6.1 ALU 数据冒险 forwarding

必须支持：

```text
EX/MEM -> EX
MEM/WB -> EX
```

典型例子：

```asm
add x1, x2, x3
add x4, x1, x5
```

选择优先级：

```text
EX/MEM forwarding 优先级高于 MEM/WB forwarding
```

原因是 EX/MEM 中的结果更新。

判断条件：

```text
EX/MEM.valid
EX/MEM.RegWrite
EX/MEM.rd != 0
EX/MEM.rd == ID/EX.rs1 或 ID/EX.rs2
```

MEM/WB 同理。

### 6.2 load-use stall

必须暂停一拍。

典型例子：

```asm
lw  x1, 0(x2)
add x3, x1, x4
```

固定处理：

```text
PC 保持
IF/ID 保持
ID/EX 插入 bubble
```

判断条件：

```text
ID/EX.valid
ID/EX 是 load
ID/EX.rd != 0
ID/EX.rd == IF/ID.rs1 或 IF/ID.rs2
```

其中“ID/EX 是 load”可以用：

```text
ID/EX.RegWrite == 1
ID/EX.WDSel == FromMEM
```

### 6.3 store data forwarding

必须支持 store 写数据 forwarding。

典型例子：

```asm
add x1, x2, x3
sw  x1, 0(x4)
```

`sw` 的地址使用 `rs1`，写入数据使用 `rs2`。因此 `rs2` 也要能从前面指令 forwarding。

第一版建议统一在 EX 阶段得到 forwarding 后的 `store_data`，再写入 EX/MEM：

```text
EX/MEM.store_data = forwarded_rs2
```

### 6.4 branch operand forwarding

分支在 EX 阶段判断，因此分支比较操作数也复用 EX 阶段 forwarding。

典型例子：

```asm
addi x1, x0, 1
beq  x1, x0, label
```

如果没有 forwarding，分支会读到旧的 `x1`。

### 6.5 flush

branch/jump 成立时必须 flush：

```text
IF/ID.valid = 0
ID/EX.valid = 0
```

已经进入 EX/MEM 的跳转指令本身不能被清掉，因为它可能还要写回 `PC+4`。

## 7. 固定访存行为

访存信号在 MEM 阶段对外输出：

```text
Addr_out = EX_MEM.alu_result
Data_out = EX_MEM.store_data
dm_ctrl  = EX_MEM.dm_ctrl
mem_w    = EX_MEM.valid && EX_MEM.MemWrite
```

load 指令在 MEM 阶段接收：

```text
mem_data = Data_in
```

然后进入 MEM/WB，在 WB 阶段写回寄存器。

`dm_ctrl` 编码必须保持老师补充文档格式：

```verilog
`define dm_word              3'b000
`define dm_halfword          3'b001
`define dm_halfword_unsigned 3'b010
`define dm_byte              3'b011
`define dm_byte_unsigned     3'b100
```

## 8. 模块划分计划

第一版建议保守复用现有模块：

```text
RF
alu
EXT
ctrl_encode_def.v
dm_ctrl 编码
```

可能需要新增：

```text
SCPU_PIPE.v          # 流水线 CPU 顶层
hazard_unit.v        # load-use stall 和 flush 控制
forward_unit.v       # EX 阶段 forwarding 选择
pipeline_regs.v      # 可选；也可先写在 SCPU_PIPE 内部
```

第一版为了调试方便，可以先把 pipeline register 写在 `SCPU_PIPE.v` 内部。等功能稳定后，再决定是否拆成独立模块。

## 9. 文件组织建议

建议不要直接覆盖当前 `rtl/SCPU.v`。

推荐结构：

```text
rtl/
├── SCPU.v              # 当前单周期 CPU，保持可用
├── SCPU_PIPE.v         # 新流水线 CPU
├── hazard_unit.v       # 新增
├── forward_unit.v      # 新增
├── alu.v               # 复用
├── ctrl.v              # 可能复用或轻微改造
├── EXT.v               # 复用
├── RF.v                # 复用
└── ctrl_encode_def.v   # 复用
```

原因：

- 目录不大，暂时不必拆成 `single/`、`pipeline/`、`common/`。
- 保留 `rtl/SCPU.v` 能随时回到已经下板成功的单周期版本。
- 新增 `SCPU_PIPE.v` 更容易和单周期对照。

后续下板时再决定：

```text
方案 A：把 SCPU_PIPE 包一层 wrapper，模块名仍叫 SCPU
方案 B：复制/替换为 rtl/SCPU.v
```

第一版推荐方案 A，避免破坏单周期基线。

## 10. 测试计划

不要一上来跑 Test-37。按以下顺序推进。

### 10.1 最小无冒险程序

目标：确认流水线能正常推进。

覆盖：

```text
addi
add
sub
lui
auipc
```

检查：

- PC 每周期推进。
- WB 写回正确。
- `x0` 保持 0。

### 10.2 ALU forwarding 测试

典型程序：

```asm
addi x1, x0, 1
add  x2, x1, x1
add  x3, x2, x1
```

目标：

- 验证 EX/MEM -> EX。
- 验证 MEM/WB -> EX。

### 10.3 load-use stall 测试

典型程序：

```asm
lw   x1, 0(x0)
add  x2, x1, x1
```

目标：

- PC 暂停一拍。
- IF/ID 暂停一拍。
- ID/EX 插入 bubble。
- 最终结果正确。

### 10.4 store forwarding 测试

典型程序：

```asm
addi x1, x0, 0x12
sw   x1, 0(x0)
```

目标：

- store 写入新值，而不是旧值。

### 10.5 branch forwarding 和 flush 测试

典型程序：

```asm
addi x1, x0, 1
beq  x1, x0, bad
addi x2, x0, 2
```

目标：

- 分支比较使用 forwarding 后的数据。
- taken branch 能 flush 错误路径。
- not-taken branch 不误 flush。

### 10.6 jump 测试

覆盖：

```text
JAL
JALR
```

目标：

- `rd = PC + 4`。
- JALR 目标最低位清零。
- 错误取到的指令被 flush。

### 10.7 完整回归

最终必须通过：

```bash
iverilog -g2012 -Wall -s sccomp_tb -o build/simv -f files.f
vvp -n build/simv
vvp -n build/simv +TEST_AUIPC
vvp -n build/simv +TEST37
```

还必须通过板级接口检查：

```bash
iverilog -g2012 -Wall -s top -o build/top_own_check -f board_own_files.f
```

下板前需要新增流水线专用 filelist，避免和单周期 `SCPU` 同名冲突。

## 11. 实现里程碑

建议拆成以下 commit/阶段：

### P0：计划与测试框架

- 写本计划文档。
- 确认流水线模块命名和 filelist 方案。
- 准备最小流水线测试程序。

### P1：流水线骨架

- 实现 IF/ID、ID/EX、EX/MEM、MEM/WB。
- 暂不处理复杂冒险。
- 跑最小无冒险程序。

### P2：forwarding

- 实现 EX/MEM -> EX。
- 实现 MEM/WB -> EX。
- 实现 branch operand forwarding。
- 实现 store data forwarding。

### P3：stall 和 flush

- 实现 load-use stall。
- 实现 branch/jump flush。
- 确认 `valid` 能屏蔽所有副作用。

### P4：完整 37 条回归

- Test-8 通过。
- AUIPC 补测通过。
- Test-37 通过。
- 对照单周期 CPU 结果。

### P5：板级替换和下板

- 流水线 CPU 兼容老师 `SCPU` 接口。
- Vivado 生成 bitstream。
- Program Device 后运行板级测试程序。

## 12. 需要确认的选项

以下选项尚未最终决定。

### 选项 A：模块名

推荐：

```text
SCPU_PIPE
```

理由：

- 不破坏当前 `SCPU` 单周期基线。
- 可以同时保留单周期和流水线两个版本。

待确认：

- 是否同意先写 `SCPU_PIPE`，后续再 wrapper 成 `SCPU` 下板？

### 选项 B：目录是否重构

推荐第一版不大规模重构目录。

即保持：

```text
rtl/SCPU.v
rtl/SCPU_PIPE.v
rtl/hazard_unit.v
rtl/forward_unit.v
```

理由：

- 当前项目规模不大。
- 减少 filelist 和 slang-server 配置变化。
- 避免在流水线功能未稳定前引入目录迁移风险。

待确认：

- 是否接受先不拆 `rtl/single`、`rtl/pipeline`、`rtl/common`？

### 选项 C：testbench 策略

推荐新增流水线专用 testbench 或参数化 testbench。

可选方案：

1. 新建 `sim/sccomp_pipe_tb.v`
2. 改造现有 `sccomp_tb.v`，用宏或参数选择单周期/流水线

推荐先用方案 1。

理由：

- 不影响当前单周期回归。
- 出问题时更容易定位。

待确认：

- 是否同意新增 `sim/sccomp_pipe_tb.v`？

## 13. 第一版不做的优化

第一版流水线明确不做：

- 分支预测。
- ID 阶段提前分支。
- 多周期访存等待。
- CSR。
- 中断/异常。
- SYSCALL/ECALL。
- Cache。
- 性能计数器。

这些优化必须等 37 条指令冒险流水线稳定后再进入下一阶段。

## 14. 验收标准

70–80 分阶段完成的最低标准：

- 37 条指令流水线 CPU 功能正确。
- 数据冒险和控制冒险处理正确。
- Test-8、AUIPC、Test-37 全部通过。
- 能替换当前板级 `SCPU` 接口。
- Vivado 能综合、实现、生成 bitstream。
- 开发板运行测试程序成功。

只有仿真通过但没有下板，不算完成本阶段。

