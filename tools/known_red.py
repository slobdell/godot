#!/usr/bin/env python3
"""Known-red targets outside `check`, beside what the last check-all actually said (ship, round 18, stretch c).

    known_red.py list   <known_red.txt> [<verdicts.tsv>]   the list, and each line's state in the last check-all
    known_red.py label  <known_red.txt> <target>           one word for check-all's line: "" or " (KNOWN RED: why)"

`verdicts.tsv` is written by check-all: `<target>\t<PASS|FAIL>\t<seconds>` per line. "Red outside check" used to be
a sentence in HANDOFF.md that the next reader had to remember was still true; this reads it from the last run.
"""

from __future__ import annotations

import sys
from pathlib import Path


def read_list(path: str) -> dict[str, tuple[str, str]]:
    entries: dict[str, tuple[str, str]] = {}
    p = Path(path)
    if not p.exists():
        return entries
    for line in p.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = [part.strip() for part in line.split("|", 2)]
        if len(parts) == 3 and parts[0]:
            entries[parts[0]] = (parts[1], parts[2])
    return entries


def read_verdicts(path: str) -> dict[str, str]:
    verdicts: dict[str, str] = {}
    p = Path(path)
    if not p.exists():
        return verdicts
    for line in p.read_text().splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            verdicts[parts[0]] = parts[1]
    return verdicts


def cmd_list(list_path: str, verdicts_path: str) -> int:
    known = read_list(list_path)
    verdicts = read_verdicts(verdicts_path) if verdicts_path else {}
    when = ""
    if verdicts_path and Path(verdicts_path).exists():
        stamp = Path(verdicts_path).stat().st_mtime
        import datetime
        when = datetime.datetime.fromtimestamp(stamp).strftime("%Y-%m-%d %H:%M")
    print(f"known red outside check ({list_path}): {len(known)}")
    print(f"  last check-all: {verdicts_path + ' at ' + when if when else 'none here (run make remote T=check-all)'}")
    status = 0
    for target, (since, why) in known.items():
        state = verdicts.get(target)
        if state is None:
            tag = "not in the last check-all"
        elif state == "PASS":
            tag = "PASSED in the last check-all: remove its line if it holds"
        else:
            tag = "still red"
        print(f"  {target:<22} {tag}\n      since {since}\n      {why}")
    for target, state in verdicts.items():
        if state != "PASS" and target not in known:
            print(f"  {target:<22} NEW RED: not on the list (find why; add it with its evidence, or fix it)")
            status = 1
    return status


def cmd_label(list_path: str, target: str) -> int:
    known = read_list(list_path)
    if target in known:
        print(f" (KNOWN RED since {known[target][0].split(',')[0]}: tests/baselines/known_red.txt)")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) in (3, 4) and argv[1] == "list":
        return cmd_list(argv[2], argv[3] if len(argv) == 4 else "")
    if len(argv) == 4 and argv[1] == "label":
        return cmd_label(argv[2], argv[3])
    print(__doc__.strip().splitlines()[2:4], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
