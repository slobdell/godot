#!/usr/bin/env python3
"""Round 47 (engage E10): the outranged probe's table. One folder: per-run rows and totals. --pair OFF ON: paired by seed,
mean ON - OFF and its se for each line (Bar E10 reads D1 out_damage, D2 retreat_m / reverse_m, the guards)."""
import json
import math
import os
import sys

LINES = ["out_damage", "out_s", "deaths", "enemy_deaths", "dealt", "friendly_hits", "reverse_m", "retreat_m_mean"]


def rows(folder):
    out = {}
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".log"):
            continue
        with open(os.path.join(folder, name), errors="replace") as handle:
            for line in handle:
                if line.startswith("OUTRANGED_PROBE "):
                    row = json.loads(line.split(" ", 1)[1])
                    if "error" in row:
                        continue
                    ends = row.get("retreat_m", [])
                    row["retreat_m_mean"] = sum(ends) / len(ends) if ends else None
                    out[row["seed"]] = row
    return out


def one(folder):
    table = rows(folder)
    for seed, row in sorted(table.items()):
        print(seed, row["arena"], row["hull"], "v", row["shooter"], row["order"], "d", row["distance"],
              " ".join("%s %s" % (k, row.get(k)) for k in LINES))
    print("runs %d" % len(table))
    for key in LINES:
        values = [r[key] for r in table.values() if r.get(key) is not None]
        print("%-14s total %.1f mean %.2f n %d" % (key, sum(values), sum(values) / max(len(values), 1), len(values)))


def pair(off_folder, on_folder):
    off, on = rows(off_folder), rows(on_folder)
    seeds = sorted(set(off) & set(on))
    print("paired seeds: %d (off %d, on %d)" % (len(seeds), len(off), len(on)))
    print("%-14s %10s %10s %10s %8s %8s" % ("line", "OFF", "ON", "mean diff", "se", "z"))
    for key in LINES:
        both = [(off[s][key], on[s][key]) for s in seeds if off[s].get(key) is not None and on[s].get(key) is not None]
        if not both:
            print("%-14s (no pairs)" % key)
            continue
        diffs = [b - a for a, b in both]
        n = len(diffs)
        mean = sum(diffs) / n
        var = sum((d - mean) ** 2 for d in diffs) / (n - 1) if n > 1 else 0.0
        se = math.sqrt(var / n) if n > 1 else 0.0
        z = mean / se if se > 0 else 0.0
        print("%-14s %10.2f %10.2f %10.2f %8.2f %8.2f  (n %d, totals %.1f -> %.1f)" % (key, sum(a for a, _ in both) / n,
              sum(b for _, b in both) / n, mean, se, z, n, sum(a for a, _ in both), sum(b for _, b in both)))


if __name__ == "__main__":
    if sys.argv[1] == "--pair":
        pair(sys.argv[2], sys.argv[3])
    else:
        one(sys.argv[1])
