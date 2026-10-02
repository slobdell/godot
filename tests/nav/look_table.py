#!/usr/bin/env python3
"""Round 15 (nav V2): what the planner saw BEFORE it planned a first k-turn leg. Reads NAV_KTURN_LEG rows (the drive's
--reverse-log) and, for first legs, the `looks` (the last checks of a moving hull: steering error, the full-lock arc's
hit, speed, stopping distance). Splits first legs by whether their roll-out was clear (`roll_margin_m` >= 0) and asks,
for an earlier trigger, at which look the hit was first within the stopping distance plus a margin.

Usage: look_table.py 'build/nav-drive/rigs-*.log' [MARGIN_M=1.0]
"""
import glob
import json
import statistics
import sys
from collections import Counter


def main(pattern, margin):
    legs = []
    for path in sorted(glob.glob(pattern)):
        for line in open(path, errors="replace"):
            if line.startswith("NAV_KTURN_LEG "):
                row = json.loads(line[len("NAV_KTURN_LEG "):])
                if int(row.get("leg_no", 0)) == 1:
                    legs.append(row)
    late = [r for r in legs if r.get("roll_margin_m") is not None and float(r["roll_margin_m"]) < 0.0]
    print("first legs %d, roll-out NOT clear %d (contacts %d, reverse %d)" % (len(legs), len(late),
          sum(int(r.get("contacts", 0)) for r in late), sum(int(r.get("reverse_contacts", 0)) for r in late)))
    for name, group in (("roll-out NOT clear", late), ("all first legs", legs)):
        lead = Counter()
        errs = []
        for r in group:
            looks = r.get("looks", [])
            # The last look IS the plan (error >= 45 deg). How many looks before it was the hit already within the
            # hull's stop + margin, and what was the error then?
            first = None
            for i, look in enumerate(looks):
                hit = float(look.get("hit", -1.0))
                if hit >= 0.0 and hit <= float(look.get("stop", 0.0)) + margin:
                    first = i
                    break
            if first is None:
                lead["never within stop+margin"] += 1
                continue
            ahead = len(looks) - 1 - first
            lead["%d look(s) before the plan" % ahead] += 1
            errs.append(float(looks[first]["err"]))
        print("%s: %s; error at that look min/med/max %s" % (name, dict(sorted(lead.items())),
              "%.0f/%.0f/%.0f" % (min(errs), statistics.median(errs), max(errs)) if errs else "-"))
    print("\nroll-out NOT clear, each leg's looks (err deg, hit m, v m/s, stop m), oldest first:")
    for r in late[:30]:
        print("  %s c=%d: %s" % (r.get("unit", "?"), int(r.get("contacts", 0)), " ".join(
            "(%d,%s,%.1f,%.1f)" % (int(l["err"]), l["hit"], float(l["v"]), float(l["stop"])) for l in r.get("looks", []))))


if __name__ == "__main__":
    main(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 1.0)
