#!/usr/bin/env python3
"""Round 17 (sim F1): read N windowed runs of the same command (run1.txt .. runN.txt, SIM_HASH lines) and report the
fork rate. A run's trajectory is its sequence of (tick, hash); the frame counters after the hash are not compared.

Prints one WINDOWED_SERIES line (machine-readable) and a human table:
  - classes: runs with identical trajectories, the run numbers in each;
  - pairs (1,2), (3,4), ...: forked or not, and the first tick that differs (the fork rate is k of N pairs);
  - for every run, the first tick that differs from run 1;
  - with --detail: for the first forked pair, the first SIM_HASH_DETAIL lines that differ (the unit and the field).
"""
import glob
import json
import os
import re
import sys


def load(path):
    hashes, details, frames = [], {}, {}
    for line in open(path, errors="replace"):
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "SIM_HASH" and len(parts) >= 3:
            tick = int(parts[1].split("=")[1])
            hashes.append((tick, parts[2]))
            if len(parts) >= 4 and parts[3].startswith("frames="):
                frames[tick] = parts[3][7:]
        elif parts[0] == "SIM_HASH_DETAIL" and len(parts) >= 3:
            tick = int(parts[1].split("=")[1])
            details.setdefault(tick, []).append(line.rstrip("\n"))
    return hashes, details, frames


def first_divergence(a, b):
    for (ta, ha), (tb, hb) in zip(a, b):
        if ta != tb or ha != hb:
            return ta
    if len(a) != len(b):
        return "length %d/%d" % (len(a), len(b))
    return None


def detail_diff(da, db):
    for tick in sorted(set(da) & set(db)):
        a, b = da[tick], db[tick]
        if a != b:
            out = []
            for x, y in zip(a, b):
                if x != y:
                    out.append((x, y))
            return tick, out
    return None, []


def main():
    folder = sys.argv[1]
    label = sys.argv[2] if len(sys.argv) > 2 else ""
    paths = sorted(glob.glob(os.path.join(folder, "run*.txt")), key=lambda p: int(re.findall(r"\d+", os.path.basename(p))[0]))
    runs = [load(p) for p in paths]
    n = len(runs)
    if n < 2:
        print("WINDOWED_SERIES %s runs=%d (need 2+)" % (label, n))
        return
    classes = {}
    for i, (h, _, _) in enumerate(runs):
        classes.setdefault(tuple(h), []).append(i + 1)
    pairs = []
    for i in range(0, n - 1, 2):
        pairs.append((i + 1, i + 2, first_divergence(runs[i][0], runs[i + 1][0])))
    forked = [p for p in pairs if p[2] is not None]
    vs_one = [first_divergence(runs[0][0], r[0]) for r in runs]
    summary = {"label": label, "runs": n, "lines": [len(r[0]) for r in runs], "classes": sorted(classes.values()),
               "pairs": len(pairs), "forked_pairs": len(forked),
               "pair_forks": [p[2] for p in pairs], "vs_run1": vs_one}
    print("WINDOWED_SERIES " + json.dumps(summary))
    print("  %d runs, %d trajectory class(es): %s" % (n, len(classes), sorted(classes.values())))
    print("  pairs forked: %d of %d  %s" % (len(forked), len(pairs), [(a, b, t) for a, b, t in pairs]))
    if "--detail" in sys.argv:
        for a, b, t in forked[:1] or []:
            tick, diffs = detail_diff(runs[a - 1][1], runs[b - 1][1])
            print("  first detail difference, runs %d/%d: tick %s, %d line(s)" % (a, b, tick, len(diffs)))
            for x, y in diffs[:12]:
                print("    run%d %s\n    run%d %s" % (a, x, b, y))
            for tk in sorted(runs[a - 1][2])[-1:]:
                print("  frames at tick %d: run%d %s run%d %s" % (tk, a, runs[a - 1][2].get(tk), b, runs[b - 1][2].get(tk)))


if __name__ == "__main__":
    main()
