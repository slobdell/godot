#!/usr/bin/env python3
"""What's inside an exported Godot .pck, grouped by where it came from (A5 budget report).

    python3 tools/assets/pck_report.py build/web/index.pck [--group game/theme/kitbash ...] [--top 15]

Imported resources live in the pack as res://.godot/imported/<source file>-<hash>.<ext>; they are
attributed back to their source by matching the .import remap files that sit beside the sources.
Reads PCK format versions 2 and 3 (Godot 4.x) without Godot.
"""

import argparse
import re
import struct
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACK_DIR_RELATIVE = 1 << 1  # PACK_REL_FILEBASE: file offsets are relative to file_base


def read_directory(path: Path) -> list:
    """[(res path, size), ...] from a .pck (or an executable with an embedded pack at its end)."""
    data = path.read_bytes()
    start = data.rfind(b"GDPC") if not data.startswith(b"GDPC") else 0
    if start < 0:
        raise ValueError(f"{path}: no GDPC header")
    offset = start + 4
    version, _major, _minor, _patch = struct.unpack_from("<4I", data, offset)
    offset += 16
    flags, file_base = struct.unpack_from("<IQ", data, offset)
    offset += 12
    if version >= 3:
        (dir_offset,) = struct.unpack_from("<Q", data, offset)
        offset += 8
        offset += 16 * 4  # reserved
        offset = start + dir_offset if flags & PACK_DIR_RELATIVE else dir_offset
    else:
        offset += 16 * 4
    if flags & 1:
        raise ValueError(f"{path}: encrypted pack directory")
    (count,) = struct.unpack_from("<I", data, offset)
    offset += 4
    files = []
    for _ in range(count):
        (length,) = struct.unpack_from("<I", data, offset)
        offset += 4
        name = data[offset:offset + length].rstrip(b"\0").decode()
        offset += length
        _file_offset, size = struct.unpack_from("<QQ", data, offset)
        offset += 16 + 16 + 4  # offset, size, md5, flags
        files.append((name, size))
    return files


def import_sources() -> dict:
    """imported path (res://.godot/imported/...) → source res path, from every .import file in the project."""
    sources = {}
    for remap in ROOT.rglob("*.import"):
        if ".godot" in remap.parts or "node_modules" in remap.parts or ".tools" in remap.parts:
            continue
        text = remap.read_text(errors="replace")
        source = "res://" + str(remap.relative_to(ROOT))[: -len(".import")]
        for dest in re.findall(r'"(res://\.godot/imported/[^"]+)"', text):
            sources[dest] = source
    return sources


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("pck")
    parser.add_argument("--group", action="append", default=[], help="res-relative prefix to total (repeatable)")
    parser.add_argument("--top", type=int, default=12)
    args = parser.parse_args(argv)

    files = read_directory(Path(args.pck))
    sources = import_sources()
    total = sum(size for _, size in files)
    groups = args.group or ["game/theme/default", "game/theme/kitbash", "game/theme/neon_kit", "assets/", "game/", "tests/", ".godot/"]
    by_group = defaultdict(int)
    by_source = defaultdict(int)
    for name, size in files:
        name = name if name.startswith("res://") else "res://" + name  # 4.4+ packs store paths without res://
        origin = sources.get(name, name)
        by_source[origin] += size
        for prefix in groups:
            if origin.startswith("res://" + prefix):
                by_group[prefix] += size
                break
        else:
            by_group["(other)"] += size

    print(f"{args.pck}: {len(files)} files, {total / 1024:.0f} KB of contents, {Path(args.pck).stat().st_size / 1024:.0f} KB on disk")
    print(f"\n| group | KB | share |\n|---|---:|---:|")
    for prefix in groups + ["(other)"]:
        if by_group[prefix]:
            print(f"| `{prefix}` | {by_group[prefix] / 1024:.0f} | {100 * by_group[prefix] / total:.1f}% |")
    print(f"\n| largest sources | KB |\n|---|---:|")
    for origin, size in sorted(by_source.items(), key=lambda item: -item[1])[: args.top]:
        print(f"| `{origin.removeprefix('res://')}` | {size / 1024:.0f} |")
    return 0


if __name__ == "__main__":
    sys.exit(main())
