# Analogue Pocket Amstrad CPC Core Port Handoff

This package is a planning and implementation handoff for porting the MiSTer Amstrad CPC core to Analogue Pocket/openFPGA, using the existing OpenFPGA ZX Spectrum core as the platform/wrapper reference.

## Source projects

- MiSTer Amstrad CPC core: https://github.com/MiSTer-devel/Amstrad_MiSTer
- OpenFPGA ZX Spectrum core: https://github.com/dave18/OpenFPGA_ZX-Spectrum
- Analogue Pocket developer docs: https://www.analogue.co/developer/docs/overview

## Intended approach

Do not try to mutate the ZX Spectrum core into a CPC by changing machine internals. Use it as an openFPGA scaffold: APF top-level, bridge wiring, controller plumbing, Quartus project shape, memory-controller examples, virtual keyboard concept, and release layout.

Use the MiSTer Amstrad core for the actual CPC implementation: Z80 timing, Gate Array, CRTC, PPI, PSG/audio, u765/FDC, DSK handling, tape/CDT loader, ROM loading, models, RAM banking, snapshots where feasible.

## Package contents

- `docs/SPEC.md`: product and technical specification.
- `docs/IMPLEMENTATION_PLAN.md`: phased engineering plan.
- `docs/COMPONENT_MAP.md`: which source project to take each subsystem from.
- `docs/CPC_IMPORT_MANIFEST.md`: initial MiSTer CPC HDL import list and deferrals.
- `docs/RISKS.md`: risk register and mitigation plan.
- `docs/APF_BRIDGE_DESIGN.md`: proposed APF bridge/register design.
- `docs/ROM_ASSET_LAYOUT.md`: proposed asset layout for CPC ROMs/media.
- `codex/TASKS.md`: Codex-ready task list.
- `codex/PROMPTS.md`: prompts to paste into Codex for each phase.
- `src/apf_amstrad_skeleton`: active APF Amstrad CPC skeleton.
- `scripts/bootstrap_local.sh`: clone upstreams and arrange local working tree.
- `scripts/check_expected_files.py`: sanity checker for local upstream clones.

## Starting locally

```bash
unzip ap-cpc-port-codex-package.zip
cd ap-cpc-port-codex-package
bash scripts/bootstrap_local.sh
python3 scripts/check_expected_files.py
```

Then hand this whole folder to Codex.

## Current implementation status

This workspace now contains a hardware-tested APF skeleton at
`src/apf_amstrad_skeleton`:

- Generic APF wrapper files copied from the Pocket ZX Spectrum reference.
- Amstrad-specific `core_top.sv` with safe unused-interface tie-offs,
  bridge-visible registers, Pocket ROM dataslot loading, and CPC video output.
- Imported MiSTer CPC motherboard, Gate Array, CRTC, PPI, PSG, T80 CPU,
  palette mixer, and local RAM/ROM wrapper sufficient to boot the CPC 6128 ROM.
- Minimal openFPGA platform/core JSON metadata for `amstrad` /
  `steve.AmstradCPC`.
- Trimmed Quartus `ap_core.qsf` source list containing APF support and the
  imported CPC modules currently used by the Pocket build.
- Docker-based Quartus build and Pocket install targets in `Makefile`.

Current hardware checkpoint:

- The core boots to the CPC 6128 firmware screen on Analogue Pocket.
- Palette is correct for the CPC boot screen.
- The scaler metadata advertises the current 192-sample active stream, which
  produces a stable, correctly sized image on the Pocket.
- Known issues: the firmware banner currently reports `Isp` rather than
  `Amstrad`, keyboard/input is not wired through yet, and storage/FDC/tape
  support remains deferred.
