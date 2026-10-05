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
        if not sq:
            # Round 18 (maps): one arm only (`CC_TURNED_ONLY=1`, a candidate with no frozen square copy) -- the counts
            # themselves, per match and per minute of fight, to set beside the dealt maps' turned arm.
            seeds = sorted(tu, key=int)
            print("CONTACT_SUMMARY %s n=%d (seeds %s), one arm; fight length s med %.0f"
                  % (m, len(seeds), ",".join(seeds), statistics.median([tu[s]["ticks"] / 30.0 for s in seeds] or [0])))
            for k in KEYS:
                b = [tu[s][k] for s in seeds]
                rb = [tu[s][k] * 1800.0 / max(1, tu[s]["ticks"]) for s in seeds]
                print("CONTACT_SUMMARY   %s med %g worst %d || per min med %.1f worst %.1f"
                      % (k, statistics.median(b), max(b), statistics.median(rb), max(rb)))
            continue
        seeds = sorted(set(sq) & set(tu), key=int)
        parts = []
        for k in KEYS:
            a = [sq[s][k] for s in seeds]
            b = [tu[s][k] for s in seeds]
            if not seeds:
                continue
            # Per minute of fight too: the same seed is a different fight length on the two layouts (a match ends
            # when a side is eliminated, or at the cap), so a raw count partly measures how long it went on.
            ra = [sq[s][k] * 1800.0 / max(1, sq[s]["ticks"]) for s in seeds]
            rb = [tu[s][k] * 1800.0 / max(1, tu[s]["ticks"]) for s in seeds]
            parts.append("%s square med %g worst %d | turned med %g worst %d | paired diff med %+g || per min: square med %.1f, "
                         "turned med %.1f, paired diff med %+.1f, turned higher on %d of %d seeds"
                         % (k, statistics.median(a), max(a), statistics.median(b), max(b),
                            statistics.median([y - x for x, y in zip(a, b)]), statistics.median(ra), statistics.median(rb),
                            statistics.median([y - x for x, y in zip(ra, rb)]), sum(1 for x, y in zip(ra, rb) if y > x),
                            len(seeds)))
        print("CONTACT_SUMMARY %s n=%d (seeds %s); fight length s: square med %.0f, turned med %.0f"
              % (m, len(seeds), ",".join(seeds), statistics.median([sq[s]["ticks"] / 30.0 for s in seeds] or [0]),
                 statistics.median([tu[s]["ticks"] / 30.0 for s in seeds] or [0])))
        for p in parts:
            print("CONTACT_SUMMARY   " + p)
    missing = [(r["arena"], r["tag"]) for r in rows if not r.get("ticks")]
    if missing:
        print("CONTACT_SUMMARY empty runs: %s" % missing)


if __name__ == "__main__":
    main(sys.argv[1])
