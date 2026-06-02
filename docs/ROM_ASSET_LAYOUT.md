# Proposed CPC ROM Asset Layout

## File

`Assets/amstrad/steve.AmstradCPC/boot.rom`

ROMs are user-supplied. Do not commit copyrighted ROM images.

## MVP layout

| Offset | Size | Description |
| ---: | ---: | --- |
| `0x00000` | `0x4000` | CPC6128 OS ROM |
| `0x04000` | `0x4000` | CPC6128 BASIC ROM |
| `0x08000` | `0x4000` | AMSDOS ROM |
| `0x0C000` | `0x4000` | Reserved/padding |

## Extended layout

| Offset | Size | Description |
| ---: | ---: | --- |
| `0x10000` | `0x4000` | CPC464 OS |
| `0x14000` | `0x4000` | CPC464 BASIC |
| `0x18000` | `0x4000` | CPC664 OS |
| `0x1C000` | `0x4000` | CPC664 BASIC |
| `0x20000` | `0x4000` | CPC664 AMSDOS |
| `0x24000` | `0x4000` | Multiface 2 ROM |
| `0x28000` | variable | Expansion ROM pages, 16K each |

## Why bundle ROMs?

The ZX Spectrum Pocket core uses a consolidated `boot.rom` model. That same shape is convenient here because it avoids multiple early file-loading paths and lets the CPC machine see deterministic ROM pages at reset.
