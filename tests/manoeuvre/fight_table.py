#!/usr/bin/env python3
"""Round 29 (manoeuvre M4): the fights guard. Usage: fight_table.py BASE_DIR NEW_DIR (FIGHT_CENSUS lines in *.log).

Paired by (arena, seed), both teams pooled per run: kills, deaths, hit rate (hits / shots) and the hit rate on targets that were
touching something when fired at; per measure the summed paired difference and its se, and whether it is within 2 se.
"""
import glob
import json
import os
import statistics
import sys


def load(d):
    out = {}
    for p in glob.glob(os.path.join(d, "*.log")):
        for line in open(p, errors="replace"):
            if line.startswith("FIGHT_CENSUS "):
                row = json.loads(line.split(" ", 1)[1])
                t = {"shots": 0, "hits": 0, "kills": 0, "deaths": 0, "touch_shots": 0, "touch_hits": 0}
                for team in row["teams"].values():
                    for k in t:
                        t[k] += int(team.get(k, 0))
                out[(row.get("arena", ""), row["seed"])] = t  # round 35: keyed by arena too (FIGHT_AT fixed arenas)
    return out


def main(base_dir, new_dir):
    base, new = load(base_dir), load(new_dir)
    seeds = sorted(set(base) & set(new))
    print(f"FIGHT_GUARD runs paired {len(seeds)} (base {len(base)}, new {len(new)})")
    for k in ("kills", "deaths", "shots", "hits", "touch_shots", "touch_hits"):
        d = [new[s][k] - base[s][k] for s in seeds]
        se = statistics.stdev(d) * len(d) ** 0.5 if len(d) > 1 else float("nan")
        print(f"FIGHT_GUARD {k}: base {sum(base[s][k] for s in seeds)} new {sum(new[s][k] for s in seeds)} "
              f"diff {sum(d):+d} se {se:.1f} {'within 2 se' if abs(sum(d)) <= 2 * se else 'OUTSIDE 2 se'}")
    for label, num, den in (("hit rate", "hits", "shots"), ("hit rate on touching targets", "touch_hits", "touch_shots")):
        rb = [base[s][num] / base[s][den] for s in seeds if base[s][den] and new[s][den]]
        rn = [new[s][num] / new[s][den] for s in seeds if base[s][den] and new[s][den]]
        d = [a - b for a, b in zip(rn, rb)]
        if len(d) < 2:
            print(f"FIGHT_GUARD {label}: too few runs")
            continue
        se = statistics.stdev(d) / len(d) ** 0.5
        m = statistics.mean(d)
        print(f"FIGHT_GUARD {label}: base {statistics.mean(rb):.3f} new {statistics.mean(rn):.3f} paired mean diff "
              f"{m:+.3f} se {se:.3f} {'within 2 se' if abs(m) <= 2 * se else 'OUTSIDE 2 se'} (n {len(d)})")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
