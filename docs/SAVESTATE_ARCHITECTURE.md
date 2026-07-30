# Savestate And Sleep/Wake Architecture

This document describes the shipped PocketCPC design for Pocket `Memories`
savestates and sleep/wake resume. It replaces the old experiment-by-experiment
devlog with a shorter description of the architecture that future changes
should preserve unless there is strong hardware evidence to do otherwise.

## Scope

This document is about Pocket-owned savestates:

- manual Pocket `Memories` save/load
- automatic sleep save and wake restore

It is not the design document for normal `.sna` snapshot files, although the
current Pocket savestate payload deliberately reuses the `.sna` state model.

## User-visible behavior

PocketCPC currently:

- advertises `savestate_supported: true` and `sleep_supported: true`
- saves and loads Pocket `Memories`
- uses the same machinery for sleep/wake resume
- stores a CPC `.sna`-compatible payload inside the Pocket `.sta` wrapper

Current limits still matter:

- savestate creation is rejected during active disk or tape activity
- tape runtime position is not preserved yet
- in-flight FDC and other adapter-local state still need broader validation
- Pocket-created Memory labels still appear under the fixed `boot` asset name

## Design constraints

The current design is built around a few constraints that came out of repeated
hardware failures during development:

1. Do not mirror the full Pocket-visible savestate window in Cyclone V BRAM.
   That route over-consumed M10Ks and was not viable on this target.
2. Do not invent a second CPC state format just for Pocket `Memories`.
   Reuse the existing CPC snapshot model where possible.
3. Keep APF/Pocket transport logic in the adapter layer.
   Do not scatter it through the imported CPC machine.
4. Treat bridge reads as one-word-buffered.
   The bridge must already have the current word ready when the Pocket reads.
5. Accept that sleep/wake can request restore before ordinary runtime media
   setup is fully safe for CPC state application.

## APF contract

The relevant APF contract is:

- `0x00A0` reports savestate save support, address, and size
- `0x00A4` reports savestate load support, address, and maximum size
- the Pocket writes the blob to the advertised address, then requests load

PocketCPC exposes that bridge window at `0x40000000` and advertises a maximum
load size of `131328` bytes, which covers the current 128 KiB CPC snapshot
payload.

The core must therefore do two things well:

- export a stable staged blob for save
- accept Pocket-written load data and hold restore until the CPC-side apply
  path is actually safe

## Chosen architecture

The current implementation centers on
`src/fpga/core/cpc_savestate_controller.sv`.

The controller owns:

- the APF savestate bridge window
- PSRAM-backed staging storage
- save/load state machines
- CPC RAM capture and restore
- final `.sna`-style register/state apply
- load-progress reporting for the Pocket UI

The staged payload is a CPC `.sna`-compatible image, not a custom PocketCPC
binary format. That lets Pocket `Memories`, normal `.sna` loading, and the
conversion tooling all speak one CPC snapshot language.

The payload lives in external PSRAM through the `cram*` interface. CPC RAM
stays where it already works; PocketCPC does not move machine RAM into the
savestate backing store just to simplify save/load transport.

## Why the staged payload needs SNA v3 state

PocketCPC reuses the `.sna` snapshot model, but the staged Pocket savestate
payload is intentionally `v3`-compatible rather than stopping at `v2`.

The reason is practical, not cosmetic:

- `v1` and `v2` snapshot headers do not carry enough machine-timing state for
  the restore path PocketCPC needed
- reliable sleep/wake restore required additional CRTC and Gate Array timing
  state to survive the round-trip
- the `v3` header provides that extra timing information

During development, ordinary save/load could appear to work while sleep/wake
still returned to boot or resumed with unstable display timing. Preserving the
extra `v3` timing fields, especially the CRTC state and related GA timing
state, was part of getting wake restore stable on hardware.

So the design rule is:

- import/export tooling can still accept older `.sna` inputs where practical
- the Pocket `Memories` implementation itself should keep producing and
  consuming a `v3`-compatible staged payload unless hardware evidence proves a
  narrower format is safe

## Save flow

At a high level, save works like this:

