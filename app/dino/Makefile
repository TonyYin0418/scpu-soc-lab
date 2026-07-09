# Dino game 裸机构建脚本。
#
# 该脚本给已配置 RISC-V 交叉工具链的协作者使用；用户本机暂不要求运行。

CROSS ?= riscv64-unknown-elf-
CC      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump

BUILD_DIR := build
TARGET    := dino
OUT_COE   := ../../coe/app/dino/I_dino_game.coe

CFLAGS := -march=rv32i -mabi=ilp32 -O2 -Wall -Wextra \
          -ffreestanding -nostdlib -nostartfiles \
          -fno-builtin -fno-pic -mstrict-align \
          -Iinclude
LDFLAGS := -T linker.ld -Wl,--gc-sections -nostdlib

SRCS := $(wildcard src/*.c) $(wildcard src/*.S)
OBJS := $(patsubst src/%,$(BUILD_DIR)/%,$(SRCS))
OBJS := $(OBJS:.c=.o)
OBJS := $(OBJS:.S=.o)

.PHONY: all clean disasm

all: $(OUT_COE)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
	mkdir -p ../../coe/app/dino

$(BUILD_DIR)/%.o: src/%.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: src/%.S | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/$(TARGET).elf: $(OBJS) linker.ld
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS) -o $@

$(BUILD_DIR)/$(TARGET).bin: $(BUILD_DIR)/$(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(OUT_COE): $(BUILD_DIR)/$(TARGET).bin | $(BUILD_DIR)
	@echo "memory_initialization_radix=16;" > $@
	@echo "memory_initialization_vector=" >> $@
	@hexdump -v -e '1/4 "%08x\n"' $< | awk '{printf "%s%s", (NR>1 ? "," : ""), $$0} END {print ";";}' >> $@
	@echo "Generated $(OUT_COE)"

disasm: $(BUILD_DIR)/$(TARGET).elf
	$(OBJDUMP) -D -M no-aliases $< > $(BUILD_DIR)/$(TARGET).asm

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(OUT_COE)

