# Game Cross-Compile Scaffold

This directory is for the software/game side of the FPGA dinosaur game.

The game targets the text-mode VGA and PS/2 MMIO contract from commit
`802d31b4add2b4f802060a72322341fd5a64a166`.

## Build

The Makefile uses `riscv64-elf-gcc` when installed and otherwise falls back to
Homebrew LLVM + LLD:

```bash
brew install llvm lld
```

Build the game:

```bash
cd game
make
```

Install the generated instruction image for board/Vivado use:

```bash
make install-coe
```

For an existing Vivado project, the interrupt build must use `rtl/SCPU.v` and
its RTL dependencies, not `edf/SCPU.edf`. Also replace `board/top.v`,
`IO/VGA/vga_text_renderer.v`, and `IO/VGA/vga_font_rom.v`; add
`IO/game_timer.v`; then refresh the instruction ROM from
`coe/board/I_dino_game.coe`. The C/assembly/linker and simulation files are not
Vivado Design Sources.

Outputs are written to `build/`:

- `game.elf`: linked RV32I bare-metal ELF
- `game.bin`: raw instruction image
- `game.coe`: Vivado instruction ROM initialization file
- `game.disasm`: disassembly for review
- `game.mcode.txt`: one 32-bit instruction word per line
- `../coe/board/I_dino_game.coe`: installed board instruction COE

`make` also runs mandatory gates: RV32I attributes, no unresolved symbols, no
M-extension opcodes, word alignment, and a strict 1024-word instruction-ROM
limit. Use `make toolchain-info` to see the selected compiler.

## Current MMIO Contract

```c
#define MMIO_VGA     0xC0000000u
#define MMIO_SEG7    0xE0000000u
#define MMIO_SW_BTN  0xE0000000u
#define MMIO_LED     0xF0000000u
#define MMIO_PS2_KEY 0xD0000000u
#define MMIO_PS2_LOG 0xD0000004u
#define MMIO_GAME_TIMER 0xFFFFFE00u
#define MMIO_INTMASK 0xFFFFFF00u
```

VGA is 80x60 text mode:

```c
addr = MMIO_VGA + (row * 80 + col) * 4;
data = (attr << 8) | ascii;
```

`MMIO_PS2_KEY` returns `{23'b0, ps2_ready, ps2_key}`. The game acknowledges
that register and uses `MMIO_PS2_LOG` as the stable event history. Make/break
and extended prefixes are tracked explicitly; unknown scan codes are ignored.
Space, W, and Up are jump keys, S and Down are held crouch keys, P toggles
pause, and R or Enter returns to the ready state.

## Game Scope

This is a text-mode Chrome-dino style runner:

- dino is fixed near the left side;
- cactus and low-flying bird obstacles scroll from right to left;
- Space/W/Up jumps;
- S/Down crouches on the ground and accelerates descent in the air;
- P pauses/resumes the run;
- collision shows `GAME OVER`;
- R/Enter/Space restarts;
- score is shown on VGA and seven-segment display.

The dinosaur, crouch pose, cactus, and bird use custom 8x8 pixel-art tiles in
`IO/VGA/vga_font_rom.v`; they are not approximated with printable characters.
The game has READY, RUNNING, PAUSED, and GAME OVER states. Crouching clears a
low bird but deliberately does not clear a cactus.

The main loop continuously polls PS/2, so break/extended sequences are not
hidden by a long blocking delay. A disabled-by-default hardware timer is
enabled through `MMIO_GAME_TIMER` and generates the 25 Hz frame interrupt. The
handler at the CPU's fixed `0x340` vector preserves all integer registers and
only publishes a pending tick; physics and rendering remain in the main loop.
Moving objects erase only their previous occupied cells instead of clearing a
five-row screen band every frame.

## Software Rules

- Target only RV32I: `-march=rv32i -mabi=ilp32`.
- Keep code freestanding: no libc, no OS calls, no `printf`.
- Avoid multiply/divide unless the CPU grows the M extension.
- Avoid string literals and initialized globals until the build flow emits a
  matching data RAM COE. The current program writes all visible text with
  immediate character constants, so it only needs an instruction ROM COE.
- Keep hardware access through `volatile` MMIO helpers.
- The linker rejects `.rodata` and initialized `.data`, because this Harvard
  SoC cannot read instruction-ROM constants through ordinary loads.
