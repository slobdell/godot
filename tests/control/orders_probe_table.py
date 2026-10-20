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
    seeds = sorted({r.get("seed", 34) for r in rows})
    if len(seeds) > 1:
        print()
        print(medians(rows, seeds))
    print()
    print(equality(rows))
    return 0


def _cell(squads):
    """One run of a case (one seed, one arm) as its headline numbers."""
    arrived = [r["arrived_s"] for r in squads]
    foreign = [r["end_foreign_m"] for r in squads if r.get("end_foreign_m", -1) >= 0]
    return {"all_in": float("inf") if min(arrived) < 0 else max(arrived),
            "shuffle": max(r["shuffle_m"] for r in squads),
            "twitch": max(r.get("twitch_m", -1) for r in squads),
            "end_far": max(r.get("end_far_m", -1) for r in squads),
            "end_foreign": min(foreign) if foreign else -1,
            "deck": sum(r["deck"] for r in squads), "far": sum(r.get("crossed", False) for r in squads),
            "ratio": max((r["driven_m"] / r["plan_drive_m"]) if r["plan_drive_m"] > 0 else 0 for r in squads)}


def medians(rows, seeds):
    """Round 35 (D5's bar): per case and arm, each seed's run first, then the median over the seeds (never in = inf)."""
    runs = {}
    for r in rows:
        runs.setdefault((r["map"], r["squads"], r["route"], r.get("arm") or "?", r.get("seed", 34)), []).append(r)
    cells = {}
    for (m, n, route, arm, seed), squads in runs.items():
        cells.setdefault((m, n, route), {}).setdefault(arm, []).append(_cell(squads))
    out = ["MEDIANS over seeds %s (n %d a cell; all-in 'inf' = a seed never all in)" % (seeds, len(seeds)),
           "case                      arm         | n | all-in med s | never | shuffle med m | twitch med m | end far med m | end foreign min m | deck far | drive/plan med"]
    for case in sorted(cells):
        for arm, runs_ in sorted(cells[case].items()):
            def med(k):
                return statistics.median(c[k] for c in runs_)
            out.append("%-25s %-11s | %d | %12s | %5d | %13.1f | %12.1f | %13.1f | %17.1f | %4d %3d | %.2f" % (
                "%s %d %s" % case, arm, len(runs_), "%.1f" % med("all_in") if med("all_in") != float("inf") else "inf",
                sum(c["all_in"] == float("inf") for c in runs_), med("shuffle"), med("twitch"), med("end_far"),
                min(c["end_foreign"] for c in runs_), sum(c["deck"] for c in runs_), sum(c["far"] for c in runs_), med("ratio")))
    return "\n".join(out)


def equality(rows):
    """Round 35 (D5's bar): per click case and seed, whether every arm's squad rows are identical (arm field aside)."""
    by = {}
    for r in rows:
        if r["route"] != "click":
            continue
        key = (r["map"], r["squads"], r.get("seed", 34))
        row = {k: v for k, v in r.items() if k not in ("arm",)}
        by.setdefault(key, {}).setdefault(r.get("arm") or "?", []).append(json.dumps(row, sort_keys=True))
    same = differ = 0
    lines = []
    for key, arms in sorted(by.items()):
        if len(arms) < 2:
            continue
        versions = {tuple(sorted(v)) for v in arms.values()}
        if len(versions) == 1:
            same += 1
        else:
            differ += 1
            lines.append("  DIFFER %s %d click seed %d" % key)
    return "\n".join(["EQUALITY click cells: %d identical across arms, %d differ" % (same, differ)] + lines)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
