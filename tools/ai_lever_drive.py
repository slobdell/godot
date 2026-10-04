#!/usr/bin/env python3
"""Round 17 (brains): summarise `make ai-lever-drive` -- per map, each arm against the champion's arm on the SAME seeds:
wall-contact ticks per minute (long hulls' plant x kturn, long hulls' steer scrapes, every hull), wedged units,
unstick fires and k-turn legs per match, units lost per side; median, mean and the paired difference seed by seed."""
import json
import statistics
import sys

KEYS = ("long_plant_kturn", "long_steer", "all", "wedged_units", "unstick_fires", "kturns", "kturn_aborted")
PER_MINUTE = ("long_plant_kturn", "long_steer", "all")


def value(row, key):
    v = float(row.get(key, 0))
    return v / max(float(row.get("minutes", 1.0)), 1e-6) if key in PER_MINUTE else v


def main(path, champion="x5p"):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    by = {}
    for r in rows:
        by.setdefault((r["arena"], r["tag"]), {})[str(r["seed"])] = r
    for arena in sorted({r["arena"] for r in rows}):
        base = by.get((arena, champion), {})
        for tag in sorted({r["tag"] for r in rows if r["arena"] == arena}):
            mine = by[(arena, tag)]
            seeds = sorted(set(base) & set(mine), key=int)
            parts = []
            for k in KEYS:
                a = [value(mine[s], k) for s in seeds]
                d = [value(mine[s], k) - value(base[s], k) for s in seeds]
                if a:
                    parts.append("%s %.1f/%.1f (paired %+.1f)" % (k + ("/min" if k in PER_MINUTE else ""),
                                                                  statistics.median(a), statistics.mean(a), statistics.median(d)))
            lost = [mine[s].get("units_lost") or [0, 0] for s in seeds]
            lost_txt = " lost green/rust %.1f/%.1f" % (statistics.mean([float(l[0]) for l in lost] or [0]),
                                                      statistics.mean([float(l[1]) for l in lost] or [0]))
            print("LEVER_DRIVE_SUMMARY %s %s n=%d: %s;%s" % (arena, tag, len(seeds), "; ".join(parts), lost_txt))


if __name__ == "__main__":
    main(sys.argv[1], *(sys.argv[2:3]))
