#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CORE_JSON = ROOT / "src" / "pocket" / "Cores" / "stilvoid.PocketCPC" / "core.json"


def run_git(*args: str, fallback: str) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(ROOT), *args],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return fallback


def describe_version() -> str:
    describe = run_git(
        "describe",
        "--tags",
        "--always",
        "--match",
        "v*",
        fallback=run_git("rev-parse", "--short", "HEAD", fallback="unknown"),
    )
    return describe[1:] if describe.startswith("v") else describe


def release_date() -> str:
    return run_git(
        "log",
        "-1",
        "--date=format:%Y-%m-%d",
        "--format=%cd",
        "HEAD",
        fallback="1970-01-01",
    )


def core_json_path() -> Path:
    if len(sys.argv) > 2:
        raise SystemExit("usage: update_core_metadata.py [core.json]")
    if len(sys.argv) == 2:
        return Path(sys.argv[1]).resolve()
    return DEFAULT_CORE_JSON


def main() -> int:
    core_json = core_json_path()
    data = json.loads(core_json.read_text())
    metadata = data["core"]["metadata"]
    version = describe_version()
    date_release = release_date()

    changed = False
    if metadata.get("version") != version:
        metadata["version"] = version
        changed = True
    if metadata.get("date_release") != date_release:
        metadata["date_release"] = date_release
        changed = True

    if changed:
        core_json.write_text(json.dumps(data, indent=2) + "\n")

    print(f"version={metadata.get('version')}")
    print(f"date_release={date_release}")
    print(f"updated={'yes' if changed else 'no'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
