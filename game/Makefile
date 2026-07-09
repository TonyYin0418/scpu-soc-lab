CROSS ?= riscv64-elf-
CC := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump

BUILD_DIR := build
TARGET := game

ELF := $(BUILD_DIR)/$(TARGET).elf
BIN := $(BUILD_DIR)/$(TARGET).bin
COE := $(BUILD_DIR)/$(TARGET).coe
BOARD_COE := ../coe/board/I_dino_game.coe
DISASM := $(BUILD_DIR)/$(TARGET).disasm
MCODE := $(BUILD_DIR)/$(TARGET).mcode.txt

CFLAGS := \
	-march=rv32i \
	-mabi=ilp32 \
	-O2 \
	-ffreestanding \
	-fno-builtin \
	-fno-pic \
	-fno-jump-tables \
	-fno-stack-protector \
	-fno-asynchronous-unwind-tables \
	-msmall-data-limit=0 \
	-Wall \
	-Wextra \
	-Werror

LDFLAGS := \
	-T linker.ld \
	-nostdlib \
	-nostartfiles \
	-Wl,--no-relax \
	-Wl,-Map=$(BUILD_DIR)/$(TARGET).map

SRCS := start.S game.c

.PHONY: all clean dump disasm install-coe

all: $(COE) $(MCODE) $(DISASM)

$(BUILD_DIR):
	mkdir -p $@

$(ELF): $(SRCS) linker.ld | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) $(SRCS) -o $@

$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

$(COE): $(BIN)
	@echo "MEMORY_INITIALIZATION_RADIX=16;" > $@
	@echo "MEMORY_INITIALIZATION_VECTOR=" >> $@
	@hexdump -v -e '1/4 "%08x\n"' $< | awk '{printf "%s%s", (NR>1 ? "," : ""), $$0} END {print ";";}' >> $@
	@echo "COE file generated: $@"

$(MCODE): $(BIN)
	@hexdump -v -e '1/4 "%08x\n"' $< > $@
	@echo "Machine code saved to $@"

$(DISASM): $(ELF)
	$(OBJDUMP) -D -M no-aliases $< > $@
	@echo "Disassembly saved to $@"

dump: $(MCODE)
	@cat $(MCODE)

disasm: $(DISASM)

install-coe: $(COE)
	cp $(COE) $(BOARD_COE)
	@echo "Installed board COE: $(BOARD_COE)"

clean:
	rm -rf $(BUILD_DIR)
