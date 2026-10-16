#!/usr/bin/env python3
"""Round 32 (brains B10): the grounding latch's drift census from `make ground-series`' rows (arm on = the latch, off =
--ground-latch=off), paired by (cell, seed, start_tick). Per cell and arm: runs with a FLIPPING crew (a seat drifting on
its anchor more than Element.DRIFT_FLIPPING times), drift moves in all, the worst crew; and the arrival reading each cell
has (Sumps: all within 8 m s, median and runs never in; yard / Terminus: runs with every crew in, crews in).
Usage: ground_census.py ground-series.jsonl"""
import json
import statistics
import sys


def load(path):
    rows = {}
    for line in open(path):
        if line.strip():
            r = json.loads(line)
            rows[(r.get("cell"), r.get("arm"), r.get("seed"), r.get("start_tick"))] = r
    return rows


def arrival(r):
    """(complete?, a number to compare: all-in-8 s for Sumps, crews in for the crossings)."""
    if r.get("missing"):
        return (False, None)
    if r.get("cell") == "sumps":
        s = r.get("all_in8_s")
        return (s is not None and float(s) >= 0.0, s)
    return (int(r.get("arrived", 0)) == int(r.get("crews", -1)), int(r.get("arrived", 0)))


def main(path):
    rows = load(path)
    cells = sorted({(k[0], k[2], k[3]) for k in rows})
    missing = [k for k, r in rows.items() if r.get("missing")]
    for cell in sorted({c[0] for c in cells}):
        print("== %s" % cell)
        keys = [c for c in cells if c[0] == cell]
        for arm in ("on", "off"):
            rs = [rows.get((cell, arm, s, t), {"missing": True}) for (_, s, t) in keys]
            flips = sum(1 for r in rs if int(r.get("drift_flipping_crews", 0)) > 0)
            drift = sum(int(r.get("drift_moves", 0)) for r in rs)
            worst = max([int(r.get("drift_worst_crew", 0)) for r in rs] or [0])
            done = [arrival(r) for r in rs]
            line = "  %-3s n %d | runs with a flipping crew %d | drift moves %d | worst crew %d | complete %d" % (
                arm, len(rs), flips, drift, worst, sum(1 for d in done if d[0]))
            if cell == "sumps":
                times = [float(d[1]) for d in done if d[0]]
                line += " | all_in8 median %.2f s" % statistics.median(times) if times else " | all_in8 median -"
            else:
                line += " | crews in %d" % sum(int(d[1] or 0) for d in done)
            print(line)
        later = []
        for (_, s, t) in keys:
            a, b = rows.get((cell, "on", s, t)), rows.get((cell, "off", s, t))
            if not a or not b:
                continue
            (ca, va), (cb, vb) = arrival(a), arrival(b)
            if cell == "sumps":
                if ca and cb and float(va) > float(vb) + 5.0:
                    later.append("s%s t%s %.1f v %.1f s" % (s, t, float(va), float(vb)))
                elif cb and not ca:
                    later.append("s%s t%s never v %.1f s" % (s, t, float(vb)))
            elif (vb or 0) > (va or 0):
                later.append("s%s t%s crews %s v %s" % (s, t, va, vb))
        print("  on worse than off: %s" % (later or "none"))
    if missing:
        print("MISSING rows: %s" % missing)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
