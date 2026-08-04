# Input Architecture

This document describes the current PocketCPC design for Pocket controls, the
virtual keyboard, session remapping, and the experimental Dock USB keyboard
path.

It is an architecture note for the current design, not a promise that the
control scheme is final. This subsystem is expected to keep evolving.

## Scope

This document covers:

- Pocket button and D-pad handling
- the split between joystick output and PS/2-style key events
- virtual keyboard behavior
- session-only VKB-driven remapping
- Dock USB keyboard ingestion
- the hardware overlay used to present the VKB and bind state

## Core design choice

PocketCPC does not rewrite the imported CPC keyboard matrix logic.

Instead, `src/fpga/core/cpc_pocket_input.sv` adapts modern Pocket and Dock
inputs into the formats the MiSTer-derived CPC path already understands:

- MiSTer-style joystick bits for `joy1`
- 11-bit PS/2 events for keyboard-like actions

The key event format is:

- `{toggle, pressed, extended, scan_code}`

That boundary is the main architectural rule for this subsystem.

## Top-level split

The input system is intentionally split across two local modules:

- `cpc_pocket_input.sv`
  owns input sampling, mode state, VKB navigation, macro emission, remap state,
  and PS/2/joystick output generation
- `cpc_virtual_keyboard_overlay.sv`
  owns drawing the visible overlay and bind feedback into the video stream

`core_top.sv` wires those outputs into:

- the imported CPC machine's `ps2_key`
- joystick input `joy1`
- overlay control signals for current VKB state

This keeps “what input means” separate from “how the overlay looks”.

## Normal-play mapping

The default runtime mapping is described in
`src/pocket/Cores/stilvoid.PocketCPC/input.json`, but the real behavior lives
in `cpc_pocket_input.sv`.

Current defaults are:

- D-pad -> joystick by default
- `A` -> joystick fire 1
- `B` -> `Space`
- `X` -> `Return`
- `Y` -> `COPY`
- `L` -> `Shift`
- `R` -> `Ctrl`
- `Select` -> open VKB
- `Start` -> `Escape`

This is a deliberate CPC-specific compromise:

- most CPC software effectively expects a one-button joystick
- the spare face buttons are more useful as direct keyboard helpers than as
  extra joystick fire buttons

## D-pad modes

The D-pad is intentionally special-cased.

`src/pocket/Cores/stilvoid.PocketCPC/interact.json` exposes `D-pad Mode` as a
persisted Pocket menu setting with three choices:

- `Joystick`
- `Cursor Keys`
- `QAOP`

`cpc_pocket_input.sv` reads that mode and changes only normal-play D-pad
behavior. It does not affect VKB navigation.

This is a deliberate constraint. The D-pad is not yet part of the arbitrary
session remap table because:

- it is the main navigation control for the VKB itself
- a small set of useful runtime presets is simpler than a full arbitrary
  per-direction mapping UI

## Why the adapter emits both joystick and PS/2 paths

PocketCPC uses both output styles because CPC software expects both kinds of
input depending on the program:

- joystick-driven games want MiSTer-style joystick bits
- keyboard-driven programs want PS/2-derived key events through the existing
  CPC HID path

The adapter therefore does not choose one universal abstraction. It routes:

- D-pad and explicitly bound joystick targets into `joy1`
- button helpers, VKB keys, macros, and Dock keyboard actions into the PS/2
  event stream

The VKB second page also includes joystick directions and fire buttons so the
same UI can bind either path.

## Virtual keyboard architecture

The VKB is a hardware overlay with two pages.

Page `0` is the main CPC keyboard surface.

Page `1` combines:

- function keys
- cursor keys
- joystick directions and fire buttons
- a macro column for common CPC commands

The macro column currently emits:

- `|TAPE` + `Return`
- `|DISC` + `Return`
- `CAT` + `Return`
- `RUN"` + `Return`
- `RUN"DISC` + `Return`

`cpc_pocket_input.sv` owns:

