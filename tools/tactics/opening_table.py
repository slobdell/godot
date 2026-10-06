#!/usr/bin/env python3
"""Round 20 (brains M2): the opening series as a table.

Per map, for --opening on and off over the same seeds: how many runs took an ambush and sprung one, the refusal census
(in contact / no site / late), the CPU's and his losses (hit points), vehicles alive, and the score; then the paired
per-seed difference (on - off) of (his loss - CPU loss) and of the score margin, mean +- sd. A run that printed nothing
is MISSING and fails the target.

Usage: opening_table.py build/opening-series.jsonl
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
    print("| map | arm | n | near ring, site | took | sprung | refused contact/site/late | CPU lost | his lost | alive CPU/his | score CPU-his |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    for arena in maps:
        for arm in (True, False):
            cell = [r for r in rows if r["arena"] == arena and r["opening"] == arm]
            if not cell:
                continue
            ref = [sum(int(r["refused"][k]) for r in cell) for k in ("in_contact", "no_site", "late")]
            print(f"| {arena} | {'on' if arm else 'off'} | {len(cell)} | {cell[0]['near_ring'] or '-'}, {cell[0]['site']} | "
                  f"{sum(1 for r in cell if r['taken'] > 0)} | {sum(1 for r in cell if r['sprung'] > 0)} | {ref[0]}/{ref[1]}/{ref[2]} | "
                  f"{statistics.mean(r['cpu_lost'] for r in cell):.0f} | {statistics.mean(r['his_lost'] for r in cell):.0f} | "
                  f"{statistics.mean(r['cpu_alive'] for r in cell):.1f}/{statistics.mean(r['his_alive'] for r in cell):.1f} | "
                  f"{statistics.mean(r['rust_score'] - r['green_score'] for r in cell):+.1f} |")
        on = {r["seed"]: r for r in rows if r["arena"] == arena and r["opening"]}
        off = {r["seed"]: r for r in rows if r["arena"] == arena and not r["opening"]}
        seeds = sorted(set(on) & set(off))
        if seeds:
            trade = [(on[s]["his_lost"] - on[s]["cpu_lost"]) - (off[s]["his_lost"] - off[s]["cpu_lost"]) for s in seeds]
            margin = [(on[s]["rust_score"] - on[s]["green_score"]) - (off[s]["rust_score"] - off[s]["green_score"]) for s in seeds]
            alive = [(on[s]["cpu_alive"] - on[s]["his_alive"]) - (off[s]["cpu_alive"] - off[s]["his_alive"]) for s in seeds]
            print(f"OPENING_SERIES {arena} paired n={len(seeds)}: trade (his loss - CPU loss) on-off {statistics.mean(trade):+.0f} +- {_sd(trade):.0f}; "
                  f"alive margin {statistics.mean(alive):+.2f} +- {_sd(alive):.2f}; score margin {statistics.mean(margin):+.1f} +- {_sd(margin):.1f}")
    print(f"OPENING_SERIES missing {len(missing)}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
