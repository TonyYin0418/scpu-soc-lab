# 工具链设置（如果不在PATH中，可以修改为完整路径）
AS = riscv64-unknown-elf-as
LD = riscv64-unknown-elf-ld
OBJCOPY = riscv64-unknown-elf-objcopy
OBJDUMP = riscv64-unknown-elf-objdump

# 编译选项
ASFLAGS = -march=rv32i -mabi=ilp32
LDFLAGS = -T $(LINKER_SCRIPT) -m elf32lriscv
OBJCOPYFLAGS = -O binary
OBJDUMPFLAGS = -D -M no-aliases

# 构建目录
BUILD_DIR = build

# 目标文件
TARGET = Test_37_Instr8
SRC = $(TARGET).S
LINKER_SCRIPT = app.ld
OBJ = $(BUILD_DIR)/$(TARGET).o
ELF = $(BUILD_DIR)/$(TARGET).elf
BIN = $(TARGET).bin
COE = $(TARGET).coe
MCODE = mcode.txt
DISASM = $(TARGET).asm

# 默认目标：生成所有文件
all: $(BIN) $(COE) $(MCODE) $(DISASM)

# 创建构建目录
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# 汇编 -> 目标文件
$(OBJ): $(SRC) | $(BUILD_DIR)
	$(AS) $(ASFLAGS) -o $@ $<

# 链接 -> ELF文件
$(ELF): $(OBJ) $(LINKER_SCRIPT)
	$(LD) $(LDFLAGS) -o $@ $<

# ELF文件 -> 二进制文件
$(BIN): $(ELF)
	$(OBJCOPY) $(OBJCOPYFLAGS) $< $@

# 生成COE文件
$(COE): $(BIN)
	@echo "MEMORY_INITIALIZATION_RADIX=16;" > $@
	@echo "MEMORY_INITIALIZATION_VECTOR=" >> $@
	@hexdump -v -e '1/4 "%08x\n"' $< | awk '{printf "%s%s", (NR>1 ? "," : ""), $$0} END {print ";";}' >> $@
	@echo "COE file generated: $(COE)"

# 生成带0x前缀的机器码文本文件
$(MCODE): $(BIN)
	@hexdump -v -e '1/4 "0x%08x\n"' $< > $@
	@echo "Machine code with 0x prefix saved to $(MCODE)"

# 生成反汇编文件
$(DISASM): $(ELF)
	$(OBJDUMP) $(OBJDUMPFLAGS) $< > $@
	@echo "Disassembly saved to $(DISASM)"

# 显示机器码（32位十六进制）
dump: $(BIN)
	@echo "Machine code (hex):"
	@hexdump -v -e '1/4 "%08x\n"' $<

# 反汇编（验证是否正确）
disasm: $(DISASM)

# 清理生成的文件
clean:
	rm -rf $(BUILD_DIR)
	rm -f $(BIN) $(COE) $(MCODE) $(DISASM)

.PHONY: all dump disasm clean