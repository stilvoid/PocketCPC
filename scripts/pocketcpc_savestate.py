#!/usr/bin/env python3
"""Convert PocketCPC Pocket Memories and CPC .sna snapshots.

Pocket `.sta` files contain a Pocket-owned wrapper around a core-defined blob.
For PocketCPC, that core-defined blob is currently a CPC `.sna`-compatible
snapshot payload. Extraction is therefore direct. Creating a `.sta` can either
preserve an existing PocketCPC `.sta` wrapper template or generate the observed
Pocket wrapper metadata with a blank thumbnail.
"""

from __future__ import annotations

import argparse
import zlib
import sys
from dataclasses import dataclass
from pathlib import Path


SNA_MAGIC = b"MV - SNA"
SNA_HEADER_BYTES = 0x100
SUPPORTED_MEM_KB = {64, 128}
POCKETCPC_STA_PREFIX_MAGIC = b"\x01SPA"
POCKETCPC_STA_PREFIX_BYTES = 0x254
POCKETCPC_STA_THUMB_MAGIC = b" IPA"
POCKETCPC_STA_THUMB_WIDTH = 121
POCKETCPC_STA_THUMB_HEIGHT = 109
POCKETCPC_STA_WRAPPER_PAYLOAD_UNITS = (0x006, 0x00A)

DEFAULT_CORE_FOLDER = "stilvoid.PocketCPC"
DEFAULT_AUTHOR = "stilvoid"
DEFAULT_CORE_NAME = "PocketCPC"
DEFAULT_CORE_VERSION = "0.2.0"
DEFAULT_PLATFORM_ID = "amstrad"
DEFAULT_PLATFORM_NAME = "Amstrad CPC"


class ConvertError(ValueError):
    """Raised for input files that cannot be safely converted."""


@dataclass(frozen=True)
class SnaInfo:
    offset: int
    version: int
    mem_kb: int
    machine_type: int
    payload_len: int
    file_len: int


@dataclass(frozen=True)
class WrapperMetadata:
    core_folder: str
    author: str
    core_name: str
    core_version: str
    asset_name: str
    platform_id: str
    platform_name: str


def read_file(path: Path) -> bytes:
    try:
        return path.read_bytes()
    except OSError as exc:
        raise ConvertError(f"could not read {path}: {exc}") from exc


def write_file(path: Path, data: bytes, overwrite: bool) -> None:
    if path.exists() and not overwrite:
        raise ConvertError(f"{path} already exists; pass --force to overwrite")
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    except OSError as exc:
        raise ConvertError(f"could not write {path}: {exc}") from exc


def find_sna_payload(data: bytes, path: Path) -> SnaInfo:
    offset = data.find(SNA_MAGIC)
    if offset < 0:
        raise ConvertError(f"{path} does not contain an SNA signature")

    if len(data) < offset + SNA_HEADER_BYTES:
        raise ConvertError(f"{path} contains a truncated SNA header")

    header = data[offset : offset + SNA_HEADER_BYTES]
    version = header[0x10]
    mem_kb = int.from_bytes(header[0x6B:0x6D], "little")
    machine_type = header[0x6D]

    if mem_kb not in SUPPORTED_MEM_KB:
        raise ConvertError(
            f"{path} reports {mem_kb} KiB RAM; PocketCPC supports only 64 or 128 KiB"
        )

    payload_len = SNA_HEADER_BYTES + (mem_kb * 1024)
    if len(data) < offset + payload_len:
        raise ConvertError(
            f"{path} is truncated: needs {payload_len} bytes from SNA offset "
            f"0x{offset:X}, has {len(data) - offset}"
        )

    return SnaInfo(
        offset=offset,
        version=version,
        mem_kb=mem_kb,
        machine_type=machine_type,
        payload_len=payload_len,
        file_len=len(data),
    )


def normalize_sna_for_pocketcpc(
    payload: bytes,
    info: SnaInfo,
    *,
    model_override: int | None,
    allow_plus: bool,
    keep_version: bool,
) -> tuple[bytes, list[str]]:
    if len(payload) != info.payload_len:
        raise ConvertError("internal error: payload length does not match parsed SNA size")

    warnings: list[str] = []
    normalized = bytearray(payload)

    if info.version not in (1, 2, 3):
        raise ConvertError(f"unsupported SNA version {info.version}; expected 1, 2, or 3")

    machine_type = info.machine_type
    if model_override is not None:
        machine_type = model_override
        warnings.append(f"machine type overridden to {machine_type}")
    elif info.version == 1:
        machine_type = 2 if info.mem_kb == 128 else 0
        warnings.append(
            f"SNA v1 has no CPC type; inferred machine type {machine_type} "
            f"from {info.mem_kb} KiB RAM"
        )
    elif info.version == 2 and machine_type not in (0, 1, 2, 3):
        raise ConvertError(f"SNA v2 has invalid machine type {machine_type}")
    elif info.version == 3 and machine_type not in (0, 1, 2, 3, 4, 5, 6):
        raise ConvertError(f"SNA v3 has invalid machine type {machine_type}")
    elif machine_type == 3:
        machine_type = 2 if info.mem_kb == 128 else 0
        warnings.append(
            f"SNA machine type is unknown; inferred machine type {machine_type} "
            f"from {info.mem_kb} KiB RAM"
        )
    elif machine_type in (4, 5, 6):
        if not allow_plus:
            raise ConvertError(
                "SNA uses a Plus/GX4000 machine type; PocketCPC does not preserve "
                "Plus-specific state. Pass --allow-plus-downgrade if you want to "
                "map it to a classic CPC model anyway."
            )
        downgraded = 0 if machine_type == 5 else 2
        warnings.append(f"downgraded Plus/GX4000 machine type {machine_type} to {downgraded}")
        machine_type = downgraded

    if not keep_version:
        if info.version == 1:
            warnings.append("normalized SNA version 1 to version 2")
            normalized[0x10] = 2
            normalized[0x6D] = machine_type
            normalized[0x6E:SNA_HEADER_BYTES] = b"\x00" * (SNA_HEADER_BYTES - 0x6E)
        else:
            normalized[0x6D] = machine_type
    else:
        if info.version == 1:
            warnings.append(
                "kept SNA version 1; current PocketCPC savestate loading expects v2 or v3"
            )

    return bytes(normalized), warnings


def patch_sta_prefix(prefix: bytes, mem_kb: int) -> tuple[bytes, list[str]]:
    patched = bytearray(prefix)
    warnings: list[str] = []

    if not patched.startswith(POCKETCPC_STA_PREFIX_MAGIC):
        warnings.append("template does not start with the expected Pocket .sta wrapper magic")
        return bytes(patched), warnings

    unit = mem_kb // 64
    for offset in POCKETCPC_STA_WRAPPER_PAYLOAD_UNITS:
        if offset >= len(patched):
            warnings.append(f"template prefix is too short to patch wrapper byte 0x{offset:X}")
            continue
        if patched[offset] not in SUPPORTED_MEM_KB_UNITS:
            warnings.append(
                f"wrapper byte 0x{offset:X} was 0x{patched[offset]:02X}, "
                f"not a known 64K/128K unit marker"
            )
        patched[offset] = unit

    return bytes(patched), warnings


