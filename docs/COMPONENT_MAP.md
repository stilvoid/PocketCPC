# Component Map

This map is governed by `AGENTS.md`: reuse MiSTer Amstrad for CPC machine
behavior, reuse the ZX Spectrum Pocket core for APF/Pocket integration, and
keep new code to the adapter layer where those references meet.

## Use from OpenFPGA ZX Spectrum core

Use these as direct references or adaptation patterns where licence permits:

| Area | Source | Use |
| --- | --- | --- |
| `apf_top.v` style wrapper | `src/fpga/apf/apf_top.v` | Copy/adapt physical Pocket pins, scaler DDR output, bridge peripheral, controller plumbing. |
| `core_top.sv` APF signature | `src/fpga/core/core_top.sv` | Use port list shape for new Amstrad-facing top. |
| Quartus project shape | `src/fpga/ap_core.qsf`, SDC/IP files | Start from this project layout, then replace Spectrum source files with CPC source files. |
| Bridge register style | ZX core bridge usage | Implement CPC menu/register/file-slot commands using APF bridge. |
| Video output wrapper | ZX `core_top.sv` APF video section | Reuse registered `video_rgb`, `video_de`, `video_hs`, `video_vs`, scaler clock, and scaler metadata patterns. |
| Virtual keyboard | ZX core feature | Reuse concept and UI behavior, redesign matrix for CPC. |
| ROM bundle convention | ZX `boot.rom` README | Use same idea for CPC OS/BASIC/AMSDOS/MF2/464 ROM bundle. |
| Disk/tape lessons | ZX changelog and code | Useful for timing and Pocket media integration patterns, not direct CPC disk logic. |

## Use from MiSTer Amstrad core

| Area | Source | Use |
| --- | --- | --- |
| CPC machine | `rtl/`, top-level logic behind `Amstrad.sv` | Primary source of CPC behavior. |
| Model support | `Amstrad.sv` menu/model logic | Keep 6128/664/464 selection and reset-time apply behaviour aligned with MiSTer. |
| ROM loader mapping | `Amstrad.sv` `ioctl_*` handling | Re-express as APF asset-slot loader. |
| FDC/u765 + DSK | MiSTer media/disk subsystem | Keep core disk controller, replace MiSTer SD block transport. |
| Tape/CDT | MiSTer tape loader | Active early tape path. Preserve MiSTer tape behavior where practical and keep Pocket transport logic in the adapter layer. |
| Snapshot loader | MiSTer SNA handling | Active early snapshot-load path. Preserve MiSTer machine-state expectations while keeping APF streaming and save plumbing local. |
| CRTC/Gate Array/PPI/PSG | CPC HDL | Keep as-is where possible. |
| Video/audio signal generation | CPC HDL, especially `color_mix` and `Amstrad.sv` timing | Preserve CPC-side colour, timing, and audio generation; adapt output wrapper only. |

## Adapter-only local code

New PocketCPC HDL should usually live at these boundaries:

| Boundary | Local role |
| --- | --- |
| APF bridge/data slot to CPC host inputs | Translate Pocket commands/assets into MiSTer-style reset, ROM load, media, and config signals. |
| MiSTer CPC video to APF video | Preserve CPC colour/timing generation, then register/clock it using ZX Pocket-style APF output patterns. |
| MiSTer CPC audio to APF audio | Preserve PSG output semantics, adapt sample width/rate/sign only as required by APF. |
| Pocket controller/virtual keyboard to CPC matrix | Use ZX Pocket UI patterns, but drive the CPC keyboard/joystick matrix and experimental Dock USB keyboard path expected by MiSTer CPC logic. |
| Pocket memory resources to CPC RAM/ROM | Keep CPC banking behavior, change only storage primitives/resource mapping as needed for Pocket. |

## Replace entirely

| MiSTer feature | Replacement |
| --- | --- |
| `hps_io` | APF bridge registers + data slots. |
| MiSTer `CONF_STR` menu | Pocket `core.json`/menu metadata and bridge writable config registers. |
| MiSTer PS/2 keyboard/mouse | Pocket controller inputs + virtual keyboard + experimental Dock USB keyboard path. |
| MiSTer SD sector interface | APF asset/data-slot loader and block cache layer. |
| MiSTer HDMI/VGA/scaler flags | Pocket scaler output using `video_rgb`, `video_de`, `video_hs`, `video_vs`. |
| SNAC/DB9 | Drop for MVP. |
