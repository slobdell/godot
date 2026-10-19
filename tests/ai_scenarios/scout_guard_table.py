#!/usr/bin/env python3
"""Brains B1 (C34.5, scout try 2): the bar's (3) fights guard over two `make scout-census` runs (rule ON, and
NAV_FLAGS=--scout-fight=off), one SCOUT_CENSUS line per seed log.

  scout deaths, paired by seed: mean(ON - OFF) <= 1.645 se            (se = sd of the differences / sqrt(n))
  team enemy-seen seconds (both sides summed), paired: mean(ON - OFF) >= -1.645 se
  kills reported
Usage: scout_guard_table.py on_dir off_dir
"""
import glob
import json
import math
import os
import statistics
import sys


def rows(directory):
    out = {}
    for path in glob.glob(os.path.join(directory, "*.log")):
        for line in open(path, errors="replace"):
            if line.startswith("SCOUT_CENSUS "):
                r = json.loads(line[len("SCOUT_CENSUS "):])
                out[int(r["seed"])] = r
    return out


def paired(diffs):
    mean = statistics.mean(diffs)
    se = statistics.stdev(diffs) / math.sqrt(len(diffs)) if len(diffs) > 1 else 0.0
    return mean, se


def main(on_dir, off_dir):
    on, off = rows(on_dir), rows(off_dir)
    seeds = sorted(set(on) & set(off))
    missing = sorted(set(on) ^ set(off))
    seen = lambda r: float(sum(r.get("enemy_seen_s", [0.0, 0.0])))
    print("seeds %s%s" % (seeds, " | MISSING in one arm: %s" % missing if missing else ""))
    for s in seeds:
        a, b = on[s], off[s]
        print("  seed %d %-10s deaths %d v %d | kills %d v %d | enemy-seen %.0f v %.0f s | fight_s %.0f v %.0f" % (
            s, a.get("arena", ""), a["deaths"], b["deaths"], a["kills"], b["kills"], seen(a), seen(b),
            a["fight_s"], b["fight_s"]))
    if not seeds:
        print("SCOUT_GUARD no seeds")
        return
    d_mean, d_se = paired([on[s]["deaths"] - off[s]["deaths"] for s in seeds])
    e_mean, e_se = paired([seen(on[s]) - seen(off[s]) for s in seeds])
    deaths_ok = d_mean <= 1.645 * d_se
    seen_ok = e_mean >= -1.645 * e_se
    print("SCOUT_GUARD n %d | deaths %d v %d, mean diff %+.2f (limit %+.2f) %s | enemy-seen %.0f v %.0f s, mean diff %+.1f "
          "(floor %+.1f) %s | kills %d v %d" % (
              len(seeds), sum(on[s]["deaths"] for s in seeds), sum(off[s]["deaths"] for s in seeds), d_mean,
              1.645 * d_se, "PASS" if deaths_ok else "FAIL", sum(seen(on[s]) for s in seeds),
              sum(seen(off[s]) for s in seeds), e_mean, -1.645 * e_se, "PASS" if seen_ok else "FAIL",
              sum(on[s]["kills"] for s in seeds), sum(off[s]["kills"] for s in seeds)))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
