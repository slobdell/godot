#!/usr/bin/env python3
"""Round 39 (manoeuvre, M1's G5 fail): `make manoeuvre-probe-wedge` logs side by side per arm. Per run: each squad's arrival
(ORDERS_PROBE_SQUAD), and for every never-in squad its crews' still ticks by partner class (probe_wedge.gd: state/way/seat) and
top partner (crew, squad). Then the classes summed over the never-in squads' crews, per arm.

    python3 tests/manoeuvre/probe_wedge_table.py DIR
"""
import collections
import glob
import json
import os
import sys


def main(folder):
    total = collections.defaultdict(collections.Counter)
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        squads, wedge = {}, []
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("ORDERS_PROBE_SQUAD "):
                    r = json.loads(line[19:])
                    squads[r["squad"]] = r
                elif line.startswith("PROBE_WEDGE "):
                    wedge.append(json.loads(line[12:]))
        arm = os.path.basename(path)[:-4]
        print("== %s: %s" % (arm, " ".join("sq%d %.1f" % (k, squads[k]["arrived_s"]) for k in sorted(squads))))
        out = [k for k in squads if squads[k]["arrived_s"] < 0]
        refusals = wedge[0] if wedge else {}
        print("   run counters: chain_refusals %s parked_refusals %s yields_started %s" % (
            refusals.get("chain_refusals"), refusals.get("parked_refusals"), refusals.get("yields_started")))
        for w in sorted(wedge, key=lambda w: (w["squad"], w["crew"])):
            if w["squad"] not in out:
                continue
            top = sorted(w["partners"].items(), key=lambda kv: -kv[1])[:3]
            print("   sq%d %-22s still %5.1f s  partner %-22s (sq%d, %.1f s)  %s" % (
                w["squad"], w["crew"], w["still_ticks"] / 30.0, w["partner_top"], w["partner_top_squad"],
                w["partner_top_ticks"] / 30.0, ", ".join("%s %.1f s" % (k, v / 30.0) for k, v in top)))
            total[arm.split("-")[3]].update(w["partners"])
    for arm, counts in sorted(total.items()):
        s = sum(counts.values()) or 1
        print("\nnever-in squads' still ticks by partner class, arm %s (%.0f s):" % (arm, s / 30.0))
        for k, v in counts.most_common():
            print("  %-30s %6.1f s  %5.1f %%" % (k, v / 30.0, 100.0 * v / s))


if __name__ == "__main__":
    main(sys.argv[1])
