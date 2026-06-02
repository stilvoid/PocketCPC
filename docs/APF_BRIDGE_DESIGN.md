# APF Bridge Design Proposal

## Principle

Expose a small Pocket-facing register block that replaces the MiSTer `status`, `buttons`, and `ioctl_*` interfaces. Keep this separate from the CPC machine so the core remains testable.

## Clock domain

- APF bridge bus is synchronous to `clk_74a`.
- CPC machine likely runs on a generated `clk_sys`.
- Use small CDC synchronizers/FIFOs for command pulses and streaming data.

## Suggested register map

| Address | Width | Direction | Purpose |
| --- | ---: | --- | --- |
| `0x0000` | 32 | R | Core ID/version. |
| `0x0004` | 32 | R/W | Control: reset, cold reset, apply config, pause. |
| `0x0008` | 32 | R/W | Model/config bits. |
| `0x000C` | 32 | R/W | Video/audio options. |
| `0x0010` | 32 | R/W | Mounted media flags. |
| `0x0014` | 32 | R | Status: ROM loaded, disk busy, tape active, error flags. |
| `0x0020` | 32 | W | Loader slot select. |
| `0x0024` | 32 | W | Loader byte address. |
| `0x0028` | 32 | W | Loader data word. |
| `0x002C` | 32 | W | Loader command: start/write/finish/cancel. |
| `0x0030` | 32 | R | Loader status/flow control. |
| `0x0040` | 32 | W | Keyboard matrix override/virtual key event. |
| `0x0044` | 32 | W | Joystick mapping. |

## Asset slots

| Slot | Type | MVP | Purpose |
| ---: | --- | --- | --- |
| 0 | ROM | Yes | `boot.rom` CPC ROM bundle. |
| 1 | DSK | Yes | Drive A read-only. |
| 2 | DSK | Later | Drive B. |
| 3 | CDT | Later | Tape. |
| 4 | SNA | Later | Snapshot. |
| 5 | ROM | Later | Expansion ROM. |
| 6 | ROM | Later | Dandanator. |

## Loader behavior

1. Host selects slot.
2. Host streams bytes/words to loader.
3. Loader writes into target memory or media cache.
4. Host signals finish.
5. Core validates minimum size/hash where useful.
6. Control register releases CPC from reset.

## First implementation shortcut

For MVP, skip generic streaming complexity if easier:

- Store `boot.rom` in inferred ROM/BRAM initialized by build asset flow, or load it into simple RAM at startup.
- Mount DSK A as a read-only data slot with a sector cache.
- Do not implement generic expansion slot writes until boot + Drive A work.
