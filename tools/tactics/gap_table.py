#!/usr/bin/env python3
"""Round 22 (brains B4): the range gap as a table, for him (no price moves; C12.6 is his).

Per case x map x arm (--duck on = B1, off = round 21): runs, who won, the Rat Rods' alive and loss, the Syndicate's
alive and loss, when the Rat Rods first drew blood, and which B1 outcomes each side took. A run that printed nothing is
MISSING and fails the target.

Usage: gap_table.py build/gap-series.jsonl
"""
import json
import statistics
import sys
from collections import Counter


def _mean(values):
    values = list(values)
    return statistics.mean(values) if values else float("nan")


def main(path):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    missing = [r for r in rows if r.get("missing")]
    rows = [r for r in rows if not r.get("missing")]
    print("| case | map | duck | n | Syndicate won | Rat Rods won | Rat Rods alive (of) | Rat Rods lost | Syndicate alive (of) | Syndicate lost | first blood s | B1 rods | B1 syn |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    keys = []
    for r in rows:
        if (r["case"], r["arena"]) not in keys:
            keys.append((r["case"], r["arena"]))
    for case, arena in keys:
        for arm in ("off", "on"):
            cell = [r for r in rows if r["case"] == case and r["arena"] == arena and r["duck"] == arm]
            if not cell:
                continue
            rods_b1, syn_b1 = Counter(), Counter()
            for r in cell:
                rods_b1.update(r["ducks"]["rods"])
                syn_b1.update(r["ducks"]["syn"])
            blood = [r["rods_first_hit_s"] for r in cell if r["rods_first_hit_s"] >= 0]
            print(f"| {case} | {arena} | {arm} | {len(cell)} | {sum(1 for r in cell if r['winner'] == 'syndicate')} | "
                  f"{sum(1 for r in cell if r['winner'] == 'rods')} | {_mean(r['rods_alive'] for r in cell):.1f} ({cell[0]['rods']}) | "
                  f"{_mean(r['rods_lost'] for r in cell):.0f} | {_mean(r['syn_alive'] for r in cell):.1f} ({cell[0]['syn']}) | "
                  f"{_mean(r['syn_lost'] for r in cell):.0f} | {_mean(blood):.1f} ({len(blood)} runs) | "
                  f"{dict(rods_b1) or '-'} | {dict(syn_b1) or '-'} |")
    print(f"GAP_SERIES missing {len(missing)}")
    return 1 if missing or not rows else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
