#!/usr/bin/env python3
"""Round 34 (planner, orders' O5): the orders probe's rows as one table a case (map, squads, route), the arms side by
side: per arm the worst and median anchor offset from the click, squads that reached a deck / the far bank, all-in time
(the last squad's arrival; never = '-'), the closest any squad stood to another squad's hull at arrival, and the worst
shuffle after arrival. Round 35 (orders D2): a second block a case, the deploy step's columns: the last squad's
deploy (or arrival, step off), the worst place move and twitch after it, the closest two squads' hulls and the farthest
crew from the click at the window's end. Usage: orders_probe_table.py rows.jsonl"""
import json
import statistics
import sys


def main(path):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    cases = {}
    for r in rows:
        cases.setdefault((r["map"], r["squads"], r["route"]), {}).setdefault(r.get("arm") or "?", []).append(r)
    print("case                      arm       | offset worst/med m | deck far | all-in s | closest foreign m | shuffle worst m | drive/plan worst | toward min m")
    for case in sorted(cases):
        for arm, squads in sorted(cases[case].items()):
            offs = [r["anchor_offset_m"] for r in squads]
            arrived = [r["arrived_s"] for r in squads]
            all_in = "-" if min(arrived) < 0 else "%.1f" % max(arrived)
            foreign = [r["foreign_m"] for r in squads if r["foreign_m"] >= 0]
            ratio = max((r["driven_m"] / r["plan_drive_m"]) if r["plan_drive_m"] > 0 else 0 for r in squads)
            print("%-25s %-9s | %6.1f / %6.1f   | %4d %3d | %8s | %17s | %15.1f | %.2f" % (
                "%s %d %s" % case, arm, max(offs), statistics.median(offs), sum(r["deck"] for r in squads),
                sum(r.get("crossed", False) for r in squads), all_in, "%.1f" % min(foreign) if foreign else "-",
                max(r["shuffle_m"] for r in squads), ratio) + " | %.1f" % min(r.get("toward_m", 0.0) for r in squads))
    print()
    print("case                      arm       | deploy last s | place worst m | twitch worst m | end foreign min m | end far max m")
    for case in sorted(cases):
        for arm, squads in sorted(cases[case].items()):
            if "place_m" not in squads[0]:
                continue
            deploys = [r["deploy_s"] for r in squads]
            last = "-" if min(deploys) < 0 else "%.1f" % max(deploys)
            twitch = [r["twitch_m"] for r in squads]
            foreign = [r["end_foreign_m"] for r in squads if r["end_foreign_m"] >= 0]
            print("%-25s %-9s | %13s | %13.1f | %14s | %17s | %13.1f" % (
                "%s %d %s" % case, arm, last, max(r["place_m"] for r in squads),
                "-" if min(twitch) < 0 else "%.1f" % max(twitch), "%.1f" % min(foreign) if foreign else "-",
                max(r["end_far_m"] for r in squads)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