SUPPORTED_MEM_KB_UNITS = {mem_kb // 64 for mem_kb in SUPPORTED_MEM_KB}


def write_ascii_field(buffer: bytearray, offset: int, size: int, value: str, field: str) -> None:
    encoded = value.encode("ascii")
    if len(encoded) >= size:
        raise ConvertError(f"{field} is too long for the .sta wrapper field")
    buffer[offset : offset + size] = b"\x00" * size
    buffer[offset : offset + len(encoded)] = encoded


def read_ascii_field(buffer: bytes, offset: int, size: int) -> str:
    if offset + size > len(buffer):
        return ""
    raw = buffer[offset : offset + size].split(b"\x00", 1)[0]
    return raw.decode("ascii", errors="replace")


def generate_sta_prefix(payload_len: int, metadata: WrapperMetadata) -> bytes:
    prefix = bytearray(POCKETCPC_STA_PREFIX_BYTES)
    prefix[0:4] = POCKETCPC_STA_PREFIX_MAGIC
    prefix[0x004:0x008] = payload_len.to_bytes(4, "little")
    prefix[0x008:0x00C] = (POCKETCPC_STA_PREFIX_BYTES + payload_len).to_bytes(4, "little")
    prefix[0x010:0x014] = (10).to_bytes(4, "little")
    prefix[0x014:0x018] = (zlib.crc32(metadata.core_folder.encode("ascii")) & 0xFFFFFFFF).to_bytes(
        4, "little"
    )

    write_ascii_field(prefix, 0x044, 0x20, metadata.author, "author")
    write_ascii_field(prefix, 0x064, 0x20, metadata.core_name, "core name")
    write_ascii_field(prefix, 0x084, 0x20, metadata.core_version, "core version")
    write_ascii_field(prefix, 0x0A4, 0x100, metadata.asset_name, "asset name")
    write_ascii_field(prefix, 0x1A4, 0x10, metadata.platform_id, "platform id")
    write_ascii_field(prefix, 0x1B4, 0x20, metadata.platform_name, "platform name")

    return bytes(prefix)


def generate_blank_thumbnail() -> bytes:
    pixel = b"\x00\x00\x00\xFF"
    return (
        POCKETCPC_STA_THUMB_MAGIC
        + POCKETCPC_STA_THUMB_WIDTH.to_bytes(2, "little")
        + POCKETCPC_STA_THUMB_HEIGHT.to_bytes(2, "little")
        + (pixel * POCKETCPC_STA_THUMB_WIDTH * POCKETCPC_STA_THUMB_HEIGHT)
    )


def build_generated_wrapper(payload_len: int, metadata: WrapperMetadata) -> tuple[bytes, bytes]:
    return generate_sta_prefix(payload_len, metadata), generate_blank_thumbnail()


def extract_sna(sta_path: Path, out_path: Path, overwrite: bool) -> None:
    data = read_file(sta_path)
    info = find_sna_payload(data, sta_path)
    payload = data[info.offset : info.offset + info.payload_len]
    write_file(out_path, payload, overwrite)
    print(
        f"extracted {info.payload_len} bytes from SNA offset 0x{info.offset:X} "
        f"({info.mem_kb} KiB, version {info.version})"
    )


def build_sta(
    sna_path: Path,
    out_path: Path,
    template_path: Path | None,
    *,
    overwrite: bool,
    model_override: int | None,
    allow_plus: bool,
    keep_version: bool,
    metadata: WrapperMetadata,
) -> None:
    sna_data = read_file(sna_path)
    sna_info = find_sna_payload(sna_data, sna_path)
    if sna_info.offset != 0:
        raise ConvertError(f"{sna_path} has SNA data at offset 0x{sna_info.offset:X}, expected 0")

    payload = sna_data[: sna_info.payload_len]
    payload, normalize_warnings = normalize_sna_for_pocketcpc(
        payload,
        sna_info,
        model_override=model_override,
        allow_plus=allow_plus,
        keep_version=keep_version,
    )

    if len(sna_data) > sna_info.payload_len:
        normalize_warnings.append(
            f"ignored {len(sna_data) - sna_info.payload_len} trailing SNA bytes/chunks"
        )

    prefix_warnings: list[str] = []
    if template_path is not None:
        template = read_file(template_path)
        template_info = find_sna_payload(template, template_path)
        prefix = template[: template_info.offset]
        suffix = template[template_info.offset + template_info.payload_len :]
        prefix, prefix_warnings = patch_sta_prefix(prefix, sna_info.mem_kb)
        wrapper_source = f"template {template_path}"
    else:
        prefix, suffix = build_generated_wrapper(len(payload), metadata)
        wrapper_source = "generated PocketCPC wrapper"

    write_file(out_path, prefix + payload + suffix, overwrite)
    print(
        f"created {out_path} using {wrapper_source} "
        f"({sna_info.mem_kb} KiB payload, {len(prefix)} byte prefix, {len(suffix)} byte suffix)"
    )
    for warning in [*normalize_warnings, *prefix_warnings]:
        print(f"warning: {warning}", file=sys.stderr)


def print_info(path: Path) -> None:
    data = read_file(path)
    info = find_sna_payload(data, path)
    trailing = len(data) - (info.offset + info.payload_len)

    print(f"path: {path}")
    print(f"file_size: {len(data)} bytes")
    print(f"sna_offset: 0x{info.offset:X}")
    print(f"sna_version: {info.version}")
    print(f"machine_type: {info.machine_type}")
    print(f"memory_size: {info.mem_kb} KiB")
    print(f"sna_payload_size: {info.payload_len} bytes")
    print(f"trailing_after_payload: {trailing} bytes")

    if info.offset == 0:
        print("kind: raw .sna snapshot")
    else:
        print("kind: Pocket .sta wrapper with embedded SNA payload")
        if data.startswith(POCKETCPC_STA_PREFIX_MAGIC):
            print(f"wrapper_payload_size: {int.from_bytes(data[0x004:0x008], 'little')} bytes")
            print(f"wrapper_payload_end: 0x{int.from_bytes(data[0x008:0x00C], 'little'):X}")
            print(f"wrapper_core_crc32: 0x{int.from_bytes(data[0x014:0x018], 'little'):08X}")
            print(f"wrapper_author: {read_ascii_field(data, 0x044, 0x20)}")
            print(f"wrapper_core_name: {read_ascii_field(data, 0x064, 0x20)}")
            print(f"wrapper_core_version: {read_ascii_field(data, 0x084, 0x20)}")
            print(f"wrapper_asset_name: {read_ascii_field(data, 0x0A4, 0x100)}")
            print(f"wrapper_platform_id: {read_ascii_field(data, 0x1A4, 0x10)}")
            print(f"wrapper_platform_name: {read_ascii_field(data, 0x1B4, 0x20)}")
        suffix = data[info.offset + info.payload_len :]
        if suffix.startswith(POCKETCPC_STA_THUMB_MAGIC) and len(suffix) >= 8:
            print(
                "thumbnail: "
                f"{int.from_bytes(suffix[4:6], 'little')}x"
                f"{int.from_bytes(suffix[6:8], 'little')}"
            )


def parse_model(value: str) -> int:
    models = {
        "464": 0,
        "cpc464": 0,
        "664": 1,
        "cpc664": 1,
        "6128": 2,
        "cpc6128": 2,
        "unknown": 3,
    }
    key = value.lower()
    if key not in models:
        raise argparse.ArgumentTypeError(
            "model must be one of 464, 664, 6128, cpc464, cpc664, cpc6128, unknown"
        )
    return models[key]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Convert PocketCPC Pocket Memories .sta files and CPC .sna snapshots."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    info = subparsers.add_parser("info", help="show the embedded SNA metadata")
    info.add_argument("input", type=Path, help=".sna or .sta file")

    to_sna = subparsers.add_parser("to-sna", help="extract a .sna from a PocketCPC .sta")
    to_sna.add_argument("input", type=Path, help="input PocketCPC .sta file")
    to_sna.add_argument("output", type=Path, help="output .sna file")
    to_sna.add_argument("--force", action="store_true", help="overwrite output file")

    to_sta = subparsers.add_parser("to-sta", help="wrap a .sna in a PocketCPC .sta")
    to_sta.add_argument("input", type=Path, help="input .sna file")
    to_sta.add_argument("output", type=Path, help="output PocketCPC .sta file")
    to_sta.add_argument(
        "--template",
        type=Path,
        help=(
            "existing PocketCPC .sta to use as the Pocket wrapper template; "
            "if omitted, a PocketCPC wrapper with a blank thumbnail is generated"
        ),
    )
    to_sta.add_argument("--force", action="store_true", help="overwrite output file")
    to_sta.add_argument(
        "--model",
        type=parse_model,
        help="override CPC type when converting old or ambiguous snapshots",
    )
    to_sta.add_argument(
        "--allow-plus-downgrade",
        action="store_true",
        help="map unsupported Plus/GX4000 SNA machine types to classic CPC models",
    )
    to_sta.add_argument(
        "--keep-version",
        action="store_true",
        help="do not normalize SNA v1 headers to v2; current PocketCPC savestate loading expects v2 or v3",
    )
    to_sta.add_argument(
        "--core-folder",
        default=DEFAULT_CORE_FOLDER,
        help=f"core folder/id for generated wrappers (default: {DEFAULT_CORE_FOLDER})",
    )
    to_sta.add_argument(
        "--author",
        default=DEFAULT_AUTHOR,
        help=f"author metadata for generated wrappers (default: {DEFAULT_AUTHOR})",
    )
    to_sta.add_argument(
        "--core-name",
        default=DEFAULT_CORE_NAME,
        help=f"core name metadata for generated wrappers (default: {DEFAULT_CORE_NAME})",
    )
    to_sta.add_argument(
        "--core-version",
        default=DEFAULT_CORE_VERSION,
        help=f"core version metadata for generated wrappers (default: {DEFAULT_CORE_VERSION})",
    )
    to_sta.add_argument(
        "--asset-name",
        help="asset filename metadata for generated wrappers (default: input .sna filename)",
    )
    to_sta.add_argument(
        "--platform-id",
        default=DEFAULT_PLATFORM_ID,
        help=f"platform id metadata for generated wrappers (default: {DEFAULT_PLATFORM_ID})",
    )
    to_sta.add_argument(
        "--platform-name",
        default=DEFAULT_PLATFORM_NAME,
        help=f"platform name metadata for generated wrappers (default: {DEFAULT_PLATFORM_NAME})",
    )

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        if args.command == "info":
            print_info(args.input)
        elif args.command == "to-sna":
            extract_sna(args.input, args.output, args.force)
        elif args.command == "to-sta":
            asset_name = args.asset_name if args.asset_name is not None else args.input.name
            build_sta(
                args.input,
                args.output,
                args.template,
                overwrite=args.force,
                model_override=args.model,
                allow_plus=args.allow_plus_downgrade,
                keep_version=args.keep_version,
                metadata=WrapperMetadata(
                    core_folder=args.core_folder,
                    author=args.author,
                    core_name=args.core_name,
                    core_version=args.core_version,
                    asset_name=asset_name,
                    platform_id=args.platform_id,
                    platform_name=args.platform_name,
                ),
            )
        else:
            parser.error(f"unknown command {args.command}")
    except ConvertError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
