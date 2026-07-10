#!/usr/bin/env python3
"""Convert a little-endian raw binary into a 32-bit Xilinx COE image."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--prefix-bytes", type=int, default=0)
    args = parser.parse_args()

    if args.prefix_bytes < 0 or args.prefix_bytes % 4 != 0:
        raise SystemExit("--prefix-bytes must be a non-negative multiple of four")

    data = bytes(args.prefix_bytes) + args.input.read_bytes()
    if len(data) % 4:
        data += bytes(4 - (len(data) % 4))

    words = [
        int.from_bytes(data[offset : offset + 4], "little")
        for offset in range(0, len(data), 4)
    ]
    if not words:
        words = [0]

    args.output.parent.mkdir(parents=True, exist_ok=True)
    body = ",\n".join(f"{word:08X}" for word in words)
    args.output.write_text(
        "memory_initialization_radix=16;\n"
        "memory_initialization_vector=\n"
        f"{body};\n",
        encoding="ascii",
    )
    print(f"Generated {args.output} ({len(words)} words)")


if __name__ == "__main__":
    main()
