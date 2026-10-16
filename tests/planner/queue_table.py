#!/usr/bin/env python3
"""Round 32 (planner, hand-over (3)): the seam's queue per hull-rest arm.

Each run.log's LAST `PLANNER_SEAM_REPORT {json}` line is that run's cumulative seam report. Summed over every run of an
arm: requests (asks), plans, driven, abandoned (and its share of asks: the bar's line), refused by code, refused early,
queue_waits, pending_ticks, and the hold per event POOLED over the arm's runs (n, median, max hull-ticks). Runs where
the seam never fired count as runs (n) with zero asks; a run with no report at all is counted as missing.
Usage: queue_table.py build/manoeuvre/hull-rest [arm ...]
One `PLANNER_QUEUE <json>` line per arm at the end for the record.
"""
import json
import os
import statistics
import sys


def last_report(path):
    found = None
    with open(path, errors="replace") as handle:
        for line in handle:
            if line.startswith("PLANNER_SEAM_REPORT "):
                found = line[len("PLANNER_SEAM_REPORT "):]
    if found is None:
        return None
    try:
        return json.loads(found)
    except json.JSONDecodeError:
        return None


def arm_table(arm_dir):
    total = {"runs": 0, "silent": 0, "requests": 0, "plans": 0, "driven": 0, "aborted": 0, "abandoned": 0,
             "rerequested": 0, "refused_early": 0, "queue_waits": 0, "pending_ticks": 0, "refused": {}}
    holds = []
    for base, _dirs, files in sorted(os.walk(arm_dir)):
        if "run.log" not in files:
            continue
        total["runs"] += 1
        rep = last_report(os.path.join(base, "run.log"))
        if rep is None:
            total["silent"] += 1   # the seam never ended an event in this run (no line is printed until one ends)
            continue
        for key in ("requests", "plans", "driven", "aborted", "abandoned", "rerequested", "refused_early",
                    "queue_waits", "pending_ticks"):
            total[key] += int(rep.get(key, 0))
        for code, count in rep.get("refused", {}).items():
            total["refused"][code] = total["refused"].get(code, 0) + int(count)
        holds.extend(int(t) for t in rep.get("hold_ticks", []))
    total["abandoned_share"] = round(total["abandoned"] / total["requests"], 4) if total["requests"] else 0.0
    total["holds"] = {"n": len(holds), "median": statistics.median(holds) if holds else 0, "max": max(holds) if holds else 0}
    return total


def main(argv):
    root = argv[1] if len(argv) > 1 else "build/manoeuvre/hull-rest"
    if not os.path.isdir(root):
        print(f"PLANNER_QUEUE no directory {root}")
        return 2
    arms = argv[2:] or sorted(a for a in os.listdir(root) if os.path.isdir(os.path.join(root, a)))
    rows = {}
    for arm in arms:
        t = arm_table(os.path.join(root, arm))
        rows[arm] = t
        print(f"QUEUE {arm:12s} runs {t['runs']:3d} (no line {t['silent']}) | asks {t['requests']:5d} plans {t['plans']:4d} "
              f"driven {t['driven']:4d} abandoned {t['abandoned']:4d} ({100 * t['abandoned_share']:.1f} %) "
              f"refused {t['refused']} early {t['refused_early']} | queue_waits {t['queue_waits']} pending {t['pending_ticks']} "
              f"| hold n {t['holds']['n']} median {t['holds']['median']} max {t['holds']['max']}")
    for arm, t in rows.items():
        print("PLANNER_QUEUE " + json.dumps({"arm": arm, **t}, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
