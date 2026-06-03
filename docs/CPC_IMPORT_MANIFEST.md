# CPC Import Manifest

Source: `upstreams/Amstrad_MiSTer/files.qip`.

This is the initial dependency list for importing MiSTer CPC logic under
`src/fpga/cpc/`. Preserve upstream licence headers and keep copied files
traceable to the MiSTer repository.

## MVP Import Candidates

| Source path | Purpose |
| --- | --- |
| `rtl/T80/T80.qip` | Z80-compatible CPU core package. |
| `rtl/GA40010/ga40010.qip` | Gate Array implementation and video timing helpers. |
| `rtl/u765/u765.sv` | Floppy disk controller. |
| `rtl/YM2149.sv` | PSG audio. |
| `rtl/i8255.v` | PPI, keyboard/PSG control path. |
| `rtl/color_mix.sv` | CPC palette/color adaptation. |
| `rtl/UM6845R.v` | CRTC. |
| `rtl/Amstrad_MMU.v` | RAM/ROM banking. |
| `rtl/Amstrad_motherboard.v` | Main CPC motherboard integration target. |

## Likely Later Imports

| Source path | Reason to defer |
| --- | --- |
| `rtl/tzxplayer.vhd` | CDT/tape is post-MVP. |
| `rtl/dandanator/cpc_dandanator.vhd` | Expansion cartridge support is post-MVP. |
| `rtl/playcity/Z80CTC/z80ctc.qip` | PlayCity expansion is post-MVP. |
| `rtl/playcity/playcity.v` | PlayCity expansion is post-MVP. |
| `rtl/hid.sv` | MiSTer HID path should be replaced by Pocket controller/keyboard adapters. |
| `rtl/joydb.sv` | Joystick database is MiSTer-oriented; map Pocket controls first. |
| `rtl/*_mouse.v` | Mouse support is post-MVP. |
| `rtl/crt_filter.v` | Pocket scaler path should start without MiSTer video filters. |
| `rtl/progressbar.v` | MiSTer UI overlay behavior is not needed for first boot. |

## Platform Files To Avoid

| Source path | Replacement |
| --- | --- |
| `Amstrad.sv` | Use only as a reference for config, loaders, and wiring. Do not instantiate MiSTer `emu` directly. |
| `sys/hps_io.sv` | Replace with `src/fpga/core/pocket_bridge_regs.sv` and APF data slots. |
| `rtl/sdram.v` | Re-evaluate after CPC RAM/ROM wrapper design; BRAM or Pocket memory wrappers may be preferable initially. |
| `Amstrad.sdc` | Rework constraints for the Pocket clocking/project once CPC clocks are chosen. |

## Next Wrapper Target

Create `src/fpga/cpc/cpc_machine_pocket.sv` around `Amstrad_motherboard`.
Start with fixed CPC 6128 config, host-loaded ROM memory, no tape, no mouse,
no PlayCity, and read-only Drive A stubs. Keep APF bridge and media transport
outside the CPC machine wrapper.
