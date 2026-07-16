#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD_ROOT = ROOT / os.environ.get("POCKETCPC_BUILD_ROOT", "build")
CORE_ID = os.environ.get("POCKETCPC_CORE_ID", "stilvoid.PocketCPC")
OUTPUT_DIR = BUILD_ROOT / "quartus" / "output_files"
CORE_DIR = BUILD_ROOT / "package" / "Cores" / CORE_ID


@dataclass(frozen=True)
class TimingEntry:
    metric: str
    corner: str
    clock: str
    slack: float
    tns: float


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError as exc:
        raise SystemExit(f"Missing build artifact: {path}\nRun `make build` first.") from exc


def parse_key_value_file(path: Path, separator: str) -> dict[str, str]:
    values: dict[str, str] = {}

    for raw_line in read_text(path).splitlines():
        if separator not in raw_line:
            continue
        key, value = raw_line.split(separator, 1)
        values[key.strip()] = value.strip()

    return values


def parse_tool_counts(path: Path) -> tuple[int, int]:
    report_text = read_text(path)
    match = re.search(
        r"Info:\s+Quartus Prime .* was (?:un)?successful\. (\d+) errors?, (\d+) warnings?",
        report_text,
    )
    if not match:
        raise SystemExit(f"Could not parse Quartus message counts from {path}")

    return int(match.group(1)), int(match.group(2))


def parse_timing_entries(path: Path) -> list[TimingEntry]:
    entries: list[TimingEntry] = []
    current_type: tuple[str, str, str] | None = None
    current_slack: float | None = None

    type_pattern = re.compile(
        r"^Type\s*:\s*(.*?) Model (Setup|Hold|Recovery|Removal|Minimum Pulse Width) '(.*)'$"
    )
    number_pattern = re.compile(r"^-?\d+(?:\.\d+)?$")

    for raw_line in read_text(path).splitlines():
        line = raw_line.strip()

        type_match = type_pattern.match(line)
        if type_match:
            current_type = (
                type_match.group(1).strip(),
                type_match.group(2).strip(),
                type_match.group(3).strip(),
            )
            current_slack = None
            continue

        if current_type is None:
            continue

        if line.startswith("Slack :"):
            slack_text = line.split(":", 1)[1].strip()
            if not number_pattern.match(slack_text):
                raise SystemExit(f"Could not parse slack value in {path}: {line}")
            current_slack = float(slack_text)
            continue

        if line.startswith("TNS   :"):
            tns_text = line.split(":", 1)[1].strip()
            if current_slack is None or not number_pattern.match(tns_text):
                raise SystemExit(f"Could not parse TNS value in {path}: {line}")

            corner, metric, clock = current_type
            entries.append(
                TimingEntry(
                    metric=metric,
                    corner=corner,
                    clock=clock,
                    slack=current_slack,
                    tns=float(tns_text),
                )
            )
            current_type = None
            current_slack = None

    if not entries:
        raise SystemExit(f"Could not find timing entries in {path}")

    return entries


def parse_flow_elapsed_times(path: Path) -> dict[str, str]:
    rows: dict[str, str] = {}
    wanted = {
        "Analysis & Synthesis": "synth",
        "Fitter": "fit",
        "Assembler": "asm",
        "Timing Analyzer": "sta",
        "Total": "total",
    }

    for raw_line in read_text(path).splitlines():
        if not raw_line.startswith(";"):
            continue

        parts = [part.strip() for part in raw_line.split(";")[1:-1]]
        if len(parts) < 2:
            continue

        label = parts[0]
        if label in wanted and re.match(r"^\d{2}:\d{2}:\d{2}$", parts[1]):
            rows[wanted[label]] = parts[1]

    return rows


def summarize_timing(entries: list[TimingEntry]) -> dict[str, TimingEntry]:
    metrics = {
        "Setup",
        "Hold",
        "Recovery",
        "Removal",
        "Minimum Pulse Width",
    }

    summary: dict[str, TimingEntry] = {}
    for metric in metrics:
        metric_entries = [entry for entry in entries if entry.metric == metric]
        if not metric_entries:
            continue
        summary[metric] = min(metric_entries, key=lambda entry: (entry.slack, entry.tns))

    return summary


def format_status(status: str) -> str:
    return " ".join(status.split())


def format_usage(summary: dict[str, str], key: str) -> str:
    return summary.get(key, "unknown")


def summarize_status(status: str) -> str:
    return "ok" if format_status(status).startswith("Successful") else format_status(status)


def shorten_clock_name(clock: str) -> str:
    if clock == "bridge_spiclk":
        return clock
    if clock in {"clk_74a", "clk_74b"}:
        return clock
    if clock.startswith("core_top:ic|"):
        return clock.removeprefix("core_top:ic|")
    if "cpc_audio_pll" in clock and "PLL_OUTPUT_COUNTER|divclk" in clock:
        return "audio_pll divclk"
    if "cpc_audio_pll" in clock and "FRACTIONAL_PLL|vcoph[0]" in clock:
        return "audio_pll vcoph0"
    if "cpc_pll_inst" in clock and "PLL_OUTPUT_COUNTER|divclk" in clock:
        return "cpc_pll divclk"
    if "cpc_pll_inst" in clock and "FRACTIONAL_PLL|vcoph[0]" in clock:
        return "cpc_pll vcoph0"
    if "|" in clock:
        return clock.split("|")[-1]
    return clock


