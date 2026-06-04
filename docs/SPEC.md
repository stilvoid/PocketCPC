# Specification: Analogue Pocket Amstrad CPC Core

## Goal

Create an Analogue Pocket/openFPGA core for the Amstrad CPC family, initially targeting CPC 6128 compatibility with boot ROM loading and read-only DSK mounting, then expanding toward CPC 464/664, CDT tape, snapshots, disk writes, expansion ROMs, and quality-of-life features.

## Feasibility position

See `docs/REFERENCE_CORE_STEERING.md` for the binding reference-core reuse
policy. The short version is: reuse MiSTer Amstrad for CPC behavior, reuse the
ZX Spectrum Pocket core for Analogue Pocket/APF integration, and keep new local
code limited to glue between those references.

The ZX Spectrum Pocket core should be treated as a platform adaptation reference, not as the hardware base. The Spectrum +3 and CPC share historical Amstrad-era design influence and both use Z80-family architecture and 3-inch disk heritage, but the core logic is not interchangeable. The useful overlap is mostly:

- Z80 CPU integration patterns.
- FDC/disk lessons.
- ROM asset packaging.
- openFPGA bridge and controller wiring.
- scaler/DDIO video output and registered RGB/DE/HS/VS patterns.
- virtual keyboard/user-interface handling.
- Quartus/openFPGA project structure.

The CPC machine implementation should come from the MiSTer Amstrad core. Any
change to CPU timing, Gate Array, CRTC, colour generation, PSG, PPI, memory
banking, FDC, tape, or model behavior should first look for the equivalent
MiSTer implementation and preserve it wherever practical.

## MVP scope

The first useful build should support:

1. CPC 6128 model.
2. Main ROM bundle loading from Pocket assets.
3. 128K RAM banking.
4. Keyboard matrix driven by Pocket controls and a simple virtual keyboard.
5. Joystick mapping.
6. RGB video output through openFPGA scaler.
7. AY/PSG audio output.
8. Read-only DSK mount for Drive A.
9. Reset/apply model command.

## Post-MVP scope

- Drive B.
- Disk writes.
- CDT tape loading.
- CPC 464 and CPC 664 model support.
- Expansion ROM loading.
- Dandanator ROM.
- SNA snapshot loading.
- Mouse/AMX mouse.
- Display options from the MiSTer core, narrowed for Pocket.
- Dock-oriented keyboard support, if practical.

## Non-goals for first version

- Full MiSTer menu parity.
- SNAC/DB9 support.
- MiSTer framebuffer/scandoubler feature parity.
- Save states.
- Exact preservation of MiSTer file-loader internals.
- Full Spectrum +3 compatibility, because this is a CPC core, not a history museum with a soldering iron.

## Technical constraints

- Analogue Pocket core top-level must expose APF physical/logical interfaces.
- MiSTer `emu` top-level cannot be used directly.
- MiSTer `hps_io`, OSD `status`, SD block I/O, PS/2 keyboard/mouse, and MiSTer video/audio outputs need replacement adapters.
- Platform adapters should follow the ZX Spectrum Pocket core structure unless
  there is a documented reason to diverge.
- The first build should minimize dependencies on external RAM complexity by using BRAM where reasonable and only using PSRAM/SDRAM when required.
- GPL source inheritance must be preserved if using MiSTer HDL.

## Expected repo architecture

```text
openfpga-amstrad-cpc/
  src/fpga/apf/             # APF wrapper from ZX Spectrum core/reference framework
  src/fpga/core/            # New Pocket-facing CPC top level
  src/fpga/cpc/             # Imported/refactored MiSTer CPC machine HDL
  src/fpga/platform/        # APF-to-core bridge adapters
  src/fpga/memory/          # Pocket memory wrappers
  src/fpga/input/           # keyboard matrix + virtual keyboard
  src/fpga/media/           # ROM/DSK/CDT asset loaders
  Cores/
  Platforms/
  Assets/amstrad/<vendor.CoreName>/
  docs/
```