1. The Pocket asks whether savestate save is supported.
2. `cpc_savestate_controller.sv` waits for `save_safe`.
3. The controller freezes the CPC and captures RAM plus the required machine
   registers.
4. It builds a `.sna`-compatible payload in PSRAM.
5. The Pocket reads that staged payload back through the APF bridge window and
   wraps it in its own `.sta` container.

Important details:

- the payload contains CPC RAM plus the CPU, CRTC, Gate Array, PPI, PSG, RAM
  config, ROM config, model, and custom-ROM state needed for restore
- the save path verifies early staged words because the first few header words
  are enough to detect transport failures quickly
- save waits for a safe frame boundary before completing

## Load and sleep/wake flow

Load and sleep/wake share the same restore path.

At a high level:

1. The Pocket writes the staged blob into the savestate bridge window.
2. The Pocket requests load through APF.
3. The controller accepts the request, freezes the CPC, and waits until the
   blob is safe to consume.
4. RAM is copied back from PSRAM into CPC RAM.
5. The final `.sna` register/state apply is delayed until `load_safe`.
6. Reset is released in a controlled sequence while the CPU remains frozen long
   enough for the restored register set to be sampled.

The important sleep/wake-specific rule is that load request acceptance must not
assume the whole core is already in ordinary runtime state. Wake restore can
arrive while startup asset work is still finishing, so the controller separates:

- accepting the Pocket's request
- draining and validating the blob
- the final CPC-side apply pulse

That separation is what lets sleep/wake resume work instead of falling through
to a normal boot.

## ROM setup interaction

Sleep/wake correctness is tied to ROM loading.

PocketCPC now loads `boot.rom` and optional `custom.rom` through normal APF
setup writes instead of deferred runtime target reads. That matters because:

- the Pocket can show native setup progress during wake
- ROM setup finishes on the APF-owned startup path
- savestate final apply can wait for `cpc_custom_rom_ready` without forcing the
  whole restore flow to idle until late runtime

In practice, the savestate path now depends on two distinct readiness ideas:

- the staged blob is present and readable
- the CPC machine is actually safe for final restored-state application

Do not collapse those back into one coarse gate without hardware proof.

## Key files

The main files to read before changing this area are:

- `src/fpga/core/cpc_savestate_controller.sv`
- `src/fpga/core/core_top.sv`
- `src/fpga/core/pocket_bridge_regs.sv`
- `src/fpga/core/pocket_sna_dataslot.sv`
- `src/fpga/core/pocket_sna_save_dataslot.sv`
- `src/fpga/core/psram.sv`
- `scripts/pocketcpc_savestate.py`
- `scripts/compare_sna_debug.py`

## Debugging and tooling

The main debug surfaces are:

- read-only savestate debug registers exposed by `pocket_bridge_regs.sv`
- target log bursts emitted by `core_top.sv`
  `SSLE` marks a failed load and `SSOK` marks a successful one
- `scripts/compare_sna_debug.py` for comparing logged header words against a
  known-good `.sna`
- `scripts/pocketcpc_savestate.py` for extracting or generating PocketCPC
  `.sta` files

When debugging, the first questions should usually be:

1. Was the staged header correct?
2. Did the Pocket-facing bridge export the first words correctly?
3. Did the CPC-side final apply happen after the runtime-safe gates were true?

## Rejected directions

These approaches were tried and should be treated as rejected unless there is
new evidence:

- effectively live-streaming savestate state across APF instead of staging
- mirroring the full savestate window in FPGA BRAM
- using a custom `PCS1` PocketCPC-only payload instead of a `.sna`-compatible
  snapshot blob
- relying on loose toggle-plus-synchronizer CDC mailboxes for wide payloads

## Current follow-up work

The remaining known work is mostly about completeness, not basic viability:

- validate more disk/tape/FDC edge cases across save/load and sleep/wake
- preserve any missing adapter-local runtime state that should survive restore
- keep the user-facing docs honest about what is hardware-proven versus still
  experimental
- revisit runtime snapshot export only when there is a proven APF-backed user
  workflow for getting the files back out
