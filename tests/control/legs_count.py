#!/usr/bin/env python3
"""Round 35 (orders D6's bar): legs per squad on the route cells, from the probe's ORDERS_PROBE_LEGS lines (logs DIR).

Per arm: route runs, squads, and how many squads got every leg (= the route's waypoints, 3) v fewer; then per cell
(map, squads, seed) whether the legs differ between arms (D6's counter). Usage: legs_count.py LOGS_DIR"""
import glob
import os
import re
import sys


def main(d):
    legs = {}
    for p in sorted(glob.glob(os.path.join(d, "*-route-*.log"))):
        m = re.match(r"(\w+)-(\d)-route-(\w+)-s(\d+)\.log", os.path.basename(p))
        if not m:
            continue
        mp, n, arm, seed = m.group(1), int(m.group(2)), m.group(3), int(m.group(4))
        for line in open(p, errors="replace"):
            if line.startswith("ORDERS_PROBE_LEGS "):
                sq = int(line.split()[2])
                count = line.count("], [") + 1 if "legs [[" in line else 0
                legs.setdefault(arm, {})[(mp, n, seed, sq)] = (count, line.split(" legs ", 1)[1].strip())
    for arm, rows in sorted(legs.items()):
        full = sum(1 for c, _ in rows.values() if c >= 3)
        print(f"LEGS {arm}: squads {len(rows)}, every leg (3) {full}, fewer {len(rows) - full}")
    arms = sorted(legs)
    if len(arms) == 2:
        a, b = legs[arms[0]], legs[arms[1]]
        cells = sorted({k[:3] for k in a} & {k[:3] for k in b})
        differ = [c for c in cells if any(a.get(c + (s,), (0, ""))[1] != b.get(c + (s,), (0, ""))[1] for s in range(1, 6))]
        print(f"LEGS cells whose legs differ between arms: {len(differ)} of {len(cells)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
