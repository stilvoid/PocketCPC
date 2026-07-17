# CPC ROM Asset Layout

## Files

`Assets/amstrad/stilvoid.PocketCPC/boot.rom`

`Assets/amstrad/stilvoid.PocketCPC/custom.rom` optional experimental upper ROM

ROMs are user-supplied. Do not commit copyrighted ROM images.

The stock bundle used by PocketCPC is the same `boot.rom` published by the
MiSTer Amstrad CPC core in its `releases/` folder.

## Current required layout

| Offset | Size | Description |
| ---: | ---: | --- |
| `0x00000` | `0x4000` | CPC6128 OS ROM |
| `0x04000` | `0x4000` | CPC6128 BASIC ROM |
| `0x08000` | `0x4000` | AMSDOS ROM |
| `0x0C000` | `0x4000` | CPC6128 Multiface 2 placeholder/padding |
| `0x10000` | `0x4000` | CPC664 OS |
| `0x14000` | `0x4000` | CPC664 BASIC |
| `0x18000` | `0x4000` | CPC664 AMSDOS |
| `0x1C000` | `0x4000` | CPC664 Multiface 2 placeholder/padding |
| `0x20000` | `0x4000` | CPC464 OS |
| `0x24000` | `0x4000` | CPC464 BASIC |

Current build and packaging assumptions:

- `boot.rom` is exactly `0x28000` bytes, or ten 16 KiB banks
- the placeholder banks keep the later model ROMs at the same offsets used by MiSTer
- the Pocket menu selects model `0 = CPC6128`, `1 = CPC664`, `2 = CPC464`
- `custom.rom`, when present, must be exactly `0x4000` bytes
- `custom.rom` is mapped to CPC upper ROM select `0x06`
- the current experiment exposes that slot on CPC 6128, CPC 664, and CPC 464
- the current experiment exposes only that one extra expansion ROM page

## Why bundle ROMs?

The ZX Spectrum Pocket core uses a consolidated `boot.rom` model. That same shape is convenient here because it avoids multiple early file-loading paths and lets the CPC machine see deterministic ROM pages at reset.
