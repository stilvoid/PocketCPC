# Contributing to PocketCPC

PocketCPC is a public hardware-tested Analogue Pocket core for the Amstrad CPC.
Contributions are welcome, but this is not a clean-room project and it is not a
good fit for casual rewrites. The best changes are small, well-explained, and
respect the reference-core structure already in use.

## Before You Start

Read these first:

1. `README.md`
2. `AGENTS.md`
3. `docs/DEVELOPER_GUIDE.md`
4. `docs/COMPONENT_MAP.md`
5. `docs/CPC_IMPORT_MANIFEST.md` if you are touching imported CPC machine files
6. `docs/ROM_ASSET_LAYOUT.md` if you are changing `boot.rom` handling or ROM assumptions
7. `TODO.md` for the current backlog

If you plan a large change, open an issue or start a discussion first. Small,
focused pull requests are much easier to review and validate on hardware.

## What Helps Most

Useful contributions include:

- bug fixes with a clear reproduction case
- hardware test reports from real Pocket or Dock use
- focused work from `TODO.md`
- documentation fixes that match the current shipped behavior
- build, packaging, and validation improvements

## Project Rules

- Preserve MiSTer Amstrad behavior for CPC machine logic wherever practical.
- Preserve the ZX Spectrum Pocket patterns for Analogue Pocket and APF integration wherever practical.
- Keep new local HDL limited to adapters and glue unless a divergence is necessary and documented.
- Preserve upstream file headers and provenance when editing imported or adapted files.
- Keep user-facing docs in sync with behavior changes.
- Treat `src/fpga/` as authored FPGA source and `src/pocket/` as the Pocket package template. Generated outputs belong under `build/` and `dist/`, not back in `src/`.

AI-assisted contributions are fine, but contributors are expected to understand
and stand behind the submitted changes.

## Build And Validation

Useful commands:

```bash
make build
make install
make dist
```

Notes:

- `make build` stages a complete installable package under `build/package/`, uses `build/quartus/` as the Quartus workspace, rebuilds the bitstream only when tracked FPGA inputs changed, and refreshes the staged metadata when git version inputs changed.
- `make install` is available for local SD-card installs and depends on `make dist`.
- `make dist` writes a release zip under `dist/` with `Assets`, `Cores`, and `Platforms` at the archive root. Users still supply `boot.rom` separately.
- For deeper build troubleshooting, use `scripts/build_core_docker.sh status|log|wait|stop|freshness` directly.
- Do not put generated bitstreams or build-info files back under `src/pocket/`. Rebuild them into `build/package/` when the new artifact is actually needed for review or hardware validation.

## Hardware Testing Expectations

Hardware-facing changes are strongest when they are tested on a real Analogue
Pocket.

If you test on hardware, include:

- Pocket or Dock setup used
- media or ROMs used to reproduce the behavior
- display mode or menu settings if relevant
- what improved, regressed, or remains uncertain

If you cannot hardware test, say so clearly in the pull request. Untested
changes can still be useful, but they may be held until someone can validate
them on hardware.

## Docs To Update

Update these when relevant:

- `README.md` for user-visible behavior, install layout, controls, or limitations
- `TODO.md` for follow-up work or known gaps
- `docs/ROM_ASSET_LAYOUT.md` for any `boot.rom` contract change
- `docs/CPC_IMPORT_MANIFEST.md` when imported MiSTer-derived file provenance changes
- `docs/DEVELOPER_GUIDE.md` or `docs/COMPONENT_MAP.md` when the architecture or reference-core boundaries change

## Licensing And Provenance

Read `LICENSE.md` before contributing. This repository contains a mix of:

- copied upstream files
- adapted upstream files
- original PocketCPC glue and documentation

Important rules:

- do not remove preserved upstream notices
- do not submit code unless you have the right to contribute it under the relevant terms
- do not commit copyrighted ROMs, commercial disk images, tapes, snapshots, or other redistributable media you do not have rights to share

## Pull Request Checklist

Before opening a PR, make sure you can say which of these are true:

- the change is scoped and reviewable
- the relevant validation was run, and for build or release-packaging changes that includes `make build`
- the docs were updated where needed
- hardware testing was done, or the PR explicitly says it was not
- any imported-file edits preserve provenance and headers
- any intentional divergence from the reference cores is explained

## Style

- Prefer direct, plain-English commit messages and pull-request descriptions.
- Keep comments focused on why something exists or why it differs from the reference behavior.
- Avoid large opportunistic refactors in imported machine code unless they are necessary for the fix.
