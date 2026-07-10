#!/usr/bin/env python3
"""Run board/top.v level simulation from COE files.

Example:
    python3 sim/run_top_board_sim.py \
        --imem coe/board/I_testac.coe \
        --dmem coe/board/D_mem.coe \
        --sw 0000 \
        --max-cycles 200000
"""

from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"


def coe_to_dat(coe_path: Path, dat_path: Path) -> int:
    text = coe_path.read_text(encoding="utf-8", errors="ignore")

    # Drop line comments that start with ';'. COE examples in this project use
    # ';xxx.asm' as the first-line comment.
    cleaned_lines: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith(";"):
            continue
        cleaned_lines.append(line)
    cleaned = "\n".join(cleaned_lines)

    match = re.search(
        r"memory_initialization_vector\s*=\s*(.*?);",
        cleaned,
        flags=re.IGNORECASE | re.DOTALL,
    )
    if not match:
        raise ValueError(f"cannot find memory_initialization_vector in {coe_path}")

    values = [
        token.strip()
        for token in re.split(r"[,\s]+", match.group(1))
        if token.strip()
    ]
    if not values:
        raise ValueError(f"empty memory_initialization_vector in {coe_path}")

    dat_path.parent.mkdir(parents=True, exist_ok=True)
    dat_path.write_text("\n".join(values) + "\n", encoding="ascii")
    return len(values)


def run(cmd: list[str]) -> None:
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=ROOT, check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Run board top simulation from COE files.")
    parser.add_argument("--imem", required=True, help="instruction ROM .coe file")
    parser.add_argument("--dmem", help="optional data RAM .coe file")
    parser.add_argument("--sw", default="0000", help="initial switch value, hex; default 0000")
    parser.add_argument("--max-cycles", type=int, default=200000)
    parser.add_argument("--out", default="build/top_board_simv", help="iverilog output path")
    parser.add_argument("--dump-vcd", action="store_true", help="dump build/top_board_tb.vcd")
    parser.add_argument("--check-vga", action="store_true", help="check VGA green test path; use --sw 8000")
    parser.add_argument("--check-vga-text", action="store_true", help="check CPU writes OK into VGA text MMIO")
    parser.add_argument("--check-dino-ready", action="store_true", help="check game reaches READY with custom dino tiles")
    parser.add_argument("--check-dino-tick", action="store_true", help="check game timer interrupt advances the first frame")
    parser.add_argument("--force-int-start", type=int, help="force timer INT high at this top_tb cycle")
    parser.add_argument("--force-int-end", type=int, help="release forced timer INT at this top_tb cycle")
    parser.add_argument("--send-ps2-key", help="send a PS/2 scan code byte in top simulation, hex")
    args = parser.parse_args()

    imem_coe = (ROOT / args.imem).resolve()
    dmem_coe = (ROOT / args.dmem).resolve() if args.dmem else None
    imem_dat = BUILD / "top_imem.dat"
    dmem_dat = BUILD / "top_dmem.dat"

    imem_words = coe_to_dat(imem_coe, imem_dat)
    print(f"[coe] {imem_coe.relative_to(ROOT)} -> {imem_dat.relative_to(ROOT)} ({imem_words} words)", flush=True)

    vvp_args = [
        f"+IMEM={imem_dat.as_posix()}",
        f"+IMEM_WORDS={imem_words}",
        f"+SW={args.sw}",
        f"+MAX_CYCLES={args.max_cycles}",
    ]
    if dmem_coe:
        dmem_words = coe_to_dat(dmem_coe, dmem_dat)
        print(f"[coe] {dmem_coe.relative_to(ROOT)} -> {dmem_dat.relative_to(ROOT)} ({dmem_words} words)", flush=True)
        vvp_args.append(f"+DMEM={dmem_dat.as_posix()}")
        vvp_args.append(f"+DMEM_WORDS={dmem_words}")
    if args.dump_vcd:
        vvp_args.append("+DUMP_VCD")
    if args.check_vga:
        vvp_args.append("+CHECK_VGA_GREEN")
    if args.check_vga_text:
        vvp_args.append("+CHECK_VGA_TEXT")
    if args.check_dino_ready:
        vvp_args.append("+CHECK_DINO_READY")
    if args.check_dino_tick:
        vvp_args.append("+CHECK_DINO_TICK")
    if args.force_int_start is not None:
        vvp_args.append(f"+FORCE_INT_START={args.force_int_start}")
    if args.force_int_end is not None:
        vvp_args.append(f"+FORCE_INT_END={args.force_int_end}")
    if args.send_ps2_key is not None:
        vvp_args.append(f"+SEND_PS2_KEY={args.send_ps2_key}")

    out_path = ROOT / args.out
    run([
        "iverilog",
        "-g2012",
        "-Wall",
        "-s",
        "top_board_tb",
        "-o",
        out_path.as_posix(),
        "-f",
        "top_board_sim_files.f",
    ])
    run(["vvp", "-n", out_path.as_posix(), *vvp_args])


if __name__ == "__main__":
    main()
