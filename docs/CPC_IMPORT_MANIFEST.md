# CPC Import Manifest

This document records which active files in `src/fpga/cpc/` come
from the MiSTer Amstrad CPC core lineage and which files are local PocketCPC
adapter code around them.

Its purpose is provenance, not planning. When updating imported machine logic,
preserve upstream licence headers, keep diffs reviewable, and prefer adapting
the Pocket boundary around the machine rather than rewriting the machine itself.

## Primary upstream reference

- `upstreams/Amstrad_MiSTer/Amstrad.sv` is the main wiring reference for how
  the imported CPC machine pieces fit together.
- `upstreams/Amstrad_MiSTer/files.qip` is the broad source inventory reference.

## Imported MiSTer-derived files in active use

| Local path | Upstream source area | Role |
| --- | --- | --- |
| `cpc/Amstrad_motherboard.v` | `rtl/Amstrad_motherboard.v` | Main CPC motherboard integration. |
| `cpc/Amstrad_MMU.v` | `rtl/Amstrad_MMU.v` | CPC RAM and ROM banking. |
| `cpc/UM6845R.v` | `rtl/UM6845R.v` | CRTC implementation. |
| `cpc/i8255.v` | `rtl/i8255.v` | PPI and keyboard/PSG control path. |
| `cpc/YM2149.sv` | `rtl/YM2149.sv` | PSG audio. |
| `cpc/color_mix.sv` | `rtl/color_mix.sv` | CPC palette and color mixing. |
| `cpc/hid.sv` | `rtl/hid.sv` | Existing CPC HID and PS/2-style key-event handling. |
| `cpc/crt_filter.v` | `rtl/crt_filter.v` | Imported video helper retained for compatibility with the current machine tree. |
| `cpc/tzxplayer.vhd` | `rtl/tzxplayer.vhd` | Tape/CDT support block used by the early tape path. |
| `cpc/u765/u765.sv` | `rtl/u765/u765.sv` | Floppy disk controller. |
| `cpc/GA40010/*` | `rtl/GA40010/*` | Gate Array, timing, and video support. |
| `cpc/T80/*` | `rtl/T80/*` | Z80-compatible CPU core. |

## Local PocketCPC wrapper files

These files are not straight imports. They are the Pocket-facing adapter layer
around the imported machine pieces:

| Local path | Role |
| --- | --- |
| `cpc/cpc_machine_pocket.sv` | Wraps the imported CPC machine for Pocket clocks, reset, media, and I/O boundaries. |
| `cpc/cpc_ram_rom.sv` | Provides the ROM and RAM implementation expected by the imported motherboard while fitting PocketCPC resource/layout choices. |

## Intentionally not imported as active machine files

These MiSTer-side files remain references rather than active PocketCPC sources:

| Upstream path | Why it stays a reference |
| --- | --- |
| `Amstrad.sv` | Useful as a wiring/config reference, but PocketCPC does not instantiate the MiSTer top level directly. |
| `sys/hps_io.sv` | Replaced by APF bridge registers and data-slot handling. |
| `rtl/sdram.v` | PocketCPC uses its own memory wrappers and packaging assumptions instead of the MiSTer memory path directly. |
| MiSTer menu/UI files | Replaced by Pocket metadata, bridge-backed controls, and the Pocket-facing virtual keyboard. |
