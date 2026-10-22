#!/usr/bin/env python3
"""Round 37 (orders O5): the seat give-way census read from seat-yield-census logs.

    python3 tests/control/seat_yield_table.py build/seat-yield/   (every *.log in it)

Per arm-less run folder: give-way episodes and deaths of crews holding a seat (screen / support_by_fire / hold), by side
(cpu / player) and verb, summed over fights; then the asker verbs; then the missing fights.
"""
import glob
import json
import os
import sys
from collections import Counter, defaultdict


def main(folder):
    eps = defaultdict(int)
    deaths = defaultdict(int)
    askers = Counter()
    fights = 0
    all_deaths = 0
    missing = []
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        census = None
        with open(path) as f:
            for line in f:
                if line.startswith("SEAT_YIELD "):
                    r = json.loads(line.split(" ", 1)[1])
                    key = ("cpu" if r["cpu"] else "player") + ":" + r["verb"]
                    eps[key] += 1
                    deaths[key] += 1 if r["died"] else 0
                    askers[(key, r["asker_verb"])] += 1
                elif line.startswith("SEAT_YIELD_CENSUS "):
                    census = json.loads(line.split(" ", 1)[1])
        if census is None:
            missing.append(os.path.basename(path))
            continue
        fights += 1
        all_deaths += census["deaths"]
    print("fights %d, all deaths %d" % (fights, all_deaths))
    for key in sorted(eps):
        print("  %-22s episodes %5d  deaths %4d" % (key, eps[key], deaths[key]))
    print("TOTAL seat give-ways %d, deaths %d" % (sum(eps.values()), sum(deaths.values())))
    for (key, asker), n in askers.most_common(12):
        print("  asker %-22s <- %-16s %d" % (key, asker, n))
    for m in missing:
        print("MISSING", m)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "build/seat-yield")
