#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKELETON = ROOT / "src" / "apf_amstrad_skeleton"
FPGA = SKELETON / "src" / "fpga"

REQUIRED_FILES = [
    FPGA / "ap_core.qpf",
    FPGA / "ap_core.qsf",
    FPGA / "apf" / "apf.qip",
    FPGA / "apf" / "apf_top.v",
    FPGA / "core" / "core_top.sv",
    FPGA / "core" / "core_bridge_cmd.v",
    FPGA / "core" / "core_constraints.sdc",
    FPGA / "core" / "cpc_pll.v",
    FPGA / "core" / "cpc_pll_0002.v",
    FPGA / "core" / "cpc_pocket_input.sv",
    FPGA / "core" / "dpram.v",
    FPGA / "core" / "pocket_dataslot_loader.sv",
    FPGA / "core" / "pocket_bridge_regs.sv",
    FPGA / "cpc" / "cpc_machine_pocket.sv",
    FPGA / "cpc" / "cpc_ram_rom.sv",
    FPGA / "cpc" / "color_mix.sv",
    FPGA / "cpc" / "Amstrad_motherboard.v",
    FPGA / "cpc" / "Amstrad_MMU.v",
    FPGA / "cpc" / "UM6845R.v",
    FPGA / "cpc" / "i8255.v",
    FPGA / "cpc" / "YM2149.sv",
    FPGA / "cpc" / "crt_filter.v",
    FPGA / "cpc" / "hid.sv",
    FPGA / "cpc" / "T80" / "T80.qip",
    FPGA / "cpc" / "GA40010" / "ga40010.qip",
    SKELETON / "Platforms" / "amstrad.json",
    SKELETON / "Cores" / "steve.AmstradCPC" / "core.json",
    SKELETON / "Cores" / "steve.AmstradCPC" / "data.json",
    SKELETON / "Cores" / "steve.AmstradCPC" / "input.json",
    SKELETON / "Cores" / "steve.AmstradCPC" / "video.json",
    SKELETON / "Cores" / "steve.AmstradCPC" / "audio.json",
    SKELETON / "Cores" / "steve.AmstradCPC" / "bitstream.rbf_r",
    ROOT / "docs" / "CPC_IMPORT_MANIFEST.md",
]

ALLOWED_QSF_SOURCES = {
    "apf/apf.qip",
    "cpc/T80/T80.qip",
    "cpc/GA40010/ga40010.qip",
    "cpc/cpc_machine_pocket.sv",
    "cpc/cpc_ram_rom.sv",
    "cpc/color_mix.sv",
    "cpc/Amstrad_motherboard.v",
    "cpc/Amstrad_MMU.v",
    "cpc/UM6845R.v",
    "cpc/i8255.v",
    "cpc/YM2149.sv",
    "cpc/crt_filter.v",
    "cpc/hid.sv",
    "core/dpram.v",
    "core/cpc_pll.v",
    "core/cpc_pll_0002.v",
    "core/cpc_pocket_input.sv",
    "core/core_top.sv",
    "core/core_bridge_cmd.v",
    "core/pocket_dataslot_loader.sv",
    "core/pocket_bridge_regs.sv",
}


def fail(message: str) -> None:
    print(f"ERROR: {message}")
    sys.exit(1)


def main() -> None:
    missing = [path for path in REQUIRED_FILES if not path.exists()]
    if missing:
        for path in missing:
            print(f"Missing: {path.relative_to(ROOT)}")
        fail("required skeleton files are missing")

    for path in SKELETON.rglob("*.json"):
        try:
            json.loads(path.read_text())
        except json.JSONDecodeError as exc:
            fail(f"invalid JSON in {path.relative_to(ROOT)}: {exc}")

    qsf = (FPGA / "ap_core.qsf").read_text()
    source_pattern = re.compile(
        r"^set_global_assignment -name "
        r"(?:SYSTEMVERILOG_FILE|VERILOG_FILE|VHDL_FILE|QIP_FILE|SDC_FILE|MISC_FILE) "
        r"(.+)$",
        re.MULTILINE,
    )
    sources = {match.group(1).strip() for match in source_pattern.finditer(qsf)}
    unexpected = sorted(sources - ALLOWED_QSF_SOURCES)
    if unexpected:
        for source in unexpected:
            print(f"Unexpected active QSF source: {source}")
        fail("unexpected active source files in skeleton project")

    spectrum_terms = re.compile(r"\b(?:ZX|Spectrum|zxspectrum|ula|divmmc|wd1793)\b", re.IGNORECASE)
    searchable_files = [
        FPGA / "ap_core.qsf",
        *list((SKELETON / "Cores").rglob("*.json")),
        *list((SKELETON / "Platforms").rglob("*.json")),
    ]
    for path in searchable_files:
        text = path.read_text()
        if spectrum_terms.search(text):
            fail(f"unexpected Spectrum reference in {path.relative_to(ROOT)}")

    bitstream = (SKELETON / "Cores" / "steve.AmstradCPC" / "bitstream.rbf_r").read_bytes()
    first_payload = next((byte for byte in bitstream if byte != 0xFF), None)
    if first_payload == 0x6A:
        fail("bitstream.rbf_r appears to be raw RBF data; run scripts/reverse_rbf_bits.py")
    if first_payload != 0x56:
        fail(f"unexpected first non-0xff bitstream byte: 0x{first_payload:02x}")

    print("APF Amstrad skeleton checks passed.")


if __name__ == "__main__":
    main()
