#!/usr/bin/env python3
"""Adopt one machine's sim-baseline line without disturbing any other machine's.

    baseline_merge.py <file> <key> <hash> <commit> <machine> [date]

The hand procedure this replaces was `cp build/sim_state_hash.txt tests/baselines/`, and
`sim-baseline-record`'s own message admits what that does: *"other machines' lines go stale"*. It does worse
than go stale — `build/sim_state_hash.txt` holds ONE line, the recording machine's, so the copy DELETES every
other machine's baseline. Today that is invisible because only builder0 has one; the day the laptop or a
second builder has one, adopting on either silently removes the other and the next check there reports
"SKIPPED: no baseline for glibc-x.yz" rather than a failure anyone would chase.

So: replace the line for this key, keep the rest, and carry provenance for each as a comment the existing
reader already ignores (`awk '$1 == k'` never matches a line starting with `#`).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

HASH = re.compile(r"^[0-9a-f]{16}$")
KEY = re.compile(r"^[A-Za-z0-9._+-]+$")


def parse(text: str) -> dict[str, tuple[str, str]]:
    """key -> (hash, provenance comment or "")."""
    entries: dict[str, tuple[str, str]] = {}
    pending = ""
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("#"):
            pending = stripped
            continue
        parts = stripped.split()
        if len(parts) >= 2:
            entries[parts[0]] = (parts[1], pending)
        pending = ""
    return entries


def render(entries: dict[str, tuple[str, str]]) -> str:
    out = []
    for key in sorted(entries):
        value, comment = entries[key]
        if comment:
            out.append(comment)
        out.append(f"{key} {value}")
    return "\n".join(out) + "\n"


def main() -> int:
    if len(sys.argv) < 6:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 2
    path, key, value, commit, machine = sys.argv[1:6]
    when = sys.argv[6] if len(sys.argv) > 6 else ""

    if not KEY.match(key):
        print(f"baseline_merge: refusing a key that is not a libc key: {key!r}", file=sys.stderr)
        return 2
    if not HASH.match(value):
        # A truncated or empty hash adopted as a baseline would make every later check compare against
        # nonsense, and the failure would read as a gameplay change.
        print(f"baseline_merge: refusing {value!r} as a state hash: expected 16 lowercase hex digits",
              file=sys.stderr)
        return 2

    target = Path(path)
    entries = parse(target.read_text()) if target.exists() else {}
    before = entries.get(key)
    entries[key] = (value, f"# {key}: recorded on {machine} at {commit}, twice, agreeing"
                           + (f" ({when})" if when else ""))

    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_suffix(target.suffix + ".tmp")
    tmp.write_text(render(entries))
    tmp.replace(target)

    kept = sorted(k for k in entries if k != key)
    if before is None:
        print(f"baseline_merge: ADDED {key} {value}")
    elif before[0] == value:
        print(f"baseline_merge: {key} unchanged at {value}")
    else:
        print(f"baseline_merge: {key} {before[0]} -> {value}")
    print(f"  kept {len(kept)} other machine's line(s): {', '.join(kept) if kept else 'none'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
