# PocketCPC

PocketCPC is an Amstrad CPC core for the [Analogue Pocket openFPGA](https://www.analogue.co/developer/docs/overview).

Status: early public release. It is hardware-tested and usable, but some features are still incomplete and a few areas remain experimental.

PocketCPC defaults to CPC 6128 and can also switch to CPC 664 or CPC 464 from the Pocket menu. It supports `.dsk` disks, `.cdt` tapes, `.sna` snapshots, and a built-in virtual keyboard with shortcut macros. It is built by adapting [MiSTer-devel/Amstrad_MiSTer](https://github.com/MiSTer-devel/Amstrad_MiSTer) for CPC machine behaviour and [dave18/OpenFPGA_ZX-Spectrum](https://github.com/dave18/OpenFPGA_ZX-Spectrum) for Analogue Pocket integration.

This project was developed with AI assistance, directed by a human who knows and cares about the Amstrad CPC.

For licensing and provenance details, see [LICENSE.md](https://github.com/stilvoid/PocketCPC/blob/main/LICENSE.md).

## Install On Pocket

For a normal install, download the [latest release](https://github.com/stilvoid/PocketCPC/releases/latest) and copy its `Assets`, `Cores`, and `Platforms` folders to the root of the Pocket SD card.

Then place the required ROM bundle here:

`/Assets/amstrad/stilvoid.PocketCPC/boot.rom`

Optional experimental custom ROM:

`/Assets/amstrad/stilvoid.PocketCPC/custom.rom`

Optional media goes anywhere under:

`/Assets/amstrad/common/`

A simple SD-card layout looks like this:

- `Assets/amstrad/stilvoid.PocketCPC/boot.rom`
- `Assets/amstrad/stilvoid.PocketCPC/custom.rom` optional, 16 KiB, maps to upper ROM slot `6`
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
- the Pocket menu defaults to CPC 6128 and can switch to CPC 664 or CPC 464
- `custom.rom` is an experimental optional 16 KiB upper ROM mapped to slot `6`

See [docs/ROM_ASSET_LAYOUT.md](https://github.com/stilvoid/PocketCPC/blob/main/docs/ROM_ASSET_LAYOUT.md) for the exact bank layout and rationale.

## First Boot And Use

1. Start `PocketCPC` from openFPGA on the Pocket.
2. If the ROM bundle is valid, the core should boot to the normal CPC startup screen.
3. Open the Pocket menu and go to `Core Settings` when you want to mount media or restart the core. Entering the Pocket menu pauses the running CPC and leaving the menu resumes it.

### Core Settings

The Pocket menu's `Core Settings` entries do this:

- `Machine Model`: choose `CPC 6128`, `CPC 664`, or `CPC 464`; changing it resets the core immediately, and it defaults back to `CPC 6128` on the next launch
  `CPC 464` follows stock hardware more closely and does not expose the built-in FDC.
- `Drive A`: mount or change the disk image in drive A
- `Drive B`: mount or change the disk image in drive B
- `Tape`: mount or change a tape image
- `Snapshot`: load a snapshot immediately
- `Display Framing`: choose `Default`, `Tight`, or `Overscan`
- `D-pad Mode`: choose `Joystick`, `Cursor Keys`, or `QAOP` for normal play
- `Activity Indicator`: show or hide the disk activity overlay
- `Disk Access Sound`: enable or disable drive access sound effects
- `Stereo Mix`: enable or disable the default 25% stereo crossfeed
- `Restart Core`: reboot the CPC after changing media or settings

`custom.rom` is an experimental optional upper ROM. It must be exactly 16 KiB, lives at `Assets/amstrad/stilvoid.PocketCPC/custom.rom`, and is exposed as CPC upper ROM slot `6`. Restart the core after adding, removing, or replacing it.

### Load software

Typical flow for a disk:

1. Mount a `.dsk` in `Drive A`.
2. Return to the CPC screen.
3. Type `CAT` to list files on the disk.
4. Start a program with `RUN"PROGRAM` or whatever command that disk expects.

This applies directly to CPC 6128 and CPC 664. In CPC 464 mode, the core follows stock hardware more closely and does not expose the built-in FDC.

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

### Convert snapshots and savestates

PocketCPC savestates contain a CPC `.sna`-compatible payload inside a
Pocket-owned `.sta` wrapper. The helper script can extract that payload or wrap
a `.sna` snapshot for use as a Pocket Memory:

```bash
python3 scripts/pocketcpc_savestate.py to-sna input.sta output.sna
python3 scripts/pocketcpc_savestate.py to-sta input.sna output.sta
```

For `.sna` to `.sta`, the script generates the observed Pocket Memory wrapper
metadata for PocketCPC, labels the generated Memory from the input snapshot
filename, and uses a blank thumbnail. Pass `--asset-name` if you want a
different generated label. You can still pass `--template existing.sta` if you
want to preserve the Pocket-side wrapper, metadata, and thumbnail from a real
PocketCPC Memory while replacing only the embedded snapshot payload. The script
normalizes SNA v1 headers to v2 by default and preserves v2/v3 payloads.

### Default controls

Normal play:

- D-pad: joystick directions by default, or `Cursor Keys` / `QAOP` through `Core Settings` -> `D-pad Mode`
- `A`: joystick fire 1
- `B`: joystick up
- `X`: `Space`
- `Y`: `Return`
- `L`: `Shift`
- `R`: `Ctrl`
- `Select`: open virtual keyboard
- `Start`: `Escape`

Most CPC software expects a one-button joystick. `B` therefore doubles as a
second easy-reach joystick-up input for jump-heavy games, while the remaining
spare Pocket face buttons stay available for common CPC keys.

Virtual keyboard mode:

- D-pad: move selection
- `A`: press selected key
- `B`: `Delete`
- `X`: `Space`
- `Y`: `Return`
- `L`: `Shift`
- `R`: next VKB page
- `Select`: close virtual keyboard, or cancel button-bind mode
- `Start`: arm button-bind mode for the highlighted key

The VKB uses two pages. The second page combines function keys, cursor keys,
joystick directions/fire buttons, and a right-hand full-text macro column for:

- `|TAPE` + `Return`
- `|DISC` + `Return`
- `CAT` + `Return`
- `RUN"` + `Return`
- `RUN"DISC` + `Return`

### Session button remap

PocketCPC can temporarily remap `A`, `B`, `X`, `Y`, `L`, `R`, or `Start` to
any single CPC key or joystick action exposed in the VKB.

Flow:

1. Open the virtual keyboard.
2. Highlight the CPC key you want.
3. Press `Start` to arm bind mode for that highlighted key.
4. Press the Pocket button you want to remap.

While bind mode is armed, the highlighted VKB key changes colour and `Select`
cancels bind mode instead of closing the VKB. A banner appears while bind mode
is armed, and a short confirmation message appears after a button is assigned.
These remaps are session-only and reset when the core resets or restarts. The
VKB second page also includes joystick directions plus joystick fire buttons
`1`, `2`, and `3`, so those actions can be tested directly from the VKB or
assigned to Pocket buttons. Any VKB target that is currently bound is
highlighted, including the default Pocket mappings when they have not been
overridden, and moving the selection onto it shows which Pocket button or
buttons currently point at that target.

Dock USB keyboard support is available through the Analogue Dock, but it is
still experimental. Most common typing keys and modifiers work, including
`COPY` on `Insert` with a `Right Alt` fallback for compact keyboards. Numpad
keys follow the CPC keypad layout, including numpad `Enter` -> CPC `Enter` and
numpad `.` -> `FDot`. On ISO/UK layouts, the `#~` key maps to CPC `]`.

## Current Limitations

- Mounted `.dsk` images should currently be treated as read-only. Write activity is acknowledged so software keeps running, but changes are not persisted back to the image yet.
- Pocket savestates / Memories are supported experimentally through an external-PSRAM staging path with a SNA v3-compatible staged payload. See `docs/SAVESTATE_DEVLOG.md` before changing the implementation.
- Pocket sleep/wake resume uses the same experimental savestate path. It is hardware-proven for basic restore flows and now uses native APF setup loading for visible wake progress, but broader media and in-flight hardware state coverage still needs validation.
- Savestate creation is currently rejected during active disk or tape activity, and tape runtime position is not preserved yet.
- Pocket-created Memories currently appear under the `boot` label because the Pocket anchors them to the required `boot.rom` asset rather than runtime-loaded `.dsk`, `.cdt`, or `.sna` media. Converted Memories can use a better label through `scripts/pocketcpc_savestate.py`.
- Tape support works but should still be treated as experimental.
- Snapshot loading is supported, but snapshot saving is not currently exposed as a finished feature.
- Custom remaps are still session-only, and the physical D-pad can only switch between the built-in `Joystick`, `Cursor Keys`, and `QAOP` presets rather than arbitrary per-button bindings.
- Only one experimental custom upper ROM slot is currently exposed, fixed as `custom.rom` -> slot `6`.

## Reporting Issues

Please report bugs through [GitHub Issues](https://github.com/stilvoid/PocketCPC/issues).

The most useful reports include the PocketCPC version or commit tested, whether you were using Pocket or Dock, exact reproduction steps, the media type involved, and any relevant menu or input details.

## Developer Notes

If you are here to build or work on the core rather than just use it, start with:

- [CONTRIBUTING.md](https://github.com/stilvoid/PocketCPC/blob/main/CONTRIBUTING.md)
- [AGENTS.md](https://github.com/stilvoid/PocketCPC/blob/main/AGENTS.md)
- [docs/DEVELOPER_GUIDE.md](https://github.com/stilvoid/PocketCPC/blob/main/docs/DEVELOPER_GUIDE.md)
- [docs/COMPONENT_MAP.md](https://github.com/stilvoid/PocketCPC/blob/main/docs/COMPONENT_MAP.md)
- [docs/ROM_ASSET_LAYOUT.md](https://github.com/stilvoid/PocketCPC/blob/main/docs/ROM_ASSET_LAYOUT.md)
- [TODO.md](https://github.com/stilvoid/PocketCPC/blob/main/TODO.md)

## ROMs And Copyright

Do not commit or redistribute copyrighted Amstrad ROM images unless you are sure you have the right to do so. This repository intentionally does not ship them.

This repository contains a mix of original PocketCPC glue, adapted upstream code, and preserved notices from those upstream sources. Review [LICENSE.md](https://github.com/stilvoid/PocketCPC/blob/main/LICENSE.md) and the relevant file headers before redistributing derived work.
