# Input Binding Plan

This note captures the practical options for configurable Pocket button
bindings in this core.

## What the Pocket framework gives us

- `input.json` is a read-only Controls-menu description. It names the current
  bindings for the user, but it does not provide a user-editable remapping UI.
- `interact.json` can expose persistent menu variables and one-shot actions
  backed by bridge registers.

That means "let the user bind any Pocket button to any CPC key" cannot be
delivered just by editing metadata. We need our own binding table in HDL and a
UI that writes into it.

## Recommended implementation order

### Phase 1: bridge-backed binding table

Move the hard-coded button mapping in `cpc_pocket_input.sv` behind a small
runtime table:

- one entry per Pocket button we want configurable
- each entry selects either `unbound`, `joystick direction/fire`, or a CPC
  PS/2 key event
- keep Select reserved for the virtual keyboard toggle
- keep the D-pad defaulted to joystick directions

This makes the translation layer flexible without touching the imported CPC HID
path.

### Phase 2: menu-driven presets plus limited per-button remaps

Use `interact.json` for the first user-facing version:

- one `Control Preset` list for common schemes
- per-button lists for `A`, `B`, `X`, `Y`, `L`, `R`, and `Start`
- start with a curated option set instead of the entire CPC keyboard

Suggested option groups:

- joystick fire buttons
- `Space`, `Enter`, `Escape`, `Delete`
- `Shift`, `Ctrl`
- a few high-value game keys such as `1`, `2`, `P`

This is the fastest way to ship useful remapping, and `persist: true` will let
Pocket remember the chosen settings.

## Why not expose every CPC key in the stock Pocket menu

It is technically possible, but the UX would be poor:

- every configurable button would need a large static list
- the flat OSD menu would become long and repetitive
- maintaining full-keyboard lists in JSON would be error-prone

## Best long-term UI

If we want true "bind anything to anything", the better path is a custom
binding editor:

- enter a `Configure Controls` mode from the Pocket menu
- pick a Pocket button
- choose a CPC key or joystick function from an on-screen editor
- write the result into the bridge-backed binding table

That could live in a custom OSD page or in an expanded virtual-keyboard-style
overlay. The stock Pocket metadata is good for presets and a handful of common
overrides, but not for a full rebinding UI.

