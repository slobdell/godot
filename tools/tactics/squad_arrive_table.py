#!/usr/bin/env python3
"""Round 19 (brains B4): the squad-arrive series as a table.

Per squad x map: arrived k of n (median arrival s), re-seats, swaps, for each arm (make-room on / off), and the totals.
A run that printed nothing is counted as missing (and fails the target).

Round 27 (brains B1, lesson 293): "arrived" is EVERY CREW on its slot (the probe's all_in_s, ArrivalLine), not the
element's own flag. A run whose element said arrived while the line never held is HOLLOW (marked h, and counted).
Rows from before B1 (no all_in_s) fall back to arrived_s and say so.

Usage: squad_arrive_table.py build/squad-arrive.jsonl [arm flag name, default make-room]
"""
import json
import statistics
import sys
from collections import defaultdict


def _arrival(row):
    """Every crew on its slot (round 27); a pre-B1 row has only the element's own arrival."""
    if "all_in_s" in row:
        return row["all_in_s"]
    return row.get("arrived_s")


def main(path, flag="make-room"):
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
        print(f"{flag} {arm}: arrived k of n (median s), re-seats, swaps")
        print("| squad | " + " | ".join(maps) + " |")
        print("|---|" + "---|" * len(maps))
        total = arrived = said = 0
        hollow_total = [0]
        for squad in squads:
            line = []
            for arena in maps:
                runs = [r for r in cells[(arm, squad, arena)] if not r.get("missing")]
                done = [_arrival(r) for r in runs if _arrival(r) is not None]
                hollow = sum(1 for r in runs if r.get("hollow"))
                hollow_total[0] += hollow
                said += sum(1 for r in runs if r.get("arrived_s") is not None)
                total += len(cells[(arm, squad, arena)])
                arrived += len(done)
                median = f" ({statistics.median(done):.1f})" if done else ""
                mark = f" {hollow}h" if hollow else ""
                line.append(f"{len(done)}/{len(cells[(arm, squad, arena)])}{median}{mark}, "
                            f"{sum(int(r.get('reseats', 0)) for r in runs)}, {sum(int(r.get('swaps', 0)) for r in runs)}")
            print(f"| {squad} | " + " | ".join(line) + " |")
        print(f"SQUAD_ARRIVE {flag}={arm}: {arrived} of {total} arrive (every crew on its slot); the element said "
              f"{said}; hollow {hollow_total[0]}")
        # How far off the worst crew stood at the end of each HOLLOW run: a ragged halt (a few metres) and a crew stuck
        # behind a squadmate (lesson 293: 19-26 m) are different failures.
        offs = sorted(float(r.get("worst_off_m", -1)) for squad in squads for arena in maps
                      for r in cells[(arm, squad, arena)] if r.get("hollow"))
        if offs:
            bands = {"<=6 m": sum(1 for o in offs if o <= 6), "6-12 m": sum(1 for o in offs if 6 < o <= 12),
                     ">12 m": sum(1 for o in offs if o > 12)}
            print(f"SQUAD_ARRIVE {flag}={arm} hollow worst crew off: " + ", ".join(f"{k} {v}" for k, v in bands.items())
                  + f" (median {statistics.median(offs):.1f} m)")
    print(f"SQUAD_ARRIVE missing {missing}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:3]))
