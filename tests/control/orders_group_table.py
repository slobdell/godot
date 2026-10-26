#!/usr/bin/env python3
"""Round 41 (orders O1): the group-order start census, one row per map x headings x arm (tests/orders_probe_group.gd runs).

  orders_group_table.py build/orders-group/runs.jsonl [crews.jsonl]

Per cell (n runs): all-in seconds (median, worst; a run with a squad never in counts as never), squads never in, crews
nose > 90 deg off their first leg (mean a run), first-leg crossing crew pairs and squads crossing (mean), and the crew-seconds
under way spent blocked by a friend / yielding / slow (mean a run). Measurement only.
"""
import json
import statistics
import sys
from collections import defaultdict


def main(argv):
    runs = [json.loads(line) for line in open(argv[1]) if line.strip()]
    cells = defaultdict(list)
    for r in runs:
        if "group" not in r:
            continue
        cells[(r["map"], r["group"]["headings"], r.get("arm", ""))].append(r)
    head = ("map", "headings", "arm", "n", "all_in_med", "all_in_worst", "never_in", "nose>90", "cross_pairs",
            "sq_crossing", "blocked_s", "yield_s", "slow_s", "turn_worst")
    print("  ".join("%-10s" % h for h in head))
    for key in sorted(cells):
        rs = cells[key]
        alls = [r["all_in_s"] for r in rs if r["all_in_s"] >= 0]
        never = sum(1 for r in rs if r["all_in_s"] < 0)
        g = [r["group"] for r in rs]
        mean = lambda k: statistics.mean(x[k] for x in g)
        row = (key[0], key[1], key[2] or "-", len(rs),
               "%.1f" % statistics.median(alls) if alls else "-", "%.1f" % max(alls) if alls else "-", never,
               "%.1f" % mean("nose_away"), "%.1f" % mean("crossing_pairs"), "%.1f" % mean("squads_crossing"),
               "%.1f" % mean("blocked_s"), "%.1f" % mean("yielding_s"), "%.1f" % mean("slow_s"),
               "%.1f" % max(x["turn_worst_s"] for x in g))
        print("  ".join("%-10s" % v for v in row))
    if len(argv) > 2:
        crews = [json.loads(line) for line in open(argv[2]) if line.strip()]
        away = [c for c in crews if c["nose_off_deg"] > 90]
        near = [c for c in crews if 0 <= c["nose_off_deg"] <= 90]
        def avg(cs, k):
            return statistics.mean(c[k] for c in cs) if cs else 0.0
        print("\ncrews nose > 90 deg: n %d  slow_s %.2f  blocked_s %.2f  yield_s %.2f" % (
            len(away), avg(away, "slow_s"), avg(away, "blocked_s"), avg(away, "yielding_s")))
        print("crews nose <= 90 deg: n %d  slow_s %.2f  blocked_s %.2f  yield_s %.2f" % (
            len(near), avg(near, "slow_s"), avg(near, "blocked_s"), avg(near, "yielding_s")))


if __name__ == "__main__":
    main(sys.argv)
