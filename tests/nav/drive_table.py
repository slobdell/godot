#!/usr/bin/env python3
"""Round 12 (nav N3): the Terminus drive's NAMED numbers per squad and arm, and the discordant seed pairs.

Usage: drive_table.py ARM=DIR [ARM=DIR ...]    (each DIR holds <squad>-<seed>.log from `make nav-terminus-drive`)

The named numbers (navigation.md *Noise*): arrivals, leg time, total wall-contact ticks, press/unstick-driven contact
ticks, reverse-gear contact ticks, cusps, and the planned reverse's counters (kturns / kturn_multi / kturn_none /
kturn_aborted). Arms are compared on the SAME seeds: a seed present in one arm and not the other is refused.
"""
import glob
import json
import os
import sys
from collections import defaultdict


def read(directory):
    runs = {}
    for path in sorted(glob.glob(os.path.join(directory, "*.log"))):
        name = os.path.basename(path).removesuffix(".log")
        squad, seed = name.rsplit("-", 1)
        legs, final = [], None
        for line in open(path, errors="replace"):
            if line.startswith("NAV_DRIVE_LEG "):
                legs.append(json.loads(line[len("NAV_DRIVE_LEG "):]))
            elif line.startswith("NAV_DRIVE "):
                final = json.loads(line[len("NAV_DRIVE "):])
        if final is None:
            print("REFUSED %s: no NAV_DRIVE line (the run did not finish)" % path)
            continue
        wc = final["wall_contacts"]
        drivers = wc.get("by_driver", {})
        gears = wc.get("by_gear", {})
        arms = final.get("route_arms", {})
        runs[(squad, int(seed))] = {
            "arrived": sum(int(l["arrived"]) for l in legs), "units": sum(int(l["units"]) for l in legs),
            "leg_s": sum(float(l["seconds"]) for l in legs), "contacts": int(wc["contact_unit_ticks"]),
            "press_unstick": int(drivers.get("press", 0)) + int(drivers.get("unstick", 0)),
            "reverse": int(gears.get("reverse", gears.get("-1", 0))), "cusps": int(final["cusps"]),
            "kturns": int(arms.get("kturns", 0)), "kturn_multi": int(arms.get("kturn_multi", 0)),
            "kturn_none": int(arms.get("kturn_none", 0)), "kturn_aborted": int(arms.get("kturn_aborted", 0)),
            "off": final.get("off", []),
        }
    return runs


KEYS = ["arrived", "leg_s", "contacts", "press_unstick", "reverse", "cusps", "kturns", "kturn_multi", "kturn_none",
        "kturn_aborted"]


def main(args):
    arms = [(a.split("=", 1)[0], read(a.split("=", 1)[1])) for a in args]
    squads = sorted({squad for _, runs in arms for squad, _ in runs})
    for squad in squads:
        seeds = [sorted(seed for s, seed in runs if s == squad) for _, runs in arms]
        common = sorted(set(seeds[0]).intersection(*seeds[1:])) if seeds else []
        if any(set(s) != set(common) for s in seeds):
            print("NOTE %s: arms ran different seeds %s; only the common %s are compared" % (squad, seeds, common))
        print("\n%s — seeds %s" % (squad, " ".join(map(str, common))))
        print("%-10s %9s " % ("arm", "arrived") + " ".join("%13s" % k for k in KEYS[1:]))
        for arm, runs in arms:
            total = defaultdict(float)
            for seed in common:
                for key in KEYS + ["units"]:
                    total[key] += runs[(squad, seed)][key]
            print("%-10s %4d/%-4d " % (arm, total["arrived"], total["units"]) +
                  " ".join("%13s" % (("%.0f" % total[k]) if k == "leg_s" else int(total[k])) for k in KEYS[1:]))
        if len(arms) >= 2:
            (a_name, a), (b_name, b) = arms[0], arms[1]
            worse = [s for s in common if b[(squad, s)]["arrived"] < a[(squad, s)]["arrived"]]
            better = [s for s in common if b[(squad, s)]["arrived"] > a[(squad, s)]["arrived"]]
            print("discordant arrivals (%s vs %s): better on seeds %s, worse on seeds %s" % (b_name, a_name, better, worse))
            for key in ["press_unstick", "reverse", "kturn_none"]:
                row = " ".join("%d:%d>%d" % (s, a[(squad, s)][key], b[(squad, s)][key]) for s in common)
                print("  %-13s per seed %s" % (key, row))


if __name__ == "__main__":
    main(sys.argv[1:])
