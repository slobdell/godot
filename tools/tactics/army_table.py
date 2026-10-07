#!/usr/bin/env python3
"""Round 22 (brains B2): the ten-squads-a-side series as a table, and its invariants.

Per run (tests/tactics/army_probe.gd): squads and units fielded, the most elements a side ever had, the biggest element,
vehicle-seconds outside the arena (and at deployment), the result, the postures each commander took, the task verbs.
FAILS (exit 1) on: a missing run, an error line in any run, more than 10 elements a side, an element over 5, any vehicle
outside the arena.

Usage: army_table.py build/army-series.jsonl build/army-series.errors
"""
import json
import sys


def main(path, errors_path):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    errors = [line.rstrip() for line in open(errors_path) if line.strip()]
    missing = [r for r in rows if r.get("missing")]
    rows = [r for r in rows if not r.get("missing")]
    broken = []
    print("| army | map | seed | green v rust | units | squads | elements max | biggest | outside (deploy) | alive | winner | ended s | postures | ms/tick |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        postures = "; ".join(f"{'GR'[int(k)]}:{','.join(v)}" for k, v in sorted(r["postures"].items()))
        print(f"| {r.get('army', 'opponent')} | {r['arena']} | {r['seed']} | {r['green']} v {r['rust']} | {r['units'][0]} v {r['units'][1]} | "
              f"{r['squads'][0]} v {r['squads'][1]} | {r['elements_max'][0]} v {r['elements_max'][1]} | {r['members_max']} | "
              f"{r['outside']} ({r['deployed_outside']}) | {r['alive'][0]} v {r['alive'][1]} | {r['winner']} | {r['ended_s']} | "
              f"{postures} | {r['ms_per_tick']} |")
        if max(r["elements_max"]) > 10 or r["members_max"] > 5 or r["outside"] > 0 or r["deployed_outside"] > 0:
            broken.append(f"{r['arena']} {r['seed']} {r['green']}:{r['rust']}")
    tasks = {}
    for r in rows:
        for verb, n in r["tasks"].items():
            tasks[verb] = tasks.get(verb, 0) + n
    print("ARMY_SERIES task-seconds by verb: " + ", ".join(f"{k} {v}" for k, v in sorted(tasks.items())))
    for line in errors[:20]:
        print("ARMY_SERIES error: " + line)
    print(f"ARMY_SERIES runs {len(rows)} missing {len(missing)} error lines {len(errors)} broken {len(broken)} {broken}")
    return 1 if missing or errors or broken or not rows else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
