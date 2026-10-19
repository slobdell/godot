#!/usr/bin/env python3
"""Brains B9 (R34.15, measurement only): the lane census table over `make lane-census` logs.
Per arena: how often a side's lane pick is STACKED (another squad of the same side picked the same lane in the last 20 s),
and the losses of team-fights (one side of one fight) with stacking v without (deaths, jam deaths, kills; per fight).
Usage: lane_table.py DIR"""
import glob
import json
import os
import statistics
import sys
from collections import Counter, defaultdict


def main(d):
    rows = []
    picks = []
    for path in sorted(glob.glob(os.path.join(d, "*.log"))):
        for line in open(path, errors="replace"):
            if line.startswith("LANE_CENSUS "):
                rows.append(json.loads(line.split(" ", 1)[1]))
            elif line.startswith("LANE_PICK "):
                p = json.loads(line.split(" ", 1)[1])
                p["arena"] = os.path.basename(path).split("-")[0]
                picks.append(p)
    print("fights %d, picks %d" % (len(rows), len(picks)))
    for arena in sorted({r["arena"] for r in rows}):
        rs = [r for r in rows if r["arena"] == arena]
        ps = [p for p in picks if p["arena"] == arena]
        lanes = Counter(p["lane"] for p in ps)
        stacked = sum(1 for p in ps if p["stacked"])
        print("== %s: %d fights, %d picks, %d stacked (%.0f %%), lanes %s, verbs %s" % (
            arena, len(rs), len(ps), stacked, 100.0 * stacked / max(len(ps), 1), dict(lanes),
            dict(Counter(p["verb"] for p in ps))))
        sides = []
        for r in rs:
            for team, t in r["teams"].items():
                if int(t.get("picks", 0)) == 0:
                    continue
                share = int(t["stacked"]) / int(t["picks"])
                sides.append((share, t))
        if not sides:
            continue
        for label, keep in (("mostly stacked (>= 50 % of picks)", lambda s: s >= 0.5), ("mostly split (< 50 %)", lambda s: s < 0.5)):
            ts = [t for s, t in sides if keep(s)]
            if not ts:
                print("   %-34s n 0" % label)
                continue
            med = lambda k: statistics.median([int(t[k]) for t in ts])
            mean = lambda k: statistics.mean([int(t[k]) for t in ts])
            print("   %-34s n %2d | deaths median %4.1f mean %5.1f | jam deaths mean %4.1f | kills mean %5.1f" % (
                label, len(ts), med("deaths"), mean("deaths"), mean("jam_deaths"), mean("kills")))


if __name__ == "__main__":
    main(sys.argv[1])
