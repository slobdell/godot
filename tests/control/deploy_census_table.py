#!/usr/bin/env python3
"""Round 35 (orders D1, C35.2): the deploy-step fights census. Usage: deploy_census_table.py OFF_DIR ON_DIR.

DEPLOY_CENSUS lines in *.log, paired by (arena, seed). Per side (0 = green, 1 = rust) and both sides pooled: deaths,
kills, stuck crew-seconds, squads deployed; the summed paired difference (on - off), its se, and whether it is within
2 se (a line outside 2 se is GROSS: brought to the orchestrator before shipping). Then the same by arena.
"""
import glob
import json
import os
import statistics
import sys

MEASURES = ("deaths", "kills", "stuck_s", "deploys", "alive")


def load(d):
    out = {}
    for p in glob.glob(os.path.join(d, "*.log")):
        for line in open(p, errors="replace"):
            if line.startswith("DEPLOY_CENSUS "):
                row = json.loads(line.split(" ", 1)[1])
                out[(row["arena"], row["seed"])] = row
    return out


def value(row, side, k):
    if side == "both":
        return sum(float(s[k]) for s in row["sides"])
    return float(row["sides"][side][k])


def lines(off, on, keys, label):
    print(f"DEPLOY_CENSUS_TABLE {label}: fights paired {len(keys)}")
    for side in (0, 1, "both"):
        name = {0: "green", 1: "rust", "both": "both"}[side]
        for k in MEASURES:
            d = [value(on[x], side, k) - value(off[x], side, k) for x in keys]
            se = statistics.stdev(d) * len(d) ** 0.5 if len(d) > 1 else float("nan")
            total = sum(d)
            verdict = "within 2 se" if abs(total) <= 2 * se else "OUTSIDE 2 se"
            print(f"  {name:5} {k:8} off {sum(value(off[x], side, k) for x in keys):8.1f} "
                  f"on {sum(value(on[x], side, k) for x in keys):8.1f} diff {total:+8.1f} se {se:6.1f} {verdict}")


def main(off_dir, on_dir):
    off, on = load(off_dir), load(on_dir)
    keys = sorted(set(off) & set(on))
    print(f"DEPLOY_CENSUS_TABLE off {len(off)} on {len(on)} paired {len(keys)}")
    if not keys:
        return 1
    lines(off, on, keys, "all arenas")
    for arena in sorted({k[0] for k in keys}):
        lines(off, on, [k for k in keys if k[0] == arena], arena)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
