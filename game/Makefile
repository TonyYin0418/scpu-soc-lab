# 恐龙游戏构建：C + start.S -> ELF -> I_dino.coe（指令 ROM）+ D_dino.coe（数据 RAM）
#
# 本地 Homebrew 工具链：make PREFIX=riscv64-elf-
# 教程/Linux 工具链：   make PREFIX=riscv64-unknown-elf-

PREFIX ?= riscv64-unknown-elf-
CC      = $(PREFIX)gcc
OBJCOPY = $(PREFIX)objcopy
OBJDUMP = $(PREFIX)objdump
SIZE    = $(PREFIX)size

# rv32i：无 M 扩展，禁跳转表/gp 小数据，避免依赖未初始化的 gp 和 ROM 内 rodata
CFLAGS  = -march=rv32i -mabi=ilp32 -O1 -Wall -Wextra \
          -ffreestanding -fno-jump-tables -msmall-data-limit=0 -mno-relax
LDFLAGS = -nostdlib -T linker.ld -Wl,--no-warn-rwx-segments

BUILD = build
ELF   = $(BUILD)/dino.elf
IBIN  = $(BUILD)/dino_text.bin
DBIN  = $(BUILD)/dino_data.bin
ICOE  = I_dino.coe
DCOE  = D_dino.coe

all: $(ICOE) $(DCOE) $(BUILD)/dino.asm size-check

$(BUILD):
	mkdir -p $(BUILD)

$(ELF): start.S game.c linker.ld | $(BUILD)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ start.S game.c

$(IBIN): $(ELF)
	$(OBJCOPY) -O binary --only-section=.text $< $@

$(DBIN): $(ELF)
	$(OBJCOPY) -O binary --only-section=.rodata --only-section=.data $< $@

# bin -> COE（与 asm2coe 相同格式）
define BIN2COE
	@echo "MEMORY_INITIALIZATION_RADIX=16;" > $@
	@echo "MEMORY_INITIALIZATION_VECTOR=" >> $@
	@hexdump -v -e '1/4 "%08x\n"' $< | awk '{printf "%s%s", (NR>1 ? "," : ""), $$0} END {print ";";}' >> $@
endef

$(ICOE): $(IBIN)
	$(BIN2COE)
	@echo "COE generated: $@"

$(DCOE): $(DBIN)
	$(BIN2COE)
	@echo "COE generated: $@"

$(BUILD)/dino.asm: $(ELF)
	$(OBJDUMP) -D -M no-aliases $< > $@

# ROM_D / RAM_B 各 4KB；超限直接报错，防止悄悄截断
size-check: $(IBIN) $(DBIN)
	@ISZ=$$(wc -c < $(IBIN)); DSZ=$$(wc -c < $(DBIN)); \
	echo "text: $$ISZ bytes / 4096, data: $$DSZ bytes / 4096"; \
	[ $$ISZ -le 4096 ] && [ $$DSZ -le 4096 ] || { echo "SIZE OVERFLOW"; exit 1; }

install: all
	cp $(ICOE) ../coe/board/I_dino.coe
	cp $(DCOE) ../coe/board/D_dino.coe

clean:
	rm -rf $(BUILD) $(ICOE) $(DCOE)

.PHONY: all clean install size-check
