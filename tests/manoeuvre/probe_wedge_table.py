#!/usr/bin/env python3
"""Round 39 (manoeuvre, M1's G5 fail): `make manoeuvre-probe-wedge` logs side by side per arm. Per run: each squad's arrival
(ORDERS_PROBE_SQUAD), and for every never-in squad its crews' still ticks by partner class (probe_wedge.gd: state/way/seat) and
top partner (crew, squad). Then the classes summed over the never-in squads' crews, per arm. Round 40 (M1 v2): each run's
PROBE_CHAIN (chained seat drift, Bar M1's D line, and the rule's counters), and per arm: never-in runs, chained out_m summed.

    python3 tests/manoeuvre/probe_wedge_table.py DIR
"""
import collections
import glob
import json
import os
import sys


def main(folder):
    total = collections.defaultdict(collections.Counter)
    arms = collections.defaultdict(lambda: {"runs": 0, "never_in": 0, "chained_n": 0, "chained_out_m": 0.0, "last_in": []})
    for path in sorted(glob.glob(os.path.join(folder, "*.log"))):
        squads, wedge, chain = {}, [], {}
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("ORDERS_PROBE_SQUAD "):
                    r = json.loads(line[19:])
                    squads[r["squad"]] = r
                elif line.startswith("PROBE_WEDGE "):
                    wedge.append(json.loads(line[12:]))
                elif line.startswith("PROBE_CHAIN "):
                    chain = json.loads(line[12:])
        arm = os.path.basename(path)[:-4]
        print("== %s: %s" % (arm, " ".join("sq%d %.1f" % (k, squads[k]["arrived_s"]) for k in sorted(squads))))
        out = [k for k in squads if squads[k]["arrived_s"] < 0]
        a = arms[arm.split("-")[3]]
        a["runs"] += 1
        a["never_in"] += 1 if out else 0
        a["chained_n"] += chain.get("chained_n", 0)
        a["chained_out_m"] += chain.get("chained_out_m", 0.0)
        a["last_in"].append(-1.0 if out else max([squads[k]["arrived_s"] for k in squads] or [0.0]))
        if chain:
            print("   chain: chained n %s out %.1f m | parked n %s out %.1f m | in_play %s refusals %s releases %s holds_refused %s"
                  " side %s | native_yield %s" % (chain["chained_n"], chain["chained_out_m"], chain["parked_n"], chain["parked_out_m"],
                  chain["chain_in_play"], chain["chain_refusals"], chain["chain_releases"], chain["chain_holds_refused"],
                  chain["chain_side_spots"], chain["native_yield"]))
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


    print("\nper arm: runs, never-in runs, chained give-ways n / out_m (summed), each run's last arrival (-1 = never in)")
    for arm, a in sorted(arms.items()):
        print("  %-12s runs %2d never-in %2d chained n %4d out %7.1f m  last-in %s" % (
            arm, a["runs"], a["never_in"], a["chained_n"], a["chained_out_m"], " ".join("%.1f" % x for x in a["last_in"])))


if __name__ == "__main__":
    main(sys.argv[1])
