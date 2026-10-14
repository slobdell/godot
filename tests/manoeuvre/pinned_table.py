#!/usr/bin/env python3
"""Round 29 (manoeuvre M4): pinned crew-seconds in hull-rest runs, two arms paired by run.

Usage: pinned_table.py BASE_DIR NEW_DIR (each <faction>/<task>-<seed>/run.log with MANOEUVRE_STATE lines, --turn-states).
A crew is PINNED while, for >= 10 consecutive 1 s state lines, it is on a move_to with |throttle| > 0.3 and its distance to
its goal changes by < 0.05 m between lines: defined by command and real displacement, not by the reported velocity (the
reading M4 changes). Pinned crew-seconds per run (the whole streak counts once it reaches 10), summed, paired by run, se.
Scouts (scout, law_scout, gang_scout) reported apart. Report only.
"""
import pathlib
import re
import statistics
import sys

STATE = re.compile(r"MANOEUVRE_STATE f (\d+) (.+?) (\S+) order (\S*) from (\S*) v ([-\d.]+) moved ([-\d.]+) "
                   r"cmd ([-\d.]+)/([-\d.]+) .* goal ([-\d.]+)")
SCOUTS = {"scout", "law_scout", "gang_scout"}


def run_pinned(log):
    hist = {}
    for line in log.read_text(errors="replace").splitlines():
        if line.startswith("SCREEN {"):
            break
        m = STATE.search(line)
        if m:
            hist.setdefault(m.group(2), []).append((m.group(3), m.group(4), float(m.group(8)), float(m.group(10))))
    total = {"all": 0, "scouts": 0, "crews": 0}
    for unit, rows in hist.items():
        streak, pinned, uid = 0, 0, rows[0][0]
        for a, b in zip(rows, rows[1:]):
            if b[1] == "move_to" and abs(b[2]) > 0.3 and abs(a[3] - b[3]) < 0.05:
                streak += 1
            else:
                if streak >= 10:
                    pinned += streak
                streak = 0
        if streak >= 10:
            pinned += streak
        total["all"] += pinned
        if uid in SCOUTS:
            total["scouts"] += pinned
        if pinned:
            total["crews"] += 1
    return total


def load(root):
    return {str(p.parent.relative_to(root)): run_pinned(p) for p in pathlib.Path(root).glob("*/*/run.log")}


def main(base_dir, new_dir):
    base, new = load(base_dir), load(new_dir)
    keys = sorted(set(base) & set(new))
    print(f"PINNED runs paired {len(keys)} (base {len(base)}, new {len(new)})")
    for k in ("all", "scouts", "crews"):
        d = [new[r][k] - base[r][k] for r in keys]
        se = statistics.stdev(d) * len(d) ** 0.5 if len(d) > 1 else float("nan")
        tot = sum(d)
        print(f"PINNED {k} crew-seconds: base {sum(base[r][k] for r in keys)} new {sum(new[r][k] for r in keys)} diff {tot:+d} "
              f"se {se:.1f} {'DOWN beyond 2 se' if tot < -2 * se else ('UP beyond 2 se' if tot > 2 * se else 'within 2 se')}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
