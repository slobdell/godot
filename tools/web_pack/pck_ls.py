#!/usr/bin/env python3
"""List what an exported Godot .pck carries, biggest first, grouped by folder.

Usage: pck_ls.py PACK [--depth N] [--files] [--json OUT]

Why (ship W1, round 17): the web pack was 175.6 MB with the announcer's clips excluded, and nothing said what filled
it. Godot 4.7 packs are format 3/4: a header, then a directory at `dir_offset` of (path, offset, size, md5, flags).
Paths of imported resources are `.godot/imported/<name>-<hash>.<ext>`; the source name is what a person reads, so
that prefix is folded back to the remapped source where the pack carries the `.import`/`.remap` that names it.
"""
import argparse
import collections
import json
import struct
import sys


def read_pack(path):
    with open(path, "rb") as f:
        head = f.read(40)
        magic, fmt, _ma, _mi, _pa, flags, base, dir_offset = struct.unpack("<4sIIIIIQQ", head)
        if magic != b"GDPC":
            sys.exit(f"{path}: not a Godot pack (magic {magic!r})")
        if fmt < 3:
            sys.exit(f"{path}: pack format {fmt}; this reader knows 3 and 4")
        f.seek(dir_offset)
        (count,) = struct.unpack("<I", f.read(4))
        files = []
        for _ in range(count):
            (n,) = struct.unpack("<I", f.read(4))
            name = f.read(n).rstrip(b"\0").decode()
            offset, size = struct.unpack("<QQ", f.read(16))
            f.read(16)  # md5
            f.read(4)  # flags
            files.append((name, size))
    return files


def resolve(files, depth=3):
    """{source path: bytes} with each imported file counted against its source, plus per-folder totals."""
    # Imported names -> their source, from the .import files the pack also carries: ".godot/imported/foo.png-<md5>.ctex"
    # came from the one ".../foo.png" whose ".import" is in the pack (ambiguous names stay "unresolved").
    sources = {}
    for name, _ in files:
        if name.endswith(".import"):
            src = name[: -len(".import")]
            sources.setdefault(src.rsplit("/", 1)[-1], []).append(src)
    groups = collections.Counter()
    total = 0
    resolved = {}
    for name, size in files:
        total += size
        key = name.removeprefix("res://")
        if key.startswith(".godot/imported/"):
            stem = key.split("/")[-1].rsplit("-", 1)[0]
            cands = sources.get(stem, [])
            key = cands[0].removeprefix("res://") if len(cands) == 1 else ".godot/imported/(unresolved)/" + stem
        resolved[key] = resolved.get(key, 0) + size
        parts = key.split("/")
        groups["/".join(parts[: min(depth, len(parts) - 1)]) or "(root)"] += size
    return resolved, groups, total


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pack")
    ap.add_argument("--depth", type=int, default=3)
    ap.add_argument("--files", action="store_true", help="print the 40 biggest files too")
    ap.add_argument("--json", help="write {path: bytes} here")
    a = ap.parse_args()
    files = read_pack(a.pack)
    resolved, groups, total = resolve(files, a.depth)
    print(f"{a.pack}: {len(files)} files, {total / 1e6:.1f} MB")
    for g, s in groups.most_common(40):
        print(f"  {s / 1e6:8.2f} MB  {g}")
    if a.files:
        print("biggest files:")
        for k, s in sorted(resolved.items(), key=lambda kv: -kv[1])[:40]:
            print(f"  {s / 1e6:8.2f} MB  {k}")
    if a.json:
        with open(a.json, "w") as out:
            json.dump(resolved, out, indent=0, sort_keys=True)


if __name__ == "__main__":
    main()
