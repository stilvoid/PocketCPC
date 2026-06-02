# Licensing and Provenance

PocketCPC is a mixed-provenance repository.

It does not consist entirely of brand-new code written from scratch, and it is
not accurate to describe all of it as merely "inspired by" other projects.
This repository contains a mix of:

- files copied verbatim from upstream reference projects
- files copied and then adapted for PocketCPC
- new PocketCPC-specific glue, packaging, metadata, and documentation

Because of that, this repository should be treated as a mixed-license project,
not as a codebase covered cleanly by one single repo-wide license.

## Practical project policy

Unless a file header or nearby notice says otherwise, new PocketCPC-authored
files in this repository are intended to be available under:

- `GPL-3.0-or-later`

This applies to clearly original PocketCPC adapter-layer code, project docs,
and packaging/metadata written specifically for this repository.

It does **not** override preserved upstream notices, copied file headers, or
third-party license terms.

## Upstream provenance

PocketCPC was built primarily from two reference projects plus Analogue APF
support files:

- [MiSTer-devel/Amstrad_MiSTer](https://github.com/MiSTer-devel/Amstrad_MiSTer)
- [dave18/OpenFPGA_ZX-Spectrum](https://github.com/dave18/OpenFPGA_ZX-Spectrum)
- Analogue Pocket APF support files and terms referenced in file headers and the
  [Pocket EULA](https://www.analogue.link/pocket-eula)

## What is clearly copied

Some files in this repository are copied verbatim, or effectively verbatim,
from upstream sources. Examples include:

- `src/fpga/apf/apf_top.v`
- `src/fpga/apf/common.v`
- `src/fpga/apf/io_bridge_peripheral.v`
- `src/fpga/apf/io_pad_controller.v`
- `src/fpga/cpc/GA40010/casgen_sync.v`
- `src/fpga/cpc/GA40010/syncgen_sync.v`

Those files remain governed by their original headers and upstream terms.

## What is adapted

Many other files are not fresh clean-room reimplementations. They are adapted
from upstream code and retain upstream provenance even where they have been
modified locally. Examples include imported or adapted CPC machine files such as:

- `src/fpga/cpc/u765/u765.sv`
- `src/fpga/cpc/UM6845R.v`
- `src/fpga/cpc/i8255.v`
- `src/fpga/cpc/YM2149.sv`
- `src/fpga/cpc/Amstrad_MMU.v`
- `src/fpga/cpc/Amstrad_motherboard.v`
- `src/fpga/cpc/hid.sv`
- `src/fpga/cpc/color_mix.sv`
- `src/fpga/cpc/GA40010/ga40010.sv`
- `src/fpga/cpc/GA40010/video.sv`
- `src/fpga/core/sound_i2s.sv`
- `src/fpga/core/sync_fifo.sv`

For these files, the preserved file headers and upstream license notices control.

## What is original PocketCPC glue

The repository also contains PocketCPC-specific integration code written for the
boundary between the reference cores and the Pocket platform. Examples include:

- `src/fpga/core/pocket_bridge_regs.sv`
- `src/fpga/core/pocket_dataslot_loader.sv`
- `src/fpga/core/pocket_fdc_dataslot.sv`
- `src/fpga/core/pocket_tape_dataslot.sv`
- `src/fpga/core/pocket_sna_dataslot.sv`
- `src/fpga/core/pocket_sna_save_dataslot.sv`
- `src/fpga/core/cpc_pocket_input.sv`
- `src/fpga/core/cpc_virtual_keyboard_overlay.sv`

Unless one of those files later gains a different header, they should be
treated as `GPL-3.0-or-later`.

## Important caution about the ZX Pocket reference

At the time this note was written, the upstream
`dave18/OpenFPGA_ZX-Spectrum` repository did not provide a clear top-level
license file in the repository root that could be treated as a simple
repo-wide license grant.

That matters because some PocketCPC files were copied or adapted from that
reference. For those files, do not assume that a new top-level PocketCPC
license statement overrides the original provenance. Preserve the original file
headers and treat ambiguous cases conservatively.

## Bottom line

- This repository is **not** a clean-room codebase.
- It is **not** licensed purely as GPLv3 across every file.
- It contains GPL-family, MIT/BSD-style, and Analogue/APF-licensed material.
- Original PocketCPC-authored files are intended to be `GPL-3.0-or-later`
  unless stated otherwise.
- Copied and adapted upstream files remain subject to their original notices.

This file is a practical provenance summary for the project, not legal advice.
