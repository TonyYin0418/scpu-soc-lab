# coe2bin

将 RISC-V 汇编源文件编译并转换为多种格式的工具脚本，主要用于为 Vivado Block RAM 生成 `.coe` 初始化文件。

## 功能

- 将 `.S` 汇编文件编译为 ELF，再提取为纯二进制 `.bin`
- 生成 Xilinx Vivado 可用的 `.coe` 内存初始化文件
- 生成带 `0x` 前缀的机器码文本文件 `mcode.txt`
- 生成反汇编文件 `.asm`，用于验证编译结果

## 工作流程

```
*.S  →  *.o  →  *.elf  →  *.bin  →  *.coe
                                ↓
                           mcode.txt / *.asm
```

代码段起始地址固定为 `0x0`（由 `app.ld` 指定），目标架构为 `rv32i`。

## 依赖安装

需要安装 RISC-V 32位 ELF 工具链：

**Ubuntu / Debian：**
```bash
sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
```

**验证安装：**
```bash
riscv64-unknown-elf-as --version
```

## 使用方法

### 编译默认目标（`Test_37_Instr8.S`）

```bash
make
```

生成以下文件：
| 文件 | 说明 |
|------|------|
| `Test_37_Instr8.bin` | 纯二进制机器码 |
| `Test_37_Instr8.coe` | Vivado Block RAM 初始化文件 |
| `mcode.txt` | 带 `0x` 前缀的十六进制机器码，每行一条指令 |
| `Test_37_Instr8.asm` | 反汇编文本 |

### 编译其他汇编文件

```bash
make TARGET=test    # 编译 test.S
```

### 其他命令

```bash
make dump     # 在终端直接打印十六进制机器码
make disasm   # 仅生成反汇编文件
make clean    # 删除所有生成文件及 build/ 目录
```

## 目录结构

```
coe2bin/
├── app.ld        # 链接脚本（代码段起始于 0x0）
├── Makefile      # 构建脚本
├── ecall.S       # 示例汇编源文件
└── build/        # 编译中间文件（自动生成）
```
