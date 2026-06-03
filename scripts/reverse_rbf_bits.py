#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


REVERSE_BYTE = bytes(int(f"{value:08b}"[::-1], 2) for value in range(256))


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: reverse_rbf_bits.py <input.rbf> <output.rbf_r>", file=sys.stderr)
        return 2

    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])

    data = src.read_bytes()
    dst.write_bytes(bytes(REVERSE_BYTE[value] for value in data))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
