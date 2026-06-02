# Codex Prompts

## Prompt 1: Skeleton

You are working in `openfpga-amstrad-cpc`. Use `upstreams/OpenFPGA_ZX-Spectrum` only as an openFPGA/APF reference. Create a buildable Analogue Pocket core skeleton for Amstrad CPC. Copy/adapt the APF top-level wrapper shape and Quartus project structure, but do not import Spectrum machine HDL. Add a dummy `core_top.sv` that outputs a stable test pattern and silence. Preserve relevant licence notices.

## Prompt 2: CPC import

Import the minimum necessary HDL from `upstreams/Amstrad_MiSTer` into `src/fpga/cpc/`. Create `docs/IMPORTED_FILES.md` listing every copied file and its role. Create `src/fpga/core/cpc_machine_pocket.sv` as a wrapper. Do not attempt to implement APF media loading yet. Stub MiSTer-only interfaces.

## Prompt 3: Replace MiSTer host interface

Find all dependencies on MiSTer `hps_io`, `CONF_STR`, `status`, `ioctl_*`, PS/2, SNAC, and MiSTer SD block signals. Create `src/fpga/platform/pocket_bridge_regs.sv` and a documented register map. Replace the host interface with bridge registers and simple loader signals. Keep behavior equivalent where possible for reset, model select, ROM load, and Drive A mount.

## Prompt 4: Boot ROM

Implement a user-supplied `boot.rom` asset flow based on `docs/ROM_ASSET_LAYOUT.md`. Load CPC6128 OS, BASIC, and AMSDOS into the ROM storage expected by the CPC core. Hold reset until ROM loading completes. Add simulation checks for ROM page mapping.

## Prompt 5: Input

Implement `src/fpga/input/cpc_keyboard_matrix.sv` and map Pocket controller inputs to CPC keyboard rows/columns plus joystick. Use the ZX Spectrum virtual keyboard behavior as a reference only. Add a minimal keyboard overlay/mode sufficient for BASIC commands.

## Prompt 6: Drive A DSK

Implement read-only Drive A DSK mounting via APF data slot. Replace MiSTer SD block transport with a Pocket media cache. Preserve the CPC FDC/u765 behavior. Writes should report write-protected or be ignored safely until write-back support is designed.

## Prompt 7: Stabilize for beta

Optimize for timing/resource fit on Analogue Pocket. Remove unused MVP-disabled features from synthesis. Add build instructions, ROM setup instructions, known issues, and a release checklist.
