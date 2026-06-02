# PocketCPC Core Package

This directory contains the Pocket package template metadata and static assets
for PocketCPC.

## Contents

- `src/fpga/apf/`: generic APF wrapper support copied from the Pocket ZX
  Spectrum reference core.
- `src/fpga/core/core_top.sv`: main Pocket-facing integration layer for clocks,
  reset, video, audio, controls, ROM loading, and media loading.
- `src/fpga/core/pocket_bridge_regs.sv`: small custom Pocket bridge register
  block.
- `src/fpga/ap_core.qsf`: trimmed Quartus project source list. It should not
  include unrelated machine HDL.
- `Cores/`, `Platforms/`, `Assets/`: openFPGA package metadata and runtime
  asset layout.

## Build Entry Point

Build from the repository root with:

```bash
make build
```

The Docker build uses `raetro/quartus:18.1` by default, compiles from a synced
workspace under `build/quartus/`, and stages the finished installable package
under `build/package/`.

`src/fpga/ap_core.qpf` remains the source-of-truth Quartus project definition,
but Quartus should write its generated files only under `build/quartus/` via
`make build`.

The packaged bitstream ends up at
`build/package/Cores/stilvoid.PocketCPC/bitstream.rbf_r`, reversed from
Quartus' `build/quartus/output_files/ap_core.rbf` into the Pocket's `_rbf_r`
format.
