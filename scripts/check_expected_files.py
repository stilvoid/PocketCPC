#!/usr/bin/env python3
from pathlib import Path
import sys

required = [
    "upstreams/Amstrad_MiSTer/Amstrad.sv",
    "upstreams/Amstrad_MiSTer/sys/hps_io.sv",
    "upstreams/OpenFPGA_ZX-Spectrum/src/fpga/apf/apf_top.v",
    "upstreams/OpenFPGA_ZX-Spectrum/src/fpga/core/core_top.sv",
    "upstreams/OpenFPGA_ZX-Spectrum/src/fpga/ap_core.qsf",
    "upstreams/OpenFPGA_ZX-Spectrum/README.md",
]

missing = [p for p in required if not Path(p).exists()]
if missing:
    print("Missing expected files:")
    for p in missing:
        print(f"  - {p}")
    sys.exit(1)

print("Expected upstream files found.")
