# PocketCPC

PocketCPC is an Amstrad CPC core for the [Analogue Pocket openFPGA](https://www.analogue.co/developer/docs/overview).

Status: early public release. It is hardware-tested and usable now, but some features are still incomplete and a few areas remain experimental.

PocketCPC currently boots the CPC 6128 firmware, loads user-supplied ROMs, supports `.dsk` disks, `.cdt` tapes, and `.sna` snapshots, and includes a built-in virtual keyboard with shortcut macros. It is built by adapting [MiSTer-devel/Amstrad_MiSTer](https://github.com/MiSTer-devel/Amstrad_MiSTer) for CPC machine behaviour and [dave18/OpenFPGA_ZX-Spectrum](https://github.com/dave18/OpenFPGA_ZX-Spectrum) for Analogue Pocket integration.

This project was developed with AI assistance, directed by a human who knows and cares about the Amstrad CPC.

For licensing and provenance details, see [LICENSE.md](https://github.com/stilvoid/PocketCPC/blob/main/LICENSE.md).

## Install On Pocket

For a normal install, download the [latest release](https://github.com/stilvoid/PocketCPC/releases/latest) and copy its `Assets`, `Cores`, and `Platforms` folders to the root of the Pocket SD card.

Then place the required ROM bundle here:

`/Assets/amstrad/stilvoid.PocketCPC/boot.rom`

Optional media goes anywhere under:

`/Assets/amstrad/common/`

A simple SD-card layout looks like this:

- `Assets/amstrad/stilvoid.PocketCPC/boot.rom`
- `Assets/amstrad/common/disks/*.dsk`
- `Assets/amstrad/common/tapes/*.cdt`
- `Assets/amstrad/common/snapshots/*.sna`
- `Cores/stilvoid.PocketCPC/*`
- `Platforms/amstrad.json`

## Required `boot.rom`

PocketCPC expects the same `boot.rom` bundle published by the MiSTer Amstrad CPC core project:

- [MiSTer Amstrad_MiSTer releases folder](https://github.com/MiSTer-devel/Amstrad_MiSTer/tree/master/releases)
- [Direct `boot.rom` link](https://github.com/MiSTer-devel/Amstrad_MiSTer/blob/master/releases/boot.rom)

Current loader requirements:

- `boot.rom` must be exactly `0x28000` bytes (160 KiB)
- the file must live at `Assets/amstrad/stilvoid.PocketCPC/boot.rom`
- the current public flow is centered on CPC 6128 booting

See [docs/ROM_ASSET_LAYOUT.md](https://github.com/stilvoid/PocketCPC/blob/main/docs/ROM_ASSET_LAYOUT.md) for the exact bank layout and rationale.

## First Boot And Use

Start with the release package installed, `boot.rom` in `Assets/amstrad/stilvoid.PocketCPC/boot.rom`, and any optional `.dsk`, `.cdt`, or `.sna` files copied somewhere under `Assets/amstrad/common/`.

Then:

1. Start `PocketCPC` from openFPGA on the Pocket.
2. If the ROM bundle is valid, the core should boot to the normal CPC startup screen.
3. Open the Pocket menu and go to `Core Settings` when you want to mount media or restart the core.

### Core Settings

The Pocket menu's `Core Settings` entries do this:

- `Drive A`: mount or change the disk image in drive A
- `Drive B`: mount or change the disk image in drive B
- `Tape`: mount or change a tape image
- `Snapshot`: load a snapshot immediately
- `Display Framing`: choose `Default`, `Tight`, or `Overscan`
- `Activity Indicator`: show or hide the disk activity overlay
- `Disk Access Sound`: enable or disable drive access sound effects
- `Restart Core`: reboot the CPC after changing media or settings

### Load software

Typical flow for a disk:

1. Mount a `.dsk` in `Drive A`.
2. Return to the CPC screen.
3. Type `CAT` to list files on the disk.
4. Start a program with `RUN"PROGRAM` or whatever command that disk expects.

Useful CPC disk commands:

- `CAT` lists files on the current disk
- `RUN"` loads and starts a program, for example `RUN"DISC`
- `|A` and `|B` switch between disk drives

Typical flow for a tape:

1. Mount a `.cdt` in `Tape`.
2. Return to the CPC screen.
3. Type `|TAPE` to switch to tape mode.
4. Type `RUN"` to start loading.

Typical flow for a snapshot:

1. Mount a `.sna` in `Snapshot`.
2. The snapshot should start immediately.

### Default controls

Normal play:

- D-pad: joystick directions
- `A`: joystick fire 1
- `B`: joystick fire 2
- `X`: joystick fire 3
- `Y`: `Escape`
- `L`: `Shift`
- `R`: `Ctrl`
- `Select`: open virtual keyboard
- `Start`: currently unbound

Most CPC software expects a one-button joystick. `Fire 2` and `Fire 3` are
extra compatibility mappings and may be ignored by many programs.

Virtual keyboard mode:

- D-pad: move selection
- `A`: press selected key
- `B`: `Space`
- `X`: `Return`
- `Y`: `Delete`
- `L`: `Shift`
- `R`: next VKB page
- `Select`: close virtual keyboard
- `Start`: currently unbound

The VKB includes a shortcut page with one-tap macros for:

- `|TAPE` + `Return`
- `|DISC` + `Return`
- `CAT` + `Return`
- `RUN"` + `Return`
- `RUN"DISC` + `Return`

Dock USB keyboard support is available through the Analogue Dock, but it is
still experimental. Most common typing keys and modifiers work, but some
CPC-specific mappings are still incomplete, including `COPY`.

## Current Limitations

- Mounted `.dsk` images should currently be treated as read-only. Write activity is acknowledged so software keeps running, but changes are not persisted back to the image yet.
- Pocket savestates / Memories are not currently supported.
- Tape support works but should still be treated as experimental.
- Snapshot loading is supported, but snapshot saving is not currently exposed as a finished feature.
- There is no finished user-friendly control remapping UI yet.
- CPC 464 and CPC 664 are present in the ROM bundle layout, but the user-facing experience is still centered on CPC 6128.

## Reporting Issues

Please report bugs through [GitHub Issues](https://github.com/stilvoid/PocketCPC/issues).

The most useful reports include:

- the PocketCPC release version or commit you tested
- whether you were using Pocket or Dock
- the exact steps needed to reproduce the problem
- what you expected to happen and what happened instead
- which media type was involved: `.dsk`, `.cdt`, `.sna`, or bare boot
- any relevant menu settings, controller input, or keyboard input needed to trigger it

Reproducible reports are much easier to investigate than general "it broke"
descriptions.

## Developer Notes

If you are here to build or work on the core rather than just use it, start with:

- [CONTRIBUTING.md](https://github.com/stilvoid/PocketCPC/blob/main/CONTRIBUTING.md)
- [AGENTS.md](https://github.com/stilvoid/PocketCPC/blob/main/AGENTS.md)
- [docs/DEVELOPER_GUIDE.md](https://github.com/stilvoid/PocketCPC/blob/main/docs/DEVELOPER_GUIDE.md)
- [docs/COMPONENT_MAP.md](https://github.com/stilvoid/PocketCPC/blob/main/docs/COMPONENT_MAP.md)
- [docs/ROM_ASSET_LAYOUT.md](https://github.com/stilvoid/PocketCPC/blob/main/docs/ROM_ASSET_LAYOUT.md)
- [TODO.md](https://github.com/stilvoid/PocketCPC/blob/main/TODO.md)

Build requirements:

- `git`
- `python3`
- Docker using `raetro/quartus:18.1`, or a local Quartus setup capable of building the project
- a user-supplied CPC `boot.rom` bundle for real use on hardware

Useful commands from the repository root:

```bash
make build
make dist
make install
```

`make build` stages an installable package under `build/package/`.
`make dist` writes a release zip under `dist/`.
`make install` installs the release package to a Pocket SD card, defaulting to
`/Volumes/Pocket`, and can be redirected with:

```bash
POCKET_SD=/path/to/Pocket make install
```

For deeper build troubleshooting, use:

```bash
scripts/build_core_docker.sh status
scripts/build_core_docker.sh log
scripts/build_core_docker.sh wait
scripts/build_core_docker.sh stop
scripts/build_core_docker.sh freshness
```

## ROMs And Copyright

Do not commit or redistribute copyrighted Amstrad ROM images unless you are sure you have the right to do so. This repository intentionally does not ship them.

This repository contains a mix of original PocketCPC glue, adapted upstream code, and preserved notices from those upstream sources. Review [LICENSE.md](https://github.com/stilvoid/PocketCPC/blob/main/LICENSE.md) and the relevant file headers before redistributing derived work.
