# RV32I bare-metal game build. Prefer GNU riscv64-elf-gcc when available;
# otherwise use Homebrew LLVM + LLD.

TOOLCHAIN ?= auto
CROSS     ?= riscv64-elf-

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
NM      := $(CROSS)nm
SIZE    := $(CROSS)size
TARGET_FLAGS :=
LINKER_FLAGS :=
else ifeq ($(TOOLCHAIN),llvm)
CC      := $(LLVM_PREFIX)/bin/clang
OBJCOPY := $(LLVM_PREFIX)/bin/llvm-objcopy
OBJDUMP := $(LLVM_PREFIX)/bin/llvm-objdump
READELF := $(LLVM_PREFIX)/bin/llvm-readelf
NM      := $(LLVM_PREFIX)/bin/llvm-nm
SIZE    := $(LLVM_PREFIX)/bin/llvm-size
TARGET_FLAGS := --target=riscv32-unknown-elf
LINKER_FLAGS := --ld-path=$(LLD_PREFIX)/bin/ld.lld
else
$(error TOOLCHAIN must be auto, gnu, or llvm)
endif

BUILD_DIR := build
TARGET    := game

ELF       := $(BUILD_DIR)/$(TARGET).elf
BIN       := $(BUILD_DIR)/$(TARGET).bin
COE       := $(BUILD_DIR)/$(TARGET).coe
BOARD_COE := ../coe/board/I_dino_game.coe
DISASM    := $(BUILD_DIR)/$(TARGET).disasm
MCODE     := $(BUILD_DIR)/$(TARGET).mcode.txt

ARCH_FLAGS := -march=rv32i -mabi=ilp32
CFLAGS := $(TARGET_FLAGS) $(ARCH_FLAGS) -Os -ffreestanding -fno-builtin \
	-fno-pic -fno-jump-tables -fno-stack-protector \
	-fno-asynchronous-unwind-tables -fno-unwind-tables \
	-msmall-data-limit=0 -ffunction-sections -fdata-sections \
	-Wall -Wextra -Werror
LDFLAGS := $(TARGET_FLAGS) $(LINKER_FLAGS) $(ARCH_FLAGS) -T linker.ld \
	-nostdlib -nostartfiles -Wl,--gc-sections -Wl,--no-relax \
	-Wl,--no-check-sections -Wl,-Map=$(BUILD_DIR)/$(TARGET).map

SRCS := start.S game.c

.PHONY: all clean dump disasm install-coe verify toolchain-info

all: $(COE) $(MCODE) $(DISASM) verify

toolchain-info:
	@echo "TOOLCHAIN=$(TOOLCHAIN)"
	@echo "CC=$(CC)"
	@echo "LINKER=$(if $(LINKER_FLAGS),$(LLD_PREFIX)/bin/ld.lld,$(CC))"
	@echo "OBJCOPY=$(OBJCOPY)"
	@echo "OBJDUMP=$(OBJDUMP)"

$(BUILD_DIR):
	mkdir -p $@

$(ELF): $(SRCS) linker.ld | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) $(SRCS) -o $@

$(BIN): $(ELF)
	$(OBJCOPY) -O binary --only-section=.text $< $@

$(COE): $(BIN)
	@echo "MEMORY_INITIALIZATION_RADIX=16;" > $@
	@echo "MEMORY_INITIALIZATION_VECTOR=" >> $@
	@hexdump -v -e '1/4 "%08x\n"' $< | awk '{printf "%s%s", (NR>1 ? "," : ""), $$0} END {print ";";}' >> $@
	@echo "COE file generated: $@"

$(MCODE): $(BIN)
	@hexdump -v -e '1/4 "%08x\n"' $< > $@
	@echo "Machine code saved to $@"

$(DISASM): $(ELF)
	$(OBJDUMP) -d -M no-aliases $< > $@
	@echo "Disassembly saved to $@"

verify: $(ELF) $(BIN) $(DISASM)
	@undefined=`$(NM) -u $(ELF)`; \
	 test -z "$$undefined" || { echo "Undefined symbols:"; echo "$$undefined"; exit 1; }
	@$(READELF) -A $(ELF) | grep -q 'rv32i' || { echo "error: ELF is not RV32I"; exit 1; }
	@bytes=`wc -c < $(BIN)`; \
	 test $$bytes -le 4096 || { echo "error: instruction image $$bytes bytes exceeds 4096"; exit 1; }; \
	 test $$((bytes % 4)) -eq 0 || { echo "error: instruction image is not word aligned"; exit 1; }; \
	 echo "Instruction image: $$((bytes / 4)) / 1024 words"
	@if grep -Eq '[[:space:]](mul|mulh|mulhsu|mulhu|div|divu|rem|remu)[[:space:]]' $(DISASM); then \
	 echo "error: M-extension instruction found"; exit 1; fi
	$(SIZE) $(ELF)
	@echo "RV32I game verification passed"

dump: $(MCODE)
	@cat $(MCODE)

disasm: $(DISASM)

install-coe: all
	cp $(COE) $(BOARD_COE)
	@echo "Installed board COE: $(BOARD_COE)"

clean:
	rm -rf $(BUILD_DIR)
