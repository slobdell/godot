#!/usr/bin/env python3
"""Round 47 (manoeuvre M3): Bar M's paired judge.

  barm_judge.py build/manoeuvre/bar-m/logs [--team=0]

One cell = map x headings x seed; the arms (base, buried) are read from each log's name (<map>-<headings>-<arm>-s<seed>.log).
Per log: the LAST `NOPROGRESS {...}` line (the census: crew-seconds with no progress toward the seat, wall-contact seconds, the
buried rule's swaps) and the `ORDERS_PROBE {...}` run line (all-in seconds, never-in squads, blocked / yielding / slow crew-seconds).
Prints, per line, the two arms' totals, the paired mean difference (buried - base) a cell, its se and z, n, and the share of cells
"buried sooner or identical" (lesson 344), over all cells and over the cells where the rule swapped at least once. Measurement only:
the verdict is the filing's, read against these numbers.
"""
import json, math, os, re, sys
from collections import defaultdict

NAME = re.compile(r"^(?P<map>[a-z_]+)-(?P<head>[a-z]+)-(?P<arm>[a-z0-9_]+)-s(?P<seed>\d+)\.log$")


def read(path, team):
    census, run = None, None
    for line in open(path, errors="replace"):
        if line.startswith("NOPROGRESS {"):
            census = json.loads(line[len("NOPROGRESS "):])
        elif line.startswith("ORDERS_PROBE {"):
            run = json.loads(line[len("ORDERS_PROBE "):])
    if census is None or run is None:
        return None
    side = census.get(str(team), {"s": 0.0, "contact_s": 0.0, "n": 0})
    g = run.get("group", {})
    all_in = run.get("all_in_s", -1)
    return {"noprog_s": side["s"], "contact_s": side.get("contact_s", 0.0), "swaps": census.get("swaps", 0),
            "all_in_s": all_in if all_in >= 0 else float(run.get("window_s", 180)), "never_in": 1 if all_in < 0 else 0,
            "blocked_s": g.get("blocked_s", 0.0), "yielding_s": g.get("yielding_s", 0.0), "slow_s": g.get("slow_s", 0.0)}


def paired(rows, key):
    d = [r["buried"][key] - r["base"][key] for r in rows]
    n = len(d)
    if n == 0:
        return "n 0"
    mean = sum(d) / n
    se = math.sqrt(sum((x - mean) ** 2 for x in d) / (n - 1) / n) if n > 1 else 0.0
    z = mean / se if se > 0 else 0.0
    base = sum(r["base"][key] for r in rows)
    arm = sum(r["buried"][key] for r in rows)
    sooner = sum(1 for x in d if x <= 1e-9) / n
    strictly = sum(1 for x in d if x < -1e-9) / n
    return "base %.1f -> buried %.1f | diff %+.3f a cell, se %.3f, z %+.2f, n %d | buried sooner-or-identical %.0f %% (strictly %.0f %%)" % (
        base, arm, mean, se, z, n, 100 * sooner, 100 * strictly)


def main(argv):
    folder = argv[1]
    team = 0
    for a in argv[2:]:
        if a.startswith("--team="):
            team = int(a.split("=")[1])
    cells = defaultdict(dict)
    missing = []
    for f in sorted(os.listdir(folder)):
        m = NAME.match(f)
        if not m:
            continue
        row = read(os.path.join(folder, f), team)
        if row is None:
            missing.append(f)
            continue
        cells[(m["map"], m["head"], int(m["seed"]))][m["arm"]] = row
    rows = [c for c in cells.values() if "base" in c and "buried" in c]
    print("BAR_M cells paired %d, logs missing a line %d %s" % (len(rows), len(missing), missing[:6]))
    touched = [r for r in rows if r["buried"]["swaps"] > 0]
    for label, subset in (("ALL", rows), ("TOUCHED (swaps > 0)", touched)):
        print("== %s: %d cells" % (label, len(subset)))
        for key in ("noprog_s", "all_in_s", "never_in", "contact_s", "blocked_s", "yielding_s", "slow_s"):
            print("  %-10s %s" % (key, paired(subset, key)))
    by_map = defaultdict(list)
    for (mp, _h, _s), c in cells.items():
        if "base" in c and "buried" in c:
            by_map[mp].append(c)
    for mp in sorted(by_map):
        print("  map %-9s noprog_s %s" % (mp, paired(by_map[mp], "noprog_s")))
    untouched = [r for r in rows if r["buried"]["swaps"] == 0]
    same = sum(1 for r in untouched if all(abs(r["buried"][k] - r["base"][k]) < 1e-9 for k in r["base"] if k != "swaps"))
    print("UNTOUCHED cells identical in every line: %d of %d" % (same, len(untouched)))


if __name__ == "__main__":
    main(sys.argv)
