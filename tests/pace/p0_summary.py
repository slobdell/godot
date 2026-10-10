#!/usr/bin/env python3
"""Round 25 pace P0: summarise build/pace/p0/<arm>-p<phase>.log.

One table per scenario: rows are arms, columns are think phases, each cell PASS/FAIL; then each FAIL's messages and
every MEASURE line, by arm and phase, so the margin to the pass line can be read next to the verdict.
"""
import collections
import pathlib
import re
import sys

LINE = re.compile(r"^\s+(PASS|FAIL|PENDING|UNEXPECTED PASS|NOT JUDGED)\s+(\S+)")


def parse(path):
    verdicts, measures, messages = {}, collections.defaultdict(list), collections.defaultdict(list)
    pending = []  # MEASURE lines print before their scenario's verdict
    last_fail = None
    for raw in path.read_text(errors="replace").splitlines():
        m = LINE.match(raw)
        if m:
            name = m.group(2).split("::")[-1]
            verdicts[name] = m.group(1)
            measures[name].extend(pending)
            pending = []
            last_fail = name if m.group(1) == "FAIL" else None
            continue
        if raw.startswith("MEASURE"):
            pending.append(raw[len("MEASURE "):])
            last_fail = None
        elif last_fail and raw.startswith("      ") and raw.strip():
            messages[last_fail].append(raw.strip())
    return verdicts, measures, messages


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "build/pace/p0")
    runs = {}
    for log in sorted(root.glob("*-p*.log")):
        arm, phase = log.stem.rsplit("-p", 1)
        runs[(arm, int(phase))] = parse(log)
    arms = list(dict.fromkeys(a for a, _ in sorted(runs, key=lambda k: k[1])))
    phases = sorted({p for _, p in runs})
    names = sorted({n for v, _, _ in runs.values() for n in v})
    for name in names:
        print(f"\n## {name}")
        print("arm".ljust(10) + " ".join(f"p{p}".ljust(5) for p in phases))
        for arm in arms:
            cells = [runs.get((arm, p), ({}, {}, {}))[0].get(name, "-")[:4] for p in phases]
            print(arm.ljust(10) + " ".join(c.ljust(5) for c in cells))
        for arm in arms:
            for p in phases:
                verdicts, measures, messages = runs.get((arm, p), ({}, {}, {}))
                for line in measures.get(name, []):
                    print(f"  {arm} p{p} {verdicts.get(name, '-')}: {line}")
                for line in messages.get(name, []):
                    print(f"  {arm} p{p}   ! {line}")


if __name__ == "__main__":
    main()
