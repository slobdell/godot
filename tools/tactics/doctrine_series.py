#!/usr/bin/env python3
"""Round 15 (squad P1): summarise `make squad-doctrine-series` (build/squad-doctrine.jsonl).

Each line is one GANG_PROBE: the gang pack under one ARM of its table (shipped = encircle off, bait on; encircle;
nobait; both), against one OPPONENT (guns, chasers, standard), on one ARENA, from one SEED. Arms are PAIRED on
(opponent, arena, seed): the same starts and the same fire dice, only the table differing. Per cell and arm:

  pack / enemy     mean survival (0..1 of hull + shield) at the time limit, and at 26 s (round 14's window)
  verdict          how many runs the pack won (enemy wiped), lost (pack wiped), or ran out the clock; the median
                   seconds to a decided verdict
  vs shipped       paired against the shipped arm on the same seed: how many seeds the arm left the enemy LESS
                   alive (b) and MORE alive (c), the exact two-sided sign test p over b + c, and the mean difference
  drills           per drill: runs that ran it, mean seconds in it, mean shots fired and damage dealt/taken in it

A win is attributed to a mechanism only when the drill it names actually ran: an arm whose drill seconds read zero
is the shipped arm under another name, whatever its numbers say.

Usage: doctrine_series.py build/squad-doctrine.jsonl [--json out.json]
"""
import json
import math
import statistics
import sys
from collections import defaultdict

ARMS = ["shipped", "encircle", "nobait", "both"]
ARM_DRILL = {"encircle": ["encircle"], "nobait": ["bait"], "both": ["encircle", "bait"]}


def sign_p(b, c):
    """Exact two-sided sign test: under no effect each discordant seed is a fair coin."""
    n = b + c
    if n == 0:
        return 1.0
    k = min(b, c)
    return min(1.0, 2.0 * sum(math.comb(n, i) for i in range(k + 1)) / 2 ** n)


def load(path):
    rows = []
    with open(path) as handle:
        for line in handle:
            line = line.strip()
            if line.startswith("GANG_PROBE "):
                line = line[len("GANG_PROBE "):]
            if line.startswith("{"):
                rows.append(json.loads(line))
    return rows


def mean(values):
    return round(statistics.fmean(values), 3) if values else None


