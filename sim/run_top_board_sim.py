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
