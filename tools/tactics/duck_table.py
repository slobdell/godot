#!/usr/bin/env python3
"""Round 22 (brains B1): the sitting-duck series as tables.

Two kinds of rows, told apart by their fields:
  * round 19's hold stage (tests/tactics/hold_probe.gd, `make duck-series`): per map, --duck=on against off over the
    same seeds: crews that left a post (by outcome), his loss and vehicles left, the CPU's vehicles left and points; then
    the paired per-seed difference (on - off) of his loss, of the CPU's alive, of the alive margin (CPU - his) and of
    the score margin (CPU - his points), mean +- sd (se).
  * his recording's stage (tests/tactics/duck_probe.gd, `make duck-stage-series`): per side x Lancers x arm: moved
    (runs), reaction time, outcome counts, answered, alive, loss, Lancer loss.
A run that printed nothing is MISSING and fails the target.

Usage: duck_table.py build/duck-series.jsonl | build/duck-stage.jsonl
"""
import json
import math
import statistics
import sys
from collections import Counter


def _line(name, values):
    sd = statistics.stdev(values) if len(values) > 1 else 0.0
    return f"{name} {statistics.mean(values):+.2f} +- {sd:.2f} (se {sd / math.sqrt(len(values)):.2f})"


def _mean(values):
    values = list(values)
    return statistics.mean(values) if values else float("nan")


def hold_stage(rows):
    for r in rows:
        # Round 22: the stage's armies are part of its name (round 19's Law tanks, or his recording's Lancers).
        r["arena"] = f"{r['arena']}/{r.get('his_units', 'law_tank')}"
    maps = []
    for r in rows:
        if r["arena"] not in maps:
            maps.append(r["arena"])
    print("| map | duck | n | left a post (crews: close/cover/fall_back) | his lost | his alive | CPU alive | CPU points | his points |")
    print("|---|---|---|---|---|---|---|---|---|")
    for arena in maps:
        for arm in ("on", "off"):
            cell = [r for r in rows if r["arena"] == arena and r["duck"] == arm]
            if not cell:
                continue
            tally = Counter()
            for r in cell:
                tally.update(r.get("ducks", {}))
            print(f"| {arena} | {arm} | {len(cell)} | {tally['close']}/{tally['cover']}/{tally['fall_back']} | "
                  f"{_mean(r['his_lost'] for r in cell):.0f} | {_mean(r['his_alive'] for r in cell):.2f} | "
                  f"{_mean(r['cpu_alive'] for r in cell):.2f} | {_mean(r['rust_score'] for r in cell):.1f} | "
                  f"{_mean(r['green_score'] for r in cell):.1f} |")
        on = {r["seed"]: r for r in rows if r["arena"] == arena and r["duck"] == "on"}
        off = {r["seed"]: r for r in rows if r["arena"] == arena and r["duck"] == "off"}
        seeds = sorted(set(on) & set(off))
        if seeds:
            lost = [on[s]["his_lost"] - off[s]["his_lost"] for s in seeds]
            cpu = [on[s]["cpu_alive"] - off[s]["cpu_alive"] for s in seeds]
            margin = [(on[s]["cpu_alive"] - on[s]["his_alive"]) - (off[s]["cpu_alive"] - off[s]["his_alive"]) for s in seeds]
            score = [(on[s]["rust_score"] - on[s]["green_score"]) - (off[s]["rust_score"] - off[s]["green_score"]) for s in seeds]
            same = sum(1 for s in seeds if not on[s].get("ducks"))
            print(f"DUCK_SERIES {arena} paired n={len(seeds)} (no crew left a post in {same}) on-off: {_line('his loss', lost)}; "
                  f"{_line('CPU alive', cpu)}; {_line('alive margin (CPU - his)', margin)}; {_line('score margin (CPU - his)', score)}")


def recording_stage(rows):
    print("| side | Lancers | duck | n | moved | react s | outcomes | answered | alive | lost | Lancers lost |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    keys = []
    for r in rows:
        key = (r["side"], r["lancers"])
        if key not in keys:
            keys.append(key)
    for side, lancers in keys:
        for arm in ("on", "off"):
            cell = [r for r in rows if r["side"] == side and r["lancers"] == lancers and r["duck"] == arm]
            if not cell:
                continue
            reacts = [r["react_s"] for r in cell if r["react_s"] >= 0]
            outcomes = Counter(r["outcome"] or "-" for r in cell)
            print(f"| {side} | {lancers} | {arm} | {len(cell)} | {sum(1 for r in cell if r['moved_s'] >= 0)} | "
                  f"{_mean(reacts):.1f} | {' '.join(f'{k}:{v}' for k, v in sorted(outcomes.items()))} | "
                  f"{sum(1 for r in cell if r['answered'])} | {sum(1 for r in cell if r['alive'])} | "
                  f"{_mean(r['lost'] for r in cell):.0f} | {_mean(r['lancers_lost'] for r in cell):.0f} |")


def main(path):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    missing = [r for r in rows if r.get("missing")]
    rows = [r for r in rows if not r.get("missing")]
    if rows and "lancers" in rows[0]:
        recording_stage(rows)
    elif rows:
        hold_stage(rows)
    print(f"DUCK_SERIES missing {len(missing)}")
    return 1 if missing or not rows else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
