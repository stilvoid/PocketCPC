# Codex Task List

## Task 1: Create repository skeleton

- Create `openfpga-amstrad-cpc`.
- Copy APF wrapper structure from `dave18/OpenFPGA_ZX-Spectrum`.
- Rename core/platform/asset identifiers to Amstrad CPC.
- Produce a buildable dummy core that shows a test pattern.

Acceptance:
- Quartus project opens.
- Dummy core builds.
- No Spectrum machine HDL remains in active file list.

## Task 2: Import MiSTer CPC source

- Copy required MiSTer Amstrad HDL into `src/fpga/cpc`.
- Preserve copyright/licence headers.
- Add a manifest of imported files.
- Create `cpc_machine_pocket.sv` wrapping CPC internals.

Acceptance:
- Dependency graph is explicit.
- Elaboration reaches CPC machine wrapper.

## Task 3: Remove MiSTer platform dependencies

- Replace `hps_io` with `pocket_bridge_regs.sv`.
- Replace MiSTer `status` with Pocket config registers.
- Stub SNAC, PS/2, MiSTer scaler, SDRAM-specific features not needed for MVP.

Acceptance:
- No dependency on MiSTer `sys/hps_io.sv`.
- Config bits are documented.

## Task 4: Boot ROM path

- Implement `boot.rom` loader.
- Map CPC6128 OS/BASIC/AMSDOS into CPC ROM space.
- Hold CPC reset until ROM bundle is ready.

Acceptance:
- CPC fetches reset vectors from loaded ROM.
- BASIC prompt visible or simulated equivalent reached.

## Task 5: Keyboard and joystick

- Implement CPC keyboard matrix adapter.
- Map Pocket buttons to joystick.
- Implement minimal virtual keyboard.

Acceptance:
- BASIC commands can be entered.
- Joystick directions/fire work.

## Task 6: Video/audio

- Wire CPC video into APF video.
- Wire AY/PSG audio into Pocket audio.
- Remove unused MiSTer video filters for MVP.

Acceptance:
- Stable video and audible audio.

## Task 7: Read-only DSK Drive A

- Implement APF data-slot backed DSK cache.
- Feed MiSTer CPC FDC sector interface.
- Make write operations no-op/write-protected for MVP.

Acceptance:
- `CAT` works on a mounted DSK.
- At least one known CPC disk title loads.

## Task 8: Build hygiene

- Add build docs.
- Add lint/build scripts.
- Add README with ROM/media setup.
- Add licence/provenance section.

Acceptance:
- New contributor can build from README.