def shorten_corner(corner: str) -> str:
    parts = corner.split()
    if len(parts) >= 3:
        return f"{parts[0]}/{parts[-1]}"
    return corner


def extract_percent(usage: str) -> str:
    match = re.search(r"\(\s*([0-9]+)\s*%\s*\)", usage)
    return f"{match.group(1)}%" if match else usage


def format_timing_entry(entry: TimingEntry) -> str:
    return (
        f"{entry.slack:.3f}ns @ {shorten_clock_name(entry.clock)} "
        f"({shorten_corner(entry.corner)})"
    )


def timing_has_failure(summary: dict[str, TimingEntry]) -> bool:
    for entry in summary.values():
        if entry.slack < 0 or entry.tns < 0:
            return True
    return False


def print_report(strict: bool) -> int:
    build_info = parse_key_value_file(CORE_DIR / "build-info.txt", "=")
    fit_summary = parse_key_value_file(OUTPUT_DIR / "ap_core.fit.summary", ":")
    timing_entries = parse_timing_entries(OUTPUT_DIR / "ap_core.sta.summary")
    flow_times = parse_flow_elapsed_times(OUTPUT_DIR / "ap_core.flow.rpt")
    timing_summary = summarize_timing(timing_entries)
    tool_counts = {
        "map": parse_tool_counts(OUTPUT_DIR / "ap_core.map.rpt"),
        "fit": parse_tool_counts(OUTPUT_DIR / "ap_core.fit.rpt"),
        "sta": parse_tool_counts(OUTPUT_DIR / "ap_core.sta.rpt"),
        "asm": parse_tool_counts(OUTPUT_DIR / "ap_core.asm.rpt"),
    }

    flow_text = read_text(OUTPUT_DIR / "ap_core.flow.rpt")
    flow_status_match = re.search(r";\s*Flow Status\s*;\s*(.*?)\s*;", flow_text)
    flow_status = flow_status_match.group(1) if flow_status_match else "unknown"
    timing_failed = timing_has_failure(timing_summary)

    print(
        "PocketCPC build report: "
        f"{build_info.get('core_version', 'unknown')} "
        f"{build_info.get('git_state', 'unknown')} "
        f"{build_info.get('build_timestamp_utc', 'unknown')}"
    )
    print(
        "status: "
        f"flow {summarize_status(flow_status)}, "
        f"fit {summarize_status(fit_summary.get('Fitter Status', 'unknown'))}, "
        f"timing {'FAIL' if timing_failed else 'PASS'}"
    )

    timing_parts = []
    for metric_name, label in (
        ("Setup", "setup"),
        ("Hold", "hold"),
        ("Minimum Pulse Width", "pulse"),
    ):
        entry = timing_summary.get(metric_name)
        if entry is not None:
            timing_parts.append(f"{label} {format_timing_entry(entry)}")

    for metric_name, label in (("Recovery", "recovery"), ("Removal", "removal")):
        entry = timing_summary.get(metric_name)
        if entry is not None and (entry.slack < 0 or entry.tns < 0):
            timing_parts.append(f"{label} {format_timing_entry(entry)}")

    if timing_parts:
        print(f"timing: {', '.join(timing_parts)}")

    print(
        "fit: "
        f"RAM blocks {format_usage(fit_summary, 'Total RAM Blocks')}, "
        f"RAM bits {extract_percent(format_usage(fit_summary, 'Total block memory bits'))}, "
        f"ALMs {extract_percent(format_usage(fit_summary, 'Logic utilization (in ALMs)'))}, "
        f"PLLs {extract_percent(format_usage(fit_summary, 'Total PLLs'))}"
    )

    elapsed_parts = [
        f"{label}={flow_times[label]}"
        for label in ("synth", "fit", "asm", "sta", "total")
        if label in flow_times
    ]
    if elapsed_parts:
        print(f"time: {', '.join(elapsed_parts)}")

    message_parts = []
    total_errors = 0
    total_warnings = 0
    for tool in ("map", "fit", "sta", "asm"):
        errors, warnings = tool_counts[tool]
        total_errors += errors
        total_warnings += warnings
        message_parts.append(f"{tool} {warnings}w")
    print(f"warnings: {total_warnings} total ({', '.join(message_parts)})")

    if strict and timing_failed:
        print("timing gate: report found a timing failure", file=sys.stderr)
        return 2

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Print a concise Quartus build report.")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="return non-zero if the timing summary shows any failure",
    )
    args = parser.parse_args()
    return print_report(strict=args.strict)


if __name__ == "__main__":
    raise SystemExit(main())