- current selection
- current page
- `Shift`, `Ctrl`, and `Caps` overlay state
- macro timing and staged press/release behavior
- repeat timing for held VKB navigation

`cpc_virtual_keyboard_overlay.sv` turns that state into pixels. It is not a
software widget toolkit; it literally computes which key cell and glyph should
be drawn at each pixel coordinate.

## Session-only remapping

The current custom remap flow is intentionally lightweight:

1. open the VKB
2. highlight a key or joystick target
3. press `Start` to arm bind mode
4. press one of `A/B/X/Y/L/R/Start` to assign it

Those remaps live only inside `cpc_pocket_input.sv` state:

- they are session-only
- they reset on core reset or restart
- they are not currently persisted through the Pocket menu or a bridge-side
  profile format

That choice is deliberate for now. The current goal is fast per-session repair
of awkward game mappings, not a full profile-management system.

## Effective bindings and overlay feedback

The remap system does not only store custom assignments. It also exposes the
effective current bindings back to the overlay.

`cpc_pocket_input.sv` exports:

- which bind slots are valid
- the currently effective VKB index per remappable button
- the currently effective page per remappable button

`cpc_virtual_keyboard_overlay.sv` uses that to:

- highlight currently bound targets
- show bind-mode status
- show short post-bind feedback
- show which Pocket button or buttons currently point at the selected target

This is why the overlay module receives binding buses rather than trying to
infer state from the currently selected key alone.

## Dock USB keyboard path

Dock keyboard support is handled in `cpc_pocket_input.sv` by sampling:

- `cont3_key`
- `cont3_joy`
- `cont3_trig`

Those APF words are interpreted as a compact USB HID report:

- one modifier byte set
- a small set of simultaneous keycodes

The adapter compares the latest report against the previously active report and
emits the corresponding PS/2-style press/release events into the existing CPC
keyboard path.

Current design intent:

- preserve ordinary typing keys and modifiers
- map CPC-specific helpers where needed
- prefer adapter-layer translation over changes inside the imported CPC HID
  blocks

Current documented special cases include:

- `Insert` -> `COPY`
- `Right Alt` fallback for `COPY` on compact keyboards
- keypad `Enter` -> CPC keypad `Enter`
- keypad `.` -> `FDot`
- ISO/UK `#~` -> CPC `]`
- ANSI grave and ISO non-US backslash feeding the CPC backslash key

This path is still experimental and expects more hardware validation.

## Joystick suppression while VKB is open

One subtle design choice is that the normal joystick path is blanked while the
VKB is open so overlay navigation does not leak into running software.

The main exception is the highlighted VKB joystick target, which can still be
activated directly for testing and bind setup.

That behavior is intentional. Do not “fix” it by letting normal D-pad
navigation drive both the overlay and the game at once.

## Why this is not persisted yet

A natural future change would be persisted remap profiles. The current design
does not do that yet because it would require more than just saving a few bits:

- a stable Pocket-facing or bridge-facing storage contract
- a menu/UI story for editing and choosing profiles
- careful interaction with default bindings and VKB feedback

Until that exists, session-only remaps are the simpler and safer choice.

## Key files

The main files for this subsystem are:

- `src/fpga/core/cpc_pocket_input.sv`
- `src/fpga/core/cpc_virtual_keyboard_overlay.sv`
- `src/pocket/Cores/stilvoid.PocketCPC/input.json`
- `src/pocket/Cores/stilvoid.PocketCPC/interact.json`
- `src/fpga/core/core_top.sv`

## What should not be “simplified”

These choices are easy to flatten away, but they are currently deliberate:

- keep emitting PS/2-style events into the imported CPC keyboard path
- keep joystick and PS/2 outputs as separate concepts
- keep D-pad mode as a small preset list instead of arbitrary per-direction
  remapping
- keep overlay drawing separate from input-state generation
- keep remaps session-only until a real persistence design exists
- keep Dock keyboard translation local to the adapter layer
