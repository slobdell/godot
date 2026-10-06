#!/usr/bin/env python3
"""Round 19 (brains B4): the squad-arrive series as a table.

Per squad x map: arrived k of n (median arrival s), re-seats, swaps, for each arm (make-room on / off), and the totals.
A run that printed nothing is counted as missing (and fails the target).

Usage: squad_arrive_table.py build/squad-arrive.jsonl
"""
import json
import statistics
import sys
from collections import defaultdict


def main(path):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    cells = defaultdict(list)
    arms, maps, squads = [], [], []
    for row in rows:
        for value, seen in ((row.get("arm"), arms), (row.get("arena"), maps), (row.get("units"), squads)):
            if value not in seen:
                seen.append(value)
        cells[(row.get("arm"), row.get("units"), row.get("arena"))].append(row)
    missing = sum(1 for row in rows if row.get("missing"))
    for arm in arms:
        print(f"make-room {arm}: arrived k of n (median s), re-seats, swaps")
        print("| squad | " + " | ".join(maps) + " |")
        print("|---|" + "---|" * len(maps))
        total = arrived = 0
        for squad in squads:
            line = []
            for arena in maps:
                runs = [r for r in cells[(arm, squad, arena)] if not r.get("missing")]
                done = [r["arrived_s"] for r in runs if r.get("arrived_s") is not None]
                total += len(cells[(arm, squad, arena)])
                arrived += len(done)
                median = f" ({statistics.median(done):.1f})" if done else ""
                line.append(f"{len(done)}/{len(cells[(arm, squad, arena)])}{median}, "
                            f"{sum(int(r.get('reseats', 0)) for r in runs)}, {sum(int(r.get('swaps', 0)) for r in runs)}")
            print(f"| {squad} | " + " | ".join(line) + " |")
        print(f"SQUAD_ARRIVE make-room={arm}: {arrived} of {total} arrive")
    print(f"SQUAD_ARRIVE missing {missing}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
