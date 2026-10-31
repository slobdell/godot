#!/usr/bin/env python3
"""Round 47 (engage E1): GUN_TRACE lines -> seconds each crew held fire, by the gate that held it.

    python3 tests/engage/gun_trace_table.py LOG [--crews=Green_Guns] [--end=<tick>]

A row's state lasts until that crew's next row (rows print on a change of the gate key and every 15 ticks). Only time with an
enemy inside the crew's weapon range is counted ("an enemy close enough to hit"), split by why the trigger was not pulled:
  reload    the gun is loading (not ready)
  no_line   the crew's own line to every in-range enemy is blocked (cover; Perception's eye ray)
  unseen    a line but the team has no sight of it (intel)
  laying    a pick and a line: the acquisition lay is building (Engagement gate 2)
  lane      a friend in the line of fire (the lane rule)
  discipline  fixed and in reach but past the weapon's effective range, no long shot, not suppressed (Engagement gate 3)
  aim       fixed, inside the band, the turret not yet on (aim error over the weapon's tolerance)
  other     anything else (the order, a hold_fire, a pick that is not the probed contact)
"""
import json
import sys
from collections import defaultdict


def main():
    path = sys.argv[1]
    crews = "Green_"
    end = None
    for a in sys.argv[2:]:
        if a.startswith("--crews="):
            crews = a.split("=", 1)[1]
        if a.startswith("--end="):
            end = int(a.split("=", 1)[1])
    rows = defaultdict(list)
    for line in open(path):
        if line.startswith("GUN_TRACE "):
            d = json.loads(line[10:])
            if crews in d["n"]:
                rows[d["n"]].append(d)
    total = defaultdict(lambda: defaultdict(float))
    for n, rs in rows.items():
        for i, d in enumerate(rs):
            t1 = rs[i + 1]["t"] if i + 1 < len(rs) else min(d["t"] + 15, end if end is not None else d["t"] + 15)
            dt = max(0, t1 - d["t"]) / 30.0
            reach = float(d.get("range", 50.0))
            probes = [x for x in (d.get("named"), d.get("nearest")) if isinstance(x, dict) and x["d"] <= reach]
            if not probes:
                continue
            if d.get("fire"):
                total[n]["fired"] += dt
            elif not d.get("ready"):
                total[n]["reload"] += dt
            elif d.get("lane"):
                total[n]["lane"] += dt
            elif not any(x["los"] for x in probes):
                total[n]["no_line"] += dt
            elif not any(x["los"] and x["seen"] for x in probes):
                total[n]["unseen"] += dt
            elif d.get("pick") and float(d.get("lay", 0)) < max(x["need"] for x in probes if x["los"]) - 0.01:
                total[n]["laying"] += dt
            elif d.get("pick") and "eff" in d and not d.get("long_shot") and float(d.get("supp", 0)) < 0.25 \
                    and min(x["d"] for x in probes if x["los"]) > float(d["eff"]) * (1.12 if d.get("firing") else 1.0):
                total[n]["discipline"] += dt
            elif d.get("pick") and "aim_tol" in d and min(abs(float(x["aim_err"])) for x in probes if x["los"]) > float(d["aim_tol"]):
                total[n]["aim"] += dt
            else:
                total[n]["other"] += dt
            total[n]["in_range"] += dt
    keys = ["in_range", "fired", "reload", "no_line", "unseen", "laying", "discipline", "aim", "lane", "other"]
    print("%-18s" % "crew" + "".join("%9s" % k for k in keys))
    sums = defaultdict(float)
    for n in sorted(total):
        print("%-18s" % n + "".join("%9.1f" % total[n][k] for k in keys))
        for k in keys:
            sums[k] += total[n][k]
    print("%-18s" % "ALL" + "".join("%9.1f" % sums[k] for k in keys))
    print("GUN_TABLE " + json.dumps({k: round(sums[k], 2) for k in keys}))


if __name__ == "__main__":
    main()
