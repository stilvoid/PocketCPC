# Media Transport Architecture

This document describes the current PocketCPC design for ROM, disk, tape,
snapshot, and snapshot-save transport between the Analogue Pocket host and the
MiSTer-derived CPC machine.

It is not a full user guide. It is the design note for why different media
types use different APF paths and which current limitations are deliberate.

## Scope

This document covers:

- required `boot.rom` and optional `custom.rom`
- mounted `.dsk` disk images
- mounted `.cdt` tape images
- mounted `.sna` snapshot loads
- runtime `.sna` snapshot export

Pocket `Memories` and sleep/wake transport are covered separately in
`docs/SAVESTATE_ARCHITECTURE.md`.

## Design rules

The current media design follows a few simple rules:

1. Keep CPC machine behavior in the imported MiSTer blocks where possible.
2. Keep Pocket/APF transport behavior in local adapter modules.
3. Use APF setup writes for startup assets that should be present before the
   CPC runs.
4. Use deferred runtime dataslots for media that can change while the core is
   running.
5. Do not promise persistence where the current transport path does not
   actually write it back.

## Two APF paths

PocketCPC intentionally uses two different APF transport styles.

### 1. Setup writes for ROM assets

`boot.rom` and `custom.rom` are normal setup-loaded dataslots in
`src/pocket/Cores/stilvoid.PocketCPC/data.json`:

- `0x200` -> `boot.rom` at `0x60000000`
- `0x208` -> `custom.rom` at `0x60028000`

These are not deferred slots. The Pocket writes them during setup and
`src/fpga/core/pocket_apf_write_loader.sv` streams those bridge writes into the
existing CPC ROM RAM.

This path was chosen because ROMs are startup assets, not runtime media:

- the CPC should not run before they are present
- the Pocket can show native setup progress
- sleep/wake restore can depend on ROM setup completing cleanly

### 2. Deferred dataslots for runtime media

Disks, tapes, and snapshots remain `deferload` dataslots:

- `1` -> Drive A
- `2` -> Drive B
- `3` -> Tape
- `4` -> Snapshot

Those slots are mounted and changed at runtime. The Pocket reports mount/update
events, then the CPC-side adapter modules request data through APF target
commands when they need it.

That split is deliberate. Do not move runtime media onto the ROM setup-write
path just because the APF interface looks superficially simpler.

## Top-level orchestration

The main coordination point is `src/fpga/core/core_top.sv`.

`core_top.sv` does four important things:

1. Tracks ROM-setup completion and holds the CPC machine until startup assets
   are loaded.
2. Treats runtime media as unavailable until `dataslot_runtime_enable` is true.
3. Instantiates one transport adapter per media type.
4. Arbitrates APF target-command ownership so only one runtime client drives
   `core_bridge_cmd.v` at a time.

The current runtime priority is:

1. snapshot save
2. snapshot load
3. tape
4. FDC

That priority is encoded by the `*_client_selected` gates in `core_top.sv`.
The point is not fairness; the point is deterministic ownership of the APF
target command bus.

## ROM loading

ROM loading now uses `src/fpga/core/pocket_apf_write_loader.sv`.

The loader:

- watches bridge writes in the `0x6...` address space
- pushes those writes through a small CDC FIFO
- emits byte writes into the CPC ROM memory
- counts bytes written so `core_top.sv` can infer when required payloads are
  complete

`core_top.sv` separately tracks:

- whether `boot.rom` was seen
- whether `custom.rom` was seen
- whether APF reported initial dataslots complete

The CPC machine is held in reset until the required base ROM payload is ready.
If `custom.rom` is present, `custom_rom_enable` is exposed separately as the
upper-ROM slot `6` experiment.

For the ROM layout itself, see `docs/ROM_ASSET_LAYOUT.md`.

## Disk transport

Disk transport lives in `src/fpga/core/pocket_fdc_dataslot.sv`.

The imported MiSTer `u765` still thinks in MiSTer block-device terms:

- it asks for 512-byte sectors via `sd_lba` and `sd_rd`
- it expects bytes to appear in a sector buffer
- it wants an acknowledge pulse back

The Pocket adapter translates that into APF reads from dataslot `1` or `2`.

Current shape:

- one 512-byte request at a time
- host data written into bridge RAM at `0x70000000`
- CPC clock domain streams the returned bytes into the `u765` sector buffer

