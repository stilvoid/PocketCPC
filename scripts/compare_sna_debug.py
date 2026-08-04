#!/usr/bin/env python3
"""Compare savestate debug words from a Pocket log against a known-good .sna.

This expects a build that emits the first staged savestate words immediately
after an `SSLE` or `SSOK` event marker in the Pocket device log.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


EVENT_RE = re.compile(r"Event Log .*?\[0x([0-9A-Fa-f]{8})\]")
MARKERS = {
    "SSLE": 0x53534C45,
    "SSOK": 0x53534F4B,
}


def read_sna_words(path: Path, count: int) -> list[int]:
    data = path.read_bytes()
    needed = count * 4
    if len(data) < needed:
        raise ValueError(
            f"{path} is only {len(data)} bytes, need at least {needed} bytes "
            f"for {count} 32-bit words"
        )
    return [int.from_bytes(data[i * 4 : (i + 1) * 4], "big") for i in range(count)]


def read_log_events(path: Path) -> list[int]:
    events: list[int] = []
    for line in path.read_text(errors="replace").splitlines():
        match = EVENT_RE.search(line)
        if match:
            events.append(int(match.group(1), 16))
    return events


def extract_last_payload(events: list[int], count: int, marker_name: str) -> tuple[str, list[int]]:
    wanted = None if marker_name == "auto" else MARKERS[marker_name]
    for index in range(len(events) - 1, -1, -1):
        if wanted is None:
            matched = next((name for name, marker in MARKERS.items() if events[index] == marker), None)
        else:
            matched = marker_name if events[index] == wanted else None
        if matched is not None:
            payload = events[index + 1 : index + 1 + count]
            if len(payload) < count:
                raise ValueError(
                    f"found {matched} marker but only {len(payload)} payload words follow it"
                )
            return matched, payload
    raise ValueError(f"no {marker_name if marker_name != 'auto' else 'SSLE/SSOK'} marker found in the log")


def format_word(word: int) -> str:
    return f"0x{word:08X}"


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Compare the first staged savestate words reported in a Pocket log "
            "against the first words of a known-good CPC .sna fixture."
        )
    )
    parser.add_argument("--sna", required=True, type=Path, help="fixture .sna path")
    parser.add_argument("--log", required=True, type=Path, help="Pocket device log path")
    parser.add_argument(
        "--count",
        type=int,
        default=4,
        help="number of staged words to compare after the event marker (default: 4)",
    )
    parser.add_argument(
        "--marker",
        choices=["auto", *MARKERS.keys()],
        default="auto",
        help="event marker to inspect; auto uses the latest SSLE or SSOK burst",
    )
    args = parser.parse_args()

    if args.count <= 0:
        parser.error("--count must be positive")

    expected = read_sna_words(args.sna, args.count)
    marker, actual = extract_last_payload(read_log_events(args.log), args.count, args.marker)

    print(f"SNA: {args.sna}")
    print(f"Log: {args.log}")
    print(f"Comparing first {args.count} staged words after {marker}")
    print()

    mismatches = 0
    for index, (exp, act) in enumerate(zip(expected, actual)):
        status = "OK" if exp == act else "MISMATCH"
        if exp != act:
            mismatches += 1
        print(
            f"word {index:>2}: expected {format_word(exp)}  "
            f"actual {format_word(act)}  {status}"
        )

    print()
    if mismatches:
        print(f"{mismatches} mismatches found.")
        return 1

    print("All compared words match.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(2)
