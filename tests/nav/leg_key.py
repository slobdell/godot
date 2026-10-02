#!/usr/bin/env python3
"""Round 15 (nav V1): which key separates the k-turn legs N3 helps (the War Rig's street turns) from the ones it breaks
(the orbiting scout's taps)? Reads NAV_KTURN_LEG rows from any logs (the drive's --reverse-log, or --leg-print in a
scenario / match) and prints, per population label (`label=glob ...`), the candidate keys side by side:

  hull_len   the hull's length (m)                      -> key (a): hull class
  stop/hull  stopping distance at the leg's start speed over the hull length
  stop/leg   stopping distance at the leg's start speed over the planned leg
  option     the brain's option when the leg was planned -> key (b): plan purpose
  kind       single back-up / back-and-fill; remaining route (m)

Usage: leg_key.py rigs='build/nav-drive/rigs-*.log' scout=build/nav-scen/none.log
"""
import glob
import json
import statistics
import sys
from collections import Counter


def rows(pattern):
    for path in sorted(glob.glob(pattern)):
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("NAV_KTURN_LEG "):
                    try:
                        yield json.loads(line[len("NAV_KTURN_LEG "):])
                    except json.JSONDecodeError:
                        pass


def q(values):
    values = sorted(values)
    if not values:
        return "-"
    return "%.2f/%.2f/%.2f" % (values[0], statistics.median(values), values[-1])


def main(args):
    print("population | units | legs | hull_len min/med/max | |v0| m/s | stop m | stop/hull | stop/leg | planned m | remaining m | kinds | options")
    for arg in args:
        label, pattern = arg.split("=", 1)
        legs = list(rows(pattern))
        if not legs:
            print("%s | no NAV_KTURN_LEG rows in %s" % (label, pattern))
            continue
        units = Counter(r.get("unit_id", "?") for r in legs)
        hull = [float(r.get("hull_len", 0.0)) for r in legs]
        v0 = [abs(float(r.get("v0", 0.0))) for r in legs]
        stop = [v * v / (2.0 * max(float(r.get("braking", 8.0)), 0.1)) for v, r in zip(v0, legs)]
        planned = [float(r.get("planned_m", 0.0)) for r in legs]
        print("%s | %s | %d | %s | %s | %s | %s | %s | %s | %s | %s | %s" % (
            label, dict(units), len(legs), q(hull), q(v0), q(stop),
            q([s / max(h, 0.1) for s, h in zip(stop, hull)]),
            q([s / max(p, 0.1) for s, p in zip(stop, planned)]), q(planned),
            q([float(r.get("remaining_m", 0.0)) for r in legs]),
            dict(Counter("%s/%s" % (r.get("kind", "?"), "fwd" if int(r.get("gear", -1)) > 0 else "rev") for r in legs)),
            dict(Counter(r.get("option", "") or "-" for r in legs))))


if __name__ == "__main__":
    main(sys.argv[1:])
