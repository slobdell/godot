#!/usr/bin/env python3
"""Round 20 (brains M3): the hides series as a table.

Per map, --hides=line (every crew of the ambushing line hidden) against point (round 19: the centre only) over the
same seeds: ambushes taken and sprung, the median spring time and where (x), his losses and vehicles left, the CPU's
vehicles left; then the paired per-seed difference (line - point) of his loss and of the alive margin, mean +- sd.
A run that printed nothing is MISSING and fails the target.

Usage: hides_table.py build/hides-series.jsonl
"""
import json
import statistics
import sys


def _sd(values):
    return statistics.stdev(values) if len(values) > 1 else 0.0


def main(path):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    missing = [r for r in rows if r.get("missing")]
    rows = [r for r in rows if not r.get("missing")]
    maps = []
    for r in rows:
        if r["arena"] not in maps:
            maps.append(r["arena"])
    print("| map | hides | n | took | sprung | spring s (median) | his lost | his alive | CPU alive |")
    print("|---|---|---|---|---|---|---|---|---|")
    for arena in maps:
        for arm in ("line", "point"):
            cell = [r for r in rows if r["arena"] == arena and r["hides"] == arm]
            if not cell:
                continue
            sprung = [r["sprung_s"] for r in cell if r["sprung_s"] >= 0]
            print(f"| {arena} | {arm} | {len(cell)} | {sum(1 for r in cell if r['taken'] > 0)} | {len(sprung)} | "
                  f"{statistics.median(sprung) if sprung else '-'} | {statistics.mean(r['his_lost'] for r in cell):.0f} | "
                  f"{statistics.mean(r['his_alive'] for r in cell):.2f} | {statistics.mean(r['cpu_alive'] for r in cell):.2f} |")
        line = {r["seed"]: r for r in rows if r["arena"] == arena and r["hides"] == "line"}
        point = {r["seed"]: r for r in rows if r["arena"] == arena and r["hides"] == "point"}
        seeds = sorted(set(line) & set(point))
        if seeds:
            lost = [line[s]["his_lost"] - point[s]["his_lost"] for s in seeds]
            alive = [(line[s]["cpu_alive"] - line[s]["his_alive"]) - (point[s]["cpu_alive"] - point[s]["his_alive"]) for s in seeds]
            same = sum(1 for s in seeds if line[s]["sprung_s"] == point[s]["sprung_s"] and line[s]["his_lost"] == point[s]["his_lost"])
            print(f"HIDES_SERIES {arena} paired n={len(seeds)} (identical runs {same}): his loss line-point "
                  f"{statistics.mean(lost):+.0f} +- {_sd(lost):.0f}; alive margin (CPU - his) {statistics.mean(alive):+.2f} +- {_sd(alive):.2f}")
    print(f"HIDES_SERIES missing {len(missing)}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