def summarise(rows):
    by = defaultdict(dict)  # (opponent, arena) -> arm -> seed -> row
    for row in rows:
        by[(row["opponent"], row["arena"])].setdefault(row["arm"], {})[row["seed"]] = row
    cells = []
    for (opponent, arena) in sorted(by):
        arms = by[(opponent, arena)]
        shipped = arms.get("shipped", {})
        cell = {"opponent": opponent, "arena": arena, "arms": {}}
        for arm in ARMS:
            runs = arms.get(arm)
            if not runs:
                continue
            seeds = sorted(runs)
            rs = [runs[s] for s in seeds]
            decided = [r["verdict_s"] for r in rs if r.get("verdict_s") is not None]
            drills = {}
            for r in rs:
                for name, d in r.get("drills", {}).items():
                    agg = drills.setdefault(name, {"runs": 0, "s": [], "shots": [], "dealt": [], "taken": []})
                    if d.get("starts", 0) > 0 or name == "none":
                        agg["runs"] += 1
                    for key in ("s", "shots", "dealt", "taken"):
                        agg[key].append(float(d.get(key, 0) or 0))
            drill_out = {}
            for name, agg in drills.items():
                n = len(rs)
                drill_out[name] = {"runs": agg["runs"], "of": n,
                                   "mean_s": round(sum(agg["s"]) / n, 1), "mean_shots": round(sum(agg["shots"]) / n, 1),
                                   "mean_dealt": round(sum(agg["dealt"]) / n, 1),
                                   "mean_taken": round(sum(agg["taken"]) / n, 1)}
            out = {"n": len(rs), "seeds": seeds,
                   "pack": mean([r["survival"] for r in rs]), "enemy": mean([r["enemy_survival"] for r in rs]),
                   "pack_26s": mean([r["survival_26s"] for r in rs]), "enemy_26s": mean([r["enemy_survival_26s"] for r in rs]),
                   "won": sum(1 for r in rs if r["verdict"] == "pack"),
                   "lost": sum(1 for r in rs if r["verdict"] == "enemy"),
                   "time": sum(1 for r in rs if r["verdict"] == "time"),
                   "verdict_s_median": round(statistics.median(decided), 1) if decided else None,
                   "pack_shots": mean([r["shots"]["pack"] for r in rs]),
                   "drills": drill_out}
            # The arm's own drill must have run for its numbers to be ITS numbers.
            if arm in ("encircle", "both"):
                out["encircle_ran"] = sum(1 for r in rs if r.get("drills", {}).get("encircle", {}).get("starts", 0) > 0)
            if arm in ("shipped", "encircle"):
                out["bait_ran"] = sum(1 for r in rs if r.get("drills", {}).get("bait", {}).get("starts", 0) > 0)
            if arm != "shipped" and shipped:
                paired = [s for s in seeds if s in shipped]
                b = sum(1 for s in paired if runs[s]["enemy_survival"] < shipped[s]["enemy_survival"] - 1e-6)
                c = sum(1 for s in paired if runs[s]["enemy_survival"] > shipped[s]["enemy_survival"] + 1e-6)
                pb = sum(1 for s in paired if runs[s]["survival"] > shipped[s]["survival"] + 1e-6)
                pc = sum(1 for s in paired if runs[s]["survival"] < shipped[s]["survival"] - 1e-6)
                out["vs_shipped"] = {
                    "pairs": len(paired),
                    "enemy_lower": b, "enemy_higher": c, "enemy_p": round(sign_p(b, c), 3),
                    "enemy_diff": mean([runs[s]["enemy_survival"] - shipped[s]["enemy_survival"] for s in paired]),
                    "pack_higher": pb, "pack_lower": pc, "pack_p": round(sign_p(pb, pc), 3),
                    "pack_diff": mean([runs[s]["survival"] - shipped[s]["survival"] for s in paired]),
                    "identical": sum(1 for s in paired if runs[s]["survival"] == shipped[s]["survival"]
                                     and runs[s]["enemy_survival"] == shipped[s]["enemy_survival"])}
            cell["arms"][arm] = out
        cells.append(cell)
    return cells


def print_cells(cells):
    for cell in cells:
        print("\n== %s on %s" % (cell["opponent"], cell["arena"]))
        print("  %-9s %3s  %6s %6s  %6s %6s  %8s  %5s  %s" % ("arm", "n", "pack", "enemy", "p@26", "e@26",
                                                               "W/L/T", "t_med", "vs shipped (enemy lower/higher p; pack higher/lower p)"))
        for arm, a in cell["arms"].items():
            vs = a.get("vs_shipped")
            vs_text = ""
            if vs:
                vs_text = "e %d/%d p=%.3f d=%+.3f; p %d/%d p=%.3f d=%+.3f; same %d" % (
                    vs["enemy_lower"], vs["enemy_higher"], vs["enemy_p"], vs["enemy_diff"] or 0,
                    vs["pack_higher"], vs["pack_lower"], vs["pack_p"], vs["pack_diff"] or 0, vs["identical"])
            print("  %-9s %3d  %6.3f %6.3f  %6.3f %6.3f  %2d/%2d/%2d  %5s  %s" % (
                arm, a["n"], a["pack"], a["enemy"], a["pack_26s"], a["enemy_26s"], a["won"], a["lost"], a["time"],
                a["verdict_s_median"], vs_text))
            drills = ", ".join("%s %d/%d %.1fs dealt %.0f" % (k, v["runs"], v["of"], v["mean_s"], v["mean_dealt"])
                               for k, v in sorted(a["drills"].items()) if k != "none")
            print("  %9s drills: %s" % ("", drills or "-"))


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    rows = load(argv[1])
    if not rows:
        print("doctrine_series: no GANG_PROBE rows in %s" % argv[1])
        return 1
    cells = summarise(rows)
    print("doctrine_series: %d runs" % len(rows))
    print_cells(cells)
    if "--json" in argv:
        with open(argv[argv.index("--json") + 1], "w") as handle:
            json.dump({"runs": len(rows), "cells": cells}, handle, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
