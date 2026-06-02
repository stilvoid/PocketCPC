# Component Map

## Use from OpenFPGA ZX Spectrum core

Use these as reference or direct scaffold where licence permits:

| Area | Source | Use |
| --- | --- | --- |
| `apf_top.v` style wrapper | `src/fpga/apf/apf_top.v` | Copy/adapt physical Pocket pins, scaler DDR output, bridge peripheral, controller plumbing. |
| `core_top.sv` APF signature | `src/fpga/core/core_top.sv` | Use port list shape for new Amstrad-facing top. |
| Quartus project shape | `src/fpga/ap_core.qsf`, SDC/IP files | Start from this project layout, then replace Spectrum source files with CPC source files. |
| Bridge register style | ZX core bridge usage | Implement CPC menu/register/file-slot commands using APF bridge. |
| Virtual keyboard | ZX core feature | Reuse concept and UI behavior, redesign matrix for CPC. |
| ROM bundle convention | ZX `boot.rom` README | Use same idea for CPC OS/BASIC/AMSDOS/MF2/464 ROM bundle. |
| Disk/tape lessons | ZX changelog and code | Useful for timing and Pocket media integration patterns, not direct CPC disk logic. |

## Use from MiSTer Amstrad core

| Area | Source | Use |
| --- | --- | --- |
| CPC machine | `rtl/`, top-level logic behind `Amstrad.sv` | Primary source of CPC behavior. |
| Model support | `Amstrad.sv` menu/model logic | Start with CPC 6128, later apply model bits for 664/464. |
| ROM loader mapping | `Amstrad.sv` `ioctl_*` handling | Re-express as APF asset-slot loader. |
| FDC/u765 + DSK | MiSTer media/disk subsystem | Keep core disk controller, replace MiSTer SD block transport. |
| Tape/CDT | MiSTer tape loader | Later phase after DSK boot. |
| Snapshot loader | MiSTer SNA handling | Later phase, may require APF slot streaming adaptation. |
| CRTC/Gate Array/PPI/PSG | CPC HDL | Keep as-is where possible. |
| Video/audio signal generation | CPC HDL | Adapt output wrapper only. |

## Replace entirely

| MiSTer feature | Replacement |
| --- | --- |
| `hps_io` | APF bridge registers + data slots. |
| MiSTer `CONF_STR` menu | Pocket `core.json`/menu metadata and bridge writable config registers. |
| MiSTer PS/2 keyboard/mouse | Pocket controller inputs + virtual keyboard; optional dock keyboard later. |
| MiSTer SD sector interface | APF asset/data-slot loader and block cache layer. |
| MiSTer HDMI/VGA/scaler flags | Pocket scaler output using `video_rgb`, `video_de`, `video_hs`, `video_vs`. |
| SNAC/DB9 | Drop for MVP. |
