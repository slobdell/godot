#!/usr/bin/env python3
"""Round 21 (brains stretch a): the hold fall-back series as a table.

Round 19's hold stage (tests/tactics/hold_probe.gd: the CPU on its depot and ahead, his four Law tanks crossing toward
it) per map, --fallback=on (a holding element losing its trade gives one bound toward the zone) against off (round 19)
over the same seeds: fall-backs taken, his loss and vehicles left, the CPU's vehicles left and points; then the paired
per-seed difference (on - off) of his loss, of the CPU's alive, and of the alive margin (CPU - his), mean +- sd (se).
A run that printed nothing is MISSING and fails the target.

Usage: fallback_table.py build/fallback-series.jsonl
"""
import json
import math
import statistics
import sys


def _line(name, values):
    sd = statistics.stdev(values) if len(values) > 1 else 0.0
    return f"{name} {statistics.mean(values):+.2f} +- {sd:.2f} (se {sd / math.sqrt(len(values)):.2f})"


def main(path):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    missing = [r for r in rows if r.get("missing")]
    rows = [r for r in rows if not r.get("missing")]
    maps = []
    for r in rows:
        if r["arena"] not in maps:
            maps.append(r["arena"])
    print("| map | fallback | n | fell back (runs) | his lost | his alive | CPU alive | CPU points |")
    print("|---|---|---|---|---|---|---|---|")
    for arena in maps:
        for arm in ("on", "off"):
            cell = [r for r in rows if r["arena"] == arena and r["fallback"] == arm]
            if not cell:
                continue
            print(f"| {arena} | {arm} | {len(cell)} | {sum(1 for r in cell if r['fallbacks'] > 0)} | "
                  f"{statistics.mean(r['his_lost'] for r in cell):.0f} | {statistics.mean(r['his_alive'] for r in cell):.2f} | "
                  f"{statistics.mean(r['cpu_alive'] for r in cell):.2f} | {statistics.mean(r['rust_score'] for r in cell):.1f} |")
        on = {r["seed"]: r for r in rows if r["arena"] == arena and r["fallback"] == "on"}
        off = {r["seed"]: r for r in rows if r["arena"] == arena and r["fallback"] == "off"}
        seeds = sorted(set(on) & set(off))
        if seeds:
            lost = [on[s]["his_lost"] - off[s]["his_lost"] for s in seeds]
            cpu = [on[s]["cpu_alive"] - off[s]["cpu_alive"] for s in seeds]
            margin = [(on[s]["cpu_alive"] - on[s]["his_alive"]) - (off[s]["cpu_alive"] - off[s]["his_alive"]) for s in seeds]
            same = sum(1 for s in seeds if on[s]["fallbacks"] == 0)
            print(f"FALLBACK_SERIES {arena} paired n={len(seeds)} (no fall-back in {same}) on-off: {_line('his loss', lost)}; "
                  f"{_line('CPU alive', cpu)}; {_line('alive margin (CPU - his)', margin)}")
    print(f"FALLBACK_SERIES missing {len(missing)}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
