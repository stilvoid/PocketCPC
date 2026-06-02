# PocketCPC

PocketCPC is an Amstrad CPC core for the [Analogue Pocket openFPGA](https://www.analogue.co/developer/docs/overview).

Status: early public release. It is hardware-tested and usable, but some
features are still incomplete and a few areas remain experimental.

This core was coded entirely with AI assistance, but it was directed by a human who knows and cares about the Amstrad CPC. The project deliberately reuses existing patterns and proven structure where possible, especially from [MiSTer-devel/Amstrad_MiSTer](https://github.com/MiSTer-devel/Amstrad_MiSTer) for CPC machine behaviour and [dave18/OpenFPGA_ZX-Spectrum](https://github.com/dave18/OpenFPGA_ZX-Spectrum) for Analogue Pocket integration, with local code kept focused on the glue between those references.

For licensing and provenance details, see [LICENSE.md](LICENSE.md).

## What This Is

PocketCPC adapts the MiSTer Amstrad CPC implementation to the Analogue Pocket by combining:

- CPC machine logic imported from [MiSTer-devel/Amstrad_MiSTer](https://github.com/MiSTer-devel/Amstrad_MiSTer)
- openFPGA platform and integration patterns taken from [dave18/OpenFPGA_ZX-Spectrum](https://github.com/dave18/OpenFPGA_ZX-Spectrum)
- Pocket-specific glue in this repository for bridge registers, ROM/media loading, video output, controls, snapshots, and packaging

The current target is CPC 6128 first, with broader CPC family support planned later.

## Current Status

### Working now

- Boots on real Analogue Pocket hardware
- Loads a user-supplied `boot.rom` bundle
- Starts the CPC 6128 firmware
- Produces working video on Pocket
- Outputs CPC audio
- Supports Pocket controls with joystick-style defaults
- Includes a built-in virtual keyboard
- Mounts `.dsk` images in Drive A and Drive B
- Can mount `.cdt` tape images
- Loads `.sna` snapshots
- Exposes Pocket menu options for display framing, disk activity indicator, disk access sound, and restart

### Partially working or untested

- Mounted disk images are effectively read-only because write requests are acknowledged but not persisted yet
- Read-only tape support is working, but it should be treated as experimental
- Dock USB keyboard support works for most common keys, but it should be treated as experimental and not all CPC-specific keys are mapped yet
- Controls are usable, but user-configurable bindings are still on the roadmap

### Not done yet

- Persistent disk writes
- Snapshot saving
- Pocket savestate / Memories support
- CPC 464 / CPC 664 support
- Expansion ROM support

## Install On Pocket

### Release package

For a normal install, copy the release package's `Assets`, `Cores`, and
`Platforms` folders to the root of the Pocket SD card.

If you are copying from a local build instead of a release package, run
`make build` first, then copy these paths to the Pocket SD card:

- `build/package/Platforms/amstrad.json` -> `Platforms/amstrad.json`
- `build/package/Cores/stilvoid.PocketCPC/` -> `Cores/stilvoid.PocketCPC/`
- `build/package/Assets/amstrad/stilvoid.PocketCPC/` -> `Assets/amstrad/stilvoid.PocketCPC/`
- `build/package/Assets/amstrad/common/` -> `Assets/amstrad/common/`

If you are updating from earlier test builds:

- keep `boot.rom` in `Assets/amstrad/stilvoid.PocketCPC/`
- move any optional `.dsk`, `.cdt`, or `.sna` files you want to keep using into `Assets/amstrad/common/`

PocketCPC uses a split asset layout:

- `boot.rom` is core-specific
- optional disks, tapes, and snapshots are platform-common

macOS note: Finder replaces folders instead of merging them. Merge the copied
`Assets`, `Cores`, and `Platforms` folders manually instead of replacing the SD
card copies outright.

## Required `boot.rom`

PocketCPC expects the Amstrad ROM bundle at:

`/Assets/amstrad/stilvoid.PocketCPC/boot.rom`

The simplest option is to use the `boot.rom` published by the MiSTer Amstrad
CPC core project and place it at that path yourself:

- [MiSTer Amstrad_MiSTer releases folder](https://github.com/MiSTer-devel/Amstrad_MiSTer/tree/master/releases)
- [Direct `boot.rom` link](https://github.com/MiSTer-devel/Amstrad_MiSTer/blob/master/releases/boot.rom)

Current required layout:

| Offset | Size | Contents |
| ---: | ---: | --- |
| `0x00000` | `0x4000` | CPC 6128 OS ROM |
| `0x04000` | `0x4000` | CPC 6128 BASIC ROM |
| `0x08000` | `0x4000` | AMSDOS ROM |
| `0x0C000` | `0x4000` | Multiface 2 placeholder / padding |
| `0x10000` | `0x4000` | CPC 664 OS ROM |
| `0x14000` | `0x4000` | CPC 664 BASIC ROM |
| `0x18000` | `0x4000` | CPC 664 AMSDOS ROM |
| `0x1C000` | `0x4000` | CPC 664 Multiface 2 placeholder / padding |
| `0x20000` | `0x4000` | CPC 464 OS ROM |
| `0x24000` | `0x4000` | CPC 464 BASIC ROM |

Current loader contract:

- `boot.rom` must be exactly `0x28000` bytes (160 KiB)
- the placeholder banks at `0x0C000` and `0x1C000` still need to be present so the later ROMs stay at fixed offsets
- expansion ROM pages are not part of the current PocketCPC boot bundle yet

See `docs/ROM_ASSET_LAYOUT.md` for the exact current layout and rationale.

## Media Files

Place optional media anywhere under:

`/Assets/amstrad/common/`

The required ROM bundle stays separate at:

`/Assets/amstrad/stilvoid.PocketCPC/boot.rom`

Subdirectories are fine. A simple layout such as this works well:

- `/Assets/amstrad/common/disks/*.dsk`
- `/Assets/amstrad/common/tapes/*.cdt`
- `/Assets/amstrad/common/snapshots/*.sna`

## How To Use It

### First boot

1. Install the core and make sure `boot.rom` is present at `/Assets/amstrad/stilvoid.PocketCPC/boot.rom`.
2. Start the core from openFPGA on the Pocket.
3. If the ROM bundle is valid, the CPC 6128 firmware should boot.

### Mounting media

Open the Pocket menu, go to `Core Settings`, and use these entries:

- `Drive A`: mount or change a `.dsk` image
- `Drive B`: mount or change a second `.dsk` image
- `Tape`: mount a `.cdt` tape image
- `Snapshot`: load a `.sna` snapshot
- `Restart Core`: reboot the machine after changing media if needed

Mounted `.dsk` images should currently be treated as read-only in practice:
write activity is acknowledged so software keeps running, but no disk changes
are persisted back to the image yet.

Useful CPC disk commands:

- `CAT` lists files on the current disk
- `RUN"` loads and starts a program, for example `RUN"DISC`
- `|A` and `|B` switch between disk drives

### Default controls

Normal play:

- D-pad: joystick directions
- `A`: joystick fire 1
- `B`: joystick fire 2
- `X`: joystick fire 3
- `Y`: `Escape`
- `L`: `Shift`
- `R`: `Ctrl`
- `Select`: toggle virtual keyboard
- `Start`: currently unbound

Virtual keyboard mode:

- D-pad: move selection
- `A`: press selected key
- `B`: `Space`
- `X`: `Return`
- `Y`: `Delete`
- `Select`: close virtual keyboard

Dock USB keyboard support is available through the Analogue Dock, but it should
still be treated as experimental:

- most common typing keys and modifiers work
- not every CPC-specific key is mapped yet
- `COPY` is currently unmapped from USB keyboard input

### Pocket menu options

`Core Settings` currently includes:

- media reload entries for `Drive A`, `Drive B`, `Tape`, and `Snapshot`
- `Display Framing`: `Default`, `Tight`, `Overscan`
- `Activity Indicator`
- `Disk Access Sound`
- `Restart Core`

## Development Requirements

For development and local builds you need:

- An Analogue Pocket with openFPGA support
- A valid Amstrad CPC `boot.rom` bundle supplied by the user
- `git`
- `python3`
- Either:
  - Docker, using `raetro/quartus:18.1`, or
  - A local Quartus setup capable of building the openFPGA project

Notes:

- ROMs are not included here.

## Build From Source

### Build the Pocket core

Docker build:

```bash
make build
```

`make build` already streams the Quartus output as it runs. If you need to
inspect or manage a long-running build directly, use the build script:

```bash
scripts/build_core_docker.sh status
scripts/build_core_docker.sh log
scripts/build_core_docker.sh wait
scripts/build_core_docker.sh stop
scripts/build_core_docker.sh freshness
```

The packaged Pocket bitstream is written to:

`build/package/Cores/stilvoid.PocketCPC/bitstream.rbf_r`

Upstream reference checkouts under `upstreams/` are only needed for development work on the project itself, not for building the current PocketCPC core from this repository state.

`make build` stages a complete installable package under `build/package/`.
Quartus runs inside `build/quartus/`, so the tracked source tree stays clean.

`make build` uses file dependencies, so Quartus only reruns when tracked FPGA
inputs change. Package staging and metadata checks rerun only when the files
they cover change.

### Automatic install from the repository

From the repository root:

```bash
make install
```

By default this installs to:

- `/Volumes/Pocket`

Useful options:

```bash
POCKET_SD=/path/to/Pocket make install
```

`POCKET_SD` is the main user-facing `make` override. The rest of the path layout
is internal to the repository.

`make install` will:

- build the release zip first when relevant inputs changed
- unzip that packaged release into the Pocket SD layout

After install, place `boot.rom` yourself in
`Assets/amstrad/stilvoid.PocketCPC/` before booting the core.

### Release zip from the repository

From the repository root:

```bash
make dist
```

This writes a release zip such as `dist/stilvoid.PocketCPC-0.1.0.zip`.

The zip is ready to extract at the root of a Pocket SD card. Users still need
to supply `boot.rom` separately.

## Repository Layout

- `src/fpga/`: Quartus project and HDL sources
- `src/pocket/`: Pocket package template metadata and static assets
- `build/quartus/`: generated Quartus workspace
- `build/package/`: staged installable Pocket package
- `AGENTS.md`: contributor working guide and reference-core reuse policy
- `docs/DEVELOPER_GUIDE.md`: architecture and code-reading guide
- `docs/COMPONENT_MAP.md`: reference-core ownership map
- `docs/CPC_IMPORT_MANIFEST.md`: provenance map for imported MiSTer-derived files
- `docs/ROM_ASSET_LAYOUT.md`: exact `boot.rom` layout expected by the core
- GitHub Releases: published build packages and release bitstreams

## Known Limitations

- This is still an early release. Expect rough edges and occasional regressions.
- Disk writes are acknowledged for compatibility but are not persisted yet. Treat mounted `.dsk` images as disposable copies for now.
- Pocket savestates / Memories are not currently supported.
- Tape, snapshot load/save, and media edge cases still need broader validation.
- There is no finished user-friendly control remapping UI yet.
- The repository contains code derived from multiple upstream sources with mixed licensing terms and notices preserved in-file. Review file headers and upstream projects before redistributing derived work.

## Developer Notes

If you are here to work on the core rather than just use it, start with:

- `CONTRIBUTING.md`
- `AGENTS.md`
- `docs/DEVELOPER_GUIDE.md`
- `docs/COMPONENT_MAP.md`
- `docs/CPC_IMPORT_MANIFEST.md` if you are touching imported CPC machine files

## ROMs And Copyright

Do not commit or redistribute copyrighted Amstrad ROM images unless you are sure you have the right to do so. This repository intentionally does not ship them.
