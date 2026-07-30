# PocketCPC Working Guide

This file is the shared working agreement for anyone editing this repository,
whether by hand or with an automated coding assistant.

## Start Here

Read these first before changing code:

1. `README.md`
2. `CONTRIBUTING.md`
3. `docs/DEVELOPER_GUIDE.md`
4. `docs/COMPONENT_MAP.md`
5. `docs/CPC_IMPORT_MANIFEST.md` if you are touching imported CPC machine files
6. `docs/ROM_ASSET_LAYOUT.md` if you are changing `boot.rom` loading, packaging, or model ROM assumptions
7. `docs/SAVESTATE_ARCHITECTURE.md` if you are touching Pocket savestates or Memories
8. `docs/MEDIA_TRANSPORT_ARCHITECTURE.md` if you are touching ROM, disk, tape, or snapshot transport
9. `docs/INPUT_ARCHITECTURE.md` if you are touching controls, the VKB, or Dock keyboard handling
11. `TODO.md`
12. `CHANGELOG.md` when preparing or documenting a release

## Project Intent

PocketCPC is a hardware-tested Analogue Pocket core for the Amstrad CPC. The
design should stay easy to follow for contributors who already understand FPGA
cores and reference-core reuse.

The architecture rule is simple:

- reuse MiSTer Amstrad for CPC machine behavior
- reuse OpenFPGA ZX Spectrum for Analogue Pocket/APF integration patterns
- consult `markus-zzz/myc64-pocket` for Dock USB keyboard APF report layout
- keep new local HDL limited to adapters and glue unless a divergence is
  necessary and documented

Do not treat the upstreams as loose inspiration when working equivalent code
already exists.

## Decision Order

For each subsystem change:

1. Check whether MiSTer Amstrad already implements the CPC-side behavior. If it
   does, preserve that logic and adapt only the host or platform boundary.
2. Check whether the ZX Spectrum Pocket core already implements the equivalent
   Pocket or APF pattern. If it does, copy or closely adapt that pattern.
3. For Dock USB keyboard handling, check `markus-zzz/myc64-pocket` before
   inventing a new APF controller-word interpretation.
4. Add new local code only when the references do not already solve the
   boundary.
5. Document deliberate divergences in the relevant source comment or docs file.

## Ownership Boundaries

MiSTer Amstrad owns:

- Z80 timing and clock-enable relationships
- Gate Array, CRTC, PPI, PSG, memory banking, model selection, and reset
  behavior
- CPC color generation and palette mapping
- FDC/u765, DSK, tape, expansion ROM, and snapshot behavior where imported

ZX Spectrum Pocket owns the preferred shape for:

- APF top-level wiring and safe unused-interface handling
- `core_top` port shape and bridge command integration
- runtime reset handling for Pocket-facing state
- scaler and DDIO video output structure
- asset and data-slot loading patterns such as `boot.rom`
- controller, virtual keyboard, metadata, and release layout
- host-facing OSD and virtual-keyboard presentation

MyC64 Pocket owns the preferred shape for:

- Dock USB keyboard APF report decoding from `cont3_key`, `cont3_joy`, and
  `cont3_trig`

Local PocketCPC code should own only:

- APF bridge and data-slot adapters
- CPC video/audio/control adapters to APF-facing outputs
- minimal storage wrappers needed for Pocket resources
- temporary debug harnesses that are removed or clearly marked before release

## Build And Test Discipline

- Avoid rebuilding or reinstalling artifacts whose hardware behavior is already
  known.
- `make validate` is allowed as the default cheap HDL sanity check. It runs
  Quartus Analysis & Elaboration only, and is the preferred pre-handoff check
  for syntax, hierarchy, project coverage, and port/assignment mistakes when a
  human has not explicitly asked for a full build.
- For routine feature work, do not start `make build`, `make report`,
  `make dist`, or other Quartus-driven flows unless a human explicitly asks for
  that validation.
- If a human reports that a build failed, inspect the existing logs and reports
  first. Do not restart `make build`, rerun Quartus, or reinstall artifacts
  just because an agent changed code or found a likely fix; hand the rerun back
  to the human unless they explicitly ask the agent to execute the build.
- After code changes, prefer handing off by asking the human collaborator to
  run `make dist` when they want build, timing, and packaging validation. The
  default matters here because Quartus builds produce a lot of log output, and
  having an agent run them can burn a large number of tokens for little value
  when a human can launch the same command directly.
- Treat Quartus execution as human-owned by default. Agents may read status,
  logs, timestamps, and reports for a build the human started, but they should
  not assume permission to relaunch or continue that build without an explicit
  user instruction to do so.
- Before starting a long build, be clear what new information that artifact
  should provide.
- When monitoring `make build`, prefer
  `scripts/build_core_docker.sh status`,
  `scripts/build_core_docker.sh log`,
  `scripts/build_core_docker.sh wait`,
  `scripts/build_core_docker.sh freshness`, `docker ps`, and artifact
  timestamps over disruptive inspection.
- Do not treat long quiet periods during Quartus builds as a hang by default.
- Do not commit hardware-facing changes until the resulting build has been
  tested on Pocket hardware and the behavior is confirmed.
- Publish release build assets through GitHub Releases. Do not commit archived
  `.rbf_r` snapshots under `releases/`.

## Current Project Conventions

- Keep the required ROM bundle at
  `/Assets/amstrad/stilvoid.PocketCPC/boot.rom`.
- Keep `docs/ROM_ASSET_LAYOUT.md` in sync with any change to the `boot.rom`
  contract or bank layout.
- Keep optional disks, tapes, and snapshots under `/Assets/amstrad/common/`.
- Use `docs/CPC_IMPORT_MANIFEST.md` to preserve provenance when editing files
  under `src/fpga/cpc/`.
- Disk writes are currently acknowledged but not persisted. Keep README and
  release notes explicit about that.
- `sleep_supported` is currently enabled and hardware-verified. Keep README and
  `TODO.md` precise about what is fully supported versus which broader
  savestate/media edge cases still need validation.
- Dock USB keyboard support is experimental. Keep README and `TODO.md` honest
  about missing mappings or behavior gaps.

## Documentation Rules

- Update `README.md` whenever user-visible behavior, install layout, controls,
  or limitations change.
- Update `CHANGELOG.md` for every release.
- Treat `docs/DEVELOPER_GUIDE.md` as the architecture and code-reading guide.
- Treat `docs/COMPONENT_MAP.md` as the ownership map for reference-core reuse
  decisions.
- Treat `docs/CPC_IMPORT_MANIFEST.md` as the provenance map for imported
  MiSTer-derived files.
- Treat `docs/ROM_ASSET_LAYOUT.md` as the contract for the required
  `boot.rom` bundle.
- Treat `docs/SAVESTATE_ARCHITECTURE.md` as the design note for Pocket
  `Memories` and sleep/wake support.
- Treat `docs/MEDIA_TRANSPORT_ARCHITECTURE.md` as the design note for APF
  startup assets and runtime media transport.
- Treat `docs/INPUT_ARCHITECTURE.md` as the design note for Pocket controls,
  the VKB, remapping, and Dock keyboard handling.
- Update `TODO.md` whenever known follow-up work changes.
- Prefer neutral repo docs such as `AGENTS.md`, `README.md`, and `docs/*`
  instead of tool-specific workflow files.
- Do not commit local tool state or scratch files such as `.codex/`,
  `.agents/`, or ad hoc assistant prompt dumps.
