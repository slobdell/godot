#!/usr/bin/env python3
"""Round 32 (manoeuvre H1b): pool `make manoeuvre-h1b-drive` logs (<arm>-<squad>-<seed>.log) into one row per run and
per-arm totals: arrivals, escape fires on hulls, asks, backs, H1b's failed asks / loops / settles / far / metres short."""
import json, os, sys
from collections import defaultdict

rows = []
for path in sys.argv[1:]:
    arm, squad, seed = os.path.basename(path)[:-4].split("-")
    legs, h1b = [], None
    for line in open(path, errors="replace"):
        if line.startswith("NAV_DRIVE_LEG "):
            legs.append(json.loads(line[len("NAV_DRIVE_LEG "):]))
        elif line.startswith("H1B_DRIVE "):
            h1b = json.loads(line[len("H1B_DRIVE "):])
    if h1b is None:
        print(f"H1B_TABLE {arm} {squad} {seed}: NO H1B_DRIVE line (the run did not finish)")
        continue
    rows.append({"arm": arm, "squad": squad, "seed": int(seed), "arrived": sum(l["arrived"] for l in legs),
                 "of": sum(l["units"] for l in legs), "fires": h1b["escape"]["fires_hull"], "asks": h1b["escape"]["asks"],
                 "backs": h1b["escape"]["backs"], **{k: h1b["h1b"][k] for k in ("failed_asks", "loops", "settles", "far", "short_m")}})
keys = ["arrived", "of", "fires", "asks", "backs", "failed_asks", "loops", "settles", "far", "short_m"]
print("H1B_TABLE arm squad seed " + " ".join(keys))
for r in sorted(rows, key=lambda r: (r["squad"], r["seed"], r["arm"])):
    print("H1B_TABLE %s %s %d %s" % (r["arm"], r["squad"], r["seed"], " ".join(str(r[k]) for k in keys)))
tot = defaultdict(lambda: defaultdict(float))
for r in rows:
    for k in keys:
        tot[(r["arm"], r["squad"])][k] += r[k]
    tot[(r["arm"], r["squad"])]["n"] += 1
for (arm, squad), t in sorted(tot.items()):
    print("H1B_TOTAL %s %s n=%d %s" % (arm, squad, t["n"], " ".join("%s=%g" % (k, round(t[k], 1)) for k in keys)))
