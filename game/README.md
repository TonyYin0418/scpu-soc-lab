# Game Cross-Compile Scaffold

This directory is for the software/game side of the FPGA dinosaur game.

The game targets the text-mode VGA and PS/2 MMIO contract from commit
`802d31b4add2b4f802060a72322341fd5a64a166`.

## Build

Install the native macOS bare-metal RISC-V toolchain:

```bash
brew install riscv64-elf-gcc
```

Build the game:

```bash
cd my-app/game
make
```

Install the generated instruction image for board/Vivado use:

```bash
make install-coe
```

Outputs are written to `build/`:

- `game.elf`: linked RV32I bare-metal ELF
- `game.bin`: raw instruction image
- `game.coe`: Vivado instruction ROM initialization file
- `game.disasm`: disassembly for review
- `game.mcode.txt`: one 32-bit instruction word per line
- `../coe/board/I_dino_game.coe`: installed board instruction COE

## Current MMIO Contract

```c
#define MMIO_VGA     0xC0000000u
#define MMIO_SEG7    0xE0000000u
#define MMIO_SW_BTN  0xE0000000u
#define MMIO_LED     0xF0000000u
#define MMIO_PS2_KEY 0xD0000000u
#define MMIO_PS2_LOG 0xD0000004u
```

VGA is 80x60 text mode:

```c
addr = MMIO_VGA + (row * 80 + col) * 4;
data = (attr << 8) | ascii;
```

`MMIO_PS2_KEY` returns `{23'b0, ps2_ready, ps2_key}` on the current
PS/2 branch. The game treats Space, W, and Up as jump keys, and R or Enter as
restart keys.

## Game Scope

This is a text-mode Chrome-dino style runner:

- dino is fixed near the left side;
- cactus obstacles scroll from right to left;
- Space/W/Up jumps;
- collision shows `GAME OVER`;
- R/Enter/Space restarts;
- score is shown on VGA and seven-segment display.

## Software Rules

- Target only RV32I: `-march=rv32i -mabi=ilp32`.
- Keep code freestanding: no libc, no OS calls, no `printf`.
- Avoid multiply/divide unless the CPU grows the M extension.
- Avoid string literals and initialized globals until the build flow emits a
  matching data RAM COE. The current program writes all visible text with
  immediate character constants, so it only needs an instruction ROM COE.
- Keep hardware access through `volatile` MMIO helpers.
