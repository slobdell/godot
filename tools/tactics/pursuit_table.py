#!/usr/bin/env python3
"""Round 21 (brains P2): the pursuit series as a table.

Per map, --pursuit=on (an attack on a target that runs is a chase) against off (round 20's attack) over the same seeds:
the target killed (k of n, median time), his loss in hit points and vehicles left, the CPU's left, his crews' hull
reversals while chasing; then the paired per-seed difference (on - off) of his loss, of the alive margin (CPU - his)
and of the time to kill (a target never killed counts as the run's length), mean +- sd and se.
A run that printed nothing is MISSING and fails the target.

Usage: pursuit_table.py build/pursuit-series.jsonl [seconds]
"""
import json
import math
import statistics
import sys


def _sd(values):
    return statistics.stdev(values) if len(values) > 1 else 0.0


def _line(name, values):
    sd = _sd(values)
    return f"{name} {statistics.mean(values):+.2f} +- {sd:.2f} (se {sd / math.sqrt(len(values)):.2f})"


def main(path, seconds=60.0):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    missing = [r for r in rows if r.get("missing")]
    rows = [r for r in rows if not r.get("missing")]
    maps = []
    for r in rows:
        if r["arena"] not in maps:
            maps.append(r["arena"])
    print("| map | pursuit | n | target killed | kill s (median) | his lost | his alive | CPU alive | reversals |")
    print("|---|---|---|---|---|---|---|---|---|")
    for arena in maps:
        for arm in ("on", "off"):
            cell = [r for r in rows if r["arena"] == arena and r["pursuit"] == arm]
            if not cell:
                continue
            kills = [r["target_killed_s"] for r in cell if r["target_killed_s"] >= 0]
            print(f"| {arena} | {arm} | {len(cell)} | {len(kills)} | {statistics.median(kills) if kills else '-'} | "
                  f"{statistics.mean(r['his_lost'] for r in cell):.0f} | {statistics.mean(r['his_alive'] for r in cell):.2f} | "
                  f"{statistics.mean(r['cpu_alive'] for r in cell):.2f} | {sum(r['reversals'] for r in cell)} |")
        on = {r["seed"]: r for r in rows if r["arena"] == arena and r["pursuit"] == "on"}
        off = {r["seed"]: r for r in rows if r["arena"] == arena and r["pursuit"] == "off"}
        seeds = sorted(set(on) & set(off))
        if seeds:
            def kill(r):
                return r["target_killed_s"] if r["target_killed_s"] >= 0 else seconds
            lost = [on[s]["his_lost"] - off[s]["his_lost"] for s in seeds]
            alive = [(on[s]["cpu_alive"] - on[s]["his_alive"]) - (off[s]["cpu_alive"] - off[s]["his_alive"]) for s in seeds]
            time = [kill(on[s]) - kill(off[s]) for s in seeds]
            better = sum(1 for s in seeds if on[s]["his_lost"] < off[s]["his_lost"])
            worse = sum(1 for s in seeds if on[s]["his_lost"] > off[s]["his_lost"])
            print(f"PURSUIT_SERIES {arena} paired n={len(seeds)} on-off: {_line('his loss', lost)}; "
                  f"{_line('alive margin (CPU - his)', alive)}; {_line('time to kill s', time)}; "
                  f"his loss lower in {better}, higher in {worse}")
    print(f"PURSUIT_SERIES missing {len(missing)}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 60.0))
