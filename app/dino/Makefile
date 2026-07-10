# Dino game RV32I 裸机构建脚本。
#
# 默认优先使用 riscv64-unknown-elf-gcc；未安装 GNU 工具链时，自动使用
# Homebrew LLVM + LLD。可用 TOOLCHAIN=gnu/llvm 显式选择。

TOOLCHAIN ?= auto
CROSS     ?= riscv64-unknown-elf-

GNU_CC      := $(shell command -v $(CROSS)gcc 2>/dev/null)
LLVM_PREFIX ?= $(shell brew --prefix llvm 2>/dev/null)
LLD_PREFIX  ?= $(shell brew --prefix lld 2>/dev/null)

ifeq ($(TOOLCHAIN),auto)
ifneq ($(GNU_CC),)
TOOLCHAIN := gnu
else
TOOLCHAIN := llvm
endif
endif

ifeq ($(TOOLCHAIN),gnu)
CC      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
READELF := $(CROSS)readelf
SIZE    := $(CROSS)size
TARGET_FLAGS :=
LINKER_FLAGS :=
else ifeq ($(TOOLCHAIN),llvm)
CC      := $(LLVM_PREFIX)/bin/clang
OBJCOPY := $(LLVM_PREFIX)/bin/llvm-objcopy
OBJDUMP := $(LLVM_PREFIX)/bin/llvm-objdump
READELF := $(LLVM_PREFIX)/bin/llvm-readelf
SIZE    := $(LLVM_PREFIX)/bin/llvm-size
TARGET_FLAGS := --target=riscv32-unknown-elf
LINKER_FLAGS := --ld-path=$(LLD_PREFIX)/bin/ld.lld
else
$(error TOOLCHAIN must be auto, gnu, or llvm)
endif

BUILD_DIR := build
TARGET    := dino
OUT_COE   := ../../coe/app/dino/I_dino_game.coe

ARCH_FLAGS := -march=rv32i -mabi=ilp32
COMMON_FLAGS := $(TARGET_FLAGS) $(ARCH_FLAGS) -O2 -Wall -Wextra \
                -ffreestanding -fno-builtin -fno-pic -mstrict-align \
                -fno-stack-protector -fno-unwind-tables \
                -fno-asynchronous-unwind-tables -ffunction-sections \
                -fdata-sections -Iinclude
CFLAGS  := $(COMMON_FLAGS)
ASFLAGS := $(COMMON_FLAGS)
LDFLAGS := $(TARGET_FLAGS) $(LINKER_FLAGS) $(ARCH_FLAGS) -nostdlib \
           -nostartfiles -T linker.ld -Wl,--gc-sections -Wl,--no-relax

SRCS := $(wildcard src/*.c) $(wildcard src/*.S)
OBJS := $(patsubst src/%,$(BUILD_DIR)/%,$(SRCS))
OBJS := $(OBJS:.c=.o)
OBJS := $(OBJS:.S=.o)

SMOKE_SRC := tests/toolchain_smoke.S
SMOKE_OBJ := $(BUILD_DIR)/toolchain_smoke.o
SMOKE_ELF := $(BUILD_DIR)/toolchain_smoke.elf
SMOKE_BIN := $(BUILD_DIR)/toolchain_smoke.bin
SMOKE_ASM := $(BUILD_DIR)/toolchain_smoke.asm

.PHONY: all clean disasm toolchain-info toolchain-check

all: $(OUT_COE) disasm

toolchain-info:
	@echo "TOOLCHAIN=$(TOOLCHAIN)"
	@echo "CC=$(CC)"
	@echo "LINKER=$(if $(LINKER_FLAGS),$(LLD_PREFIX)/bin/ld.lld,$(CC))"
	@echo "OBJCOPY=$(OBJCOPY)"
	@echo "OBJDUMP=$(OBJDUMP)"

toolchain-check: toolchain-info $(SMOKE_ELF)
	$(OBJCOPY) -O binary $(SMOKE_ELF) $(SMOKE_BIN)
	$(OBJDUMP) -d -M no-aliases $(SMOKE_ELF) > $(SMOKE_ASM)
	$(READELF) -h $(SMOKE_ELF) | grep -E 'Class:|Data:|Machine:|Entry point'
	$(SIZE) $(SMOKE_ELF)
	@echo "RV32I toolchain check passed"

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
	mkdir -p ../../coe/app/dino

$(SMOKE_OBJ): $(SMOKE_SRC) | $(BUILD_DIR)
	$(CC) $(ASFLAGS) -c $< -o $@

$(SMOKE_ELF): $(SMOKE_OBJ) linker.ld
	$(CC) $(LDFLAGS) $< -o $@

$(BUILD_DIR)/%.o: src/%.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: src/%.S | $(BUILD_DIR)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD_DIR)/$(TARGET).elf: $(OBJS) linker.ld
	@test -n "$(OBJS)" || { echo "error: add src/crt0.S and application sources before make"; exit 1; }
	$(CC) $(LDFLAGS) $(OBJS) -o $@

$(BUILD_DIR)/$(TARGET).bin: $(BUILD_DIR)/$(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(OUT_COE): $(BUILD_DIR)/$(TARGET).bin | $(BUILD_DIR)
	@echo "memory_initialization_radix=16;" > $@
	@echo "memory_initialization_vector=" >> $@
	@hexdump -v -e '1/4 "%08x\n"' $< | awk '{printf "%s%s", (NR>1 ? "," : ""), $$0} END {print ";";}' >> $@
	@echo "Generated $(OUT_COE)"

disasm: $(BUILD_DIR)/$(TARGET).elf
	$(OBJDUMP) -d -M no-aliases $< > $(BUILD_DIR)/$(TARGET).asm

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(OUT_COE)
