#!/usr/bin/env python3
"""Summarise `make container-contacts` (yard, round 17): per map and arm (square / turned), the median and worst of
each contact count over the seeds, and the paired difference seed by seed (the same seed is the same fight start)."""
import json
import statistics
import sys

KEYS = ("long_plant_kturn", "long_plant_kturn_container", "long_kturn_any", "long_steer", "long_container", "all")


def main(path):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    maps = sorted({r["arena"] for r in rows if r["tag"] == "turned"})
    by = {}
    for r in rows:
        name = r["arena"] if r["tag"] == "turned" else r["arena"]
        by.setdefault((name, r["tag"]), {})[r["seed"]] = r
    for m in maps:
        sq, tu = by.get((m, "square"), {}), by.get((m, "turned"), {})
        seeds = sorted(set(sq) & set(tu), key=int)
        parts = []
        for k in KEYS:
            a = [sq[s][k] for s in seeds]
            b = [tu[s][k] for s in seeds]
            if not seeds:
                continue
            parts.append("%s square med %g worst %d | turned med %g worst %d | paired diff med %+g"
                         % (k, statistics.median(a), max(a), statistics.median(b), max(b),
                            statistics.median([y - x for x, y in zip(a, b)])))
        print("CONTACT_SUMMARY %s n=%d (seeds %s)" % (m, len(seeds), ",".join(seeds)))
        for p in parts:
            print("CONTACT_SUMMARY   " + p)
    missing = [(r["arena"], r["tag"]) for r in rows if not r.get("ticks")]
    if missing:
        print("CONTACT_SUMMARY empty runs: %s" % missing)


if __name__ == "__main__":
    main(sys.argv[1])
