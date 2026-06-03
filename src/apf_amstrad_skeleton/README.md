# Amstrad CPC APF Skeleton

This is the current Analogue Pocket/openFPGA starting point for the Amstrad CPC
port. It is a dummy APF core, not a CPC implementation yet.

## Contents

- `src/fpga/apf/`: generic APF wrapper support copied from the Pocket ZX
  Spectrum reference core.
- `src/fpga/core/core_top.sv`: Amstrad-facing dummy core with a 320x240 test
  pattern, silent audio, safe unused-interface tie-offs, and bridge register
  wiring.
- `src/fpga/core/pocket_bridge_regs.sv`: first Pocket bridge register block,
  replacing the future MiSTer `hps_io/status/ioctl` dependency.
- `src/fpga/ap_core.qsf`: trimmed Quartus project source list. It should not
  include Spectrum machine HDL.
- `Cores/`, `Platforms/`, `Assets/`: minimal openFPGA package metadata.

## Checks

From the repository root:

```bash
python3 scripts/check_expected_files.py
python3 scripts/check_skeleton.py
```

`check_skeleton.py` validates JSON, required skeleton files, and the active QSF
source list.

## Build Entry Point

Open or build `src/fpga/ap_core.qpf` with Quartus. The expected top-level entity
is `apf_top`.

You can also build with Docker from the repository root:

```bash
scripts/build_skeleton_docker.sh
```

The script uses `raetro/quartus:18.1` by default and writes
`Cores/steve.AmstradCPC/bitstream.rbf_r` from Quartus'
`src/fpga/output_files/ap_core.rbf`, reversing the bits in each byte for the
Pocket's `_rbf_r` bitstream format.

Current local result: Docker Quartus 18.1 full compile succeeds with 0 errors.