Drive mount status also comes from APF `dataslot_update` notifications.
`pocket_fdc_dataslot.sv` delays making a drive “ready” until the runtime media
path is considered stable.

### Why writes are fake-acknowledged

This is an explicit current limitation.

When the MiSTer `u765` tries to write sectors, the adapter currently:

- acknowledges the request
- does not send a real APF writeback transaction
- does not persist sector changes to the image

That behavior exists to keep CPC software running instead of hanging the FDC
state machine. It is a compatibility compromise, not a finished writable-disk
implementation.

Do not document `.dsk` writes as persistent unless the transport path actually
changes.

## Tape transport

Tape transport lives in `src/fpga/core/pocket_tape_dataslot.sv`.

The imported MiSTer `tzxplayer` is already a sequential tape parser, so the
Pocket adapter does not try to reinterpret the CDT format. It only replaces the
byte source.

Current shape:

- tape data comes from dataslot `3`
- the adapter fetches 4 KiB chunks through APF target reads
- chunks are cached in a double-buffered local BRAM
- while one chunk is being consumed, the next chunk can be prefetched into the
  other bank

That double-buffering is the important design choice here. Tape playback is
sequential enough that a small rolling cache is simpler than per-byte host
traffic.

The adapter also responds to pause/restart conditions from the Pocket/menu
integration so the MiSTer tape player does not drift while the core is paused.

## Snapshot load transport

Runtime `.sna` loading lives in `src/fpga/core/pocket_sna_dataslot.sv`.

The design goal was to keep snapshot semantics aligned with MiSTer CPC rather
than inventing a Pocket-specific state loader.

Current shape:

- snapshot bytes come from dataslot `4`
- the adapter reads the file in 1 KiB chunks through APF
- the first 256 bytes are interpreted as the `.sna` header
- RAM bytes after that are streamed directly into CPC snapshot memory
- the final register/state apply is driven through the same `sna_*` signals the
  CPC wrapper already expects

The loader currently supports the standard contiguous-memory `.sna` form and
ignores extension chunks such as `MEM0` and `MEM1`.

It also preserves the longer apply/freeze sequence needed to avoid restoring
state and then immediately resetting over it.

## Snapshot save transport

Runtime snapshot export lives in `src/fpga/core/pocket_sna_save_dataslot.sv`.

This path is deliberately separate from Pocket `Memories`:

- Pocket `Memories` save into the APF savestate window and are wrapped in `.sta`
- snapshot export writes an actual `.sna` file to a writable dataslot/open-file
  path

The current implementation uses a dedicated save slot id internally and is not
yet exposed as a finished public Pocket menu/media feature.

Current shape:

- the adapter builds a normal `.sna` payload in a local buffer
- it opens a path under `/Saves/amstrad/common/`
- it writes the payload in 1 KiB chunks through APF target write/open-file
  commands

The output filename is generated from the RTC timestamp plus a short sequence
counter.

This path is not currently exposed as a finished end-user feature because the
transport and user workflow still need stronger validation.

## Current boundaries

The media boundary lines are:

- `pocket_apf_write_loader.sv` owns startup ROM ingestion
- `pocket_fdc_dataslot.sv` owns disk block reads and current fake write-acks
- `pocket_tape_dataslot.sv` owns sequential tape chunk fetch and cache
- `pocket_sna_dataslot.sv` owns runtime snapshot load
- `pocket_sna_save_dataslot.sv` owns runtime snapshot export
- `core_top.sv` owns reset gating, client arbitration, and shared readiness

## Current limitations

The important current limitations are:

- `.dsk` writes are acknowledged but not persisted
- tape runtime position is not preserved by Pocket `Memories`
- runtime snapshot export is still treated as a developer-facing path rather
  than a finished public feature
- the runtime media clients all share one APF target-command path, so they are
  intentionally serialized

## What should not be “simplified”

These choices are easy to misread as over-engineering, but they are currently
deliberate:

- ROM assets use setup writes while runtime media uses deferred dataslots
- runtime media ownership is serialized instead of parallel
- tape uses chunk caching instead of byte-at-a-time bridge traffic
- disk writes are fake-acknowledged rather than half-implemented as persistent
  writes
- snapshot export stays separate from Pocket `Memories`
