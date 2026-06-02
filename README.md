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
- `docs/RISKS.md`: risk register and mitigation plan.
- `docs/APF_BRIDGE_DESIGN.md`: proposed APF bridge/register design.
- `docs/ROM_ASSET_LAYOUT.md`: proposed asset layout for CPC ROMs/media.
- `codex/TASKS.md`: Codex-ready task list.
- `codex/PROMPTS.md`: prompts to paste into Codex for each phase.
- `src/apf_amstrad_skeleton`: starter skeleton with placeholder top-level files and TODOs.
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
