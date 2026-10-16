#!/usr/bin/env python3
"""Round 31 (planner CP-P1, bar line (a)): the judged Terminus series read as the bar is written.

Usage: series_verdict.py base=DIR candidate=DIR [se=1.645]
  (each DIR holds <squad>-<seed>.log from `make nav-terminus-drive`, the two arms on the SAME seeds)

Per squad, PAIRED on seed (candidate - base): arrivals (the sum over legs of hulls that arrived) -- the bar's pass
line is "not down beyond 1.645 se": the mean paired difference >= -1.645 x se (se = sd / sqrt n of the paired
differences; n = seeds), never judged before 6 seeds; wall contact-ticks (`contact_unit_ticks`) REPORTED per run and as
the median per arm, with the paired difference's mean and se (the rigs row's MDE is too wide for a pass line), and the
worst run of each arm named. The seam: the LAST `PLANNER_SEAM_REPORT` line of each candidate log (requests, plans,
driven, aborted, abandoned, rerequested, refused by code, holds n/median/max, queue_waits): a run where the seam never
fired is an equality check, not a sample. One `PLANNER_SERIES <json>` line at the end for the record; refuses (exit 2)
on a missing arm, a seed present in one arm only, or an unfinished run. Reads the drive rows through nav's
drive_table.read (read-only).
"""
import json
import math
import os
import statistics
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "nav"))
from drive_table import read  # noqa: E402


def seam_reports(directory):
    out = {}
    for name in os.listdir(directory):
        if not name.endswith(".log"):
            continue
        last = None
        with open(os.path.join(directory, name), errors="replace") as f:
            for line in f:
                if line.startswith("PLANNER_SEAM_REPORT "):
                    last = json.loads(line[len("PLANNER_SEAM_REPORT "):])
        out[name[:-4]] = last
    return out


def pooled_holds(reports, squad=None):
    """The hold per rig event POOLED over the arm's runs (the orchestrator's reported line: pending ticks per rig event,
    median and max per arm): n, median, max hull-ticks; `squad` keeps the runs named <squad>-<seed>."""
    ticks = []
    for run, rep in reports.items():
        if rep is None or (squad is not None and run.rsplit("-", 1)[0] != squad):
            continue
        ticks.extend(int(t) for t in rep.get("hold_ticks", []))
    if not ticks:
        return {"n": 0, "median": 0, "max": 0}
    return {"n": len(ticks), "median": statistics.median(ticks), "max": max(ticks)}


def paired(base, cand, keys, field):
    diffs = [cand[k][field] - base[k][field] for k in keys]
    n = len(diffs)
    mean = statistics.fmean(diffs) if n else 0.0
    sd = statistics.stdev(diffs) if n > 1 else 0.0
    se = sd / math.sqrt(n) if n else 0.0
    return {"n": n, "mean": round(mean, 3), "sd": round(sd, 3), "se": round(se, 3), "diffs": diffs}


def main(argv):
    arms = {}
    mult = 1.645
    for arg in argv:
        name, _, value = arg.partition("=")
        if name == "se":
            mult = float(value)
        else:
            arms[name] = value
    if "base" not in arms or "candidate" not in arms:
        print(__doc__)
        return 2
    base = read(arms["base"])
    cand = read(arms["candidate"])
    only = set(base) ^ set(cand)
    if only:
        print("REFUSED: seeds in one arm only: %s" % sorted(only))
        return 2
    reports = seam_reports(arms["candidate"])
    base_reports = seam_reports(arms["base"])
    verdict = {"se_mult": mult, "squads": {}, "seam": {}}
    squads = sorted({squad for squad, _ in base})
    for squad in squads:
        keys = sorted(k for k in base if k[0] == squad)
        n = len(keys)
        arr = paired(base, cand, keys, "arrived")
        con = paired(base, cand, keys, "contacts")
        units = sum(base[k]["units"] for k in keys)
        arr_pass = n >= 6 and arr["mean"] >= -mult * arr["se"]
        row = {
            "n": n, "units": units,
            "arrived": {"base": sum(base[k]["arrived"] for k in keys), "candidate": sum(cand[k]["arrived"] for k in keys),
                        "paired": arr, "line": "not down beyond %.3f se" % mult, "pass": arr_pass,
                        "judged": n >= 6},
            "contacts": {"base_median": statistics.median(base[k]["contacts"] for k in keys),
                         "candidate_median": statistics.median(cand[k]["contacts"] for k in keys),
                         "base_per_run": {k[1]: base[k]["contacts"] for k in keys},
                         "candidate_per_run": {k[1]: cand[k]["contacts"] for k in keys},
                         "paired": con,
                         "worst_base": max(keys, key=lambda k: base[k]["contacts"])[1],
                         "worst_candidate": max(keys, key=lambda k: cand[k]["contacts"])[1],
                         "line": "REPORTED (the rigs row's MDE is +74 % at n 13)"},
            "pending_per_event": pooled_holds(reports, squad),
        }
        verdict["squads"][squad] = row
        print("PLANNER_SERIES_SQUAD %s: n %d | arrivals base %d candidate %d of %d, paired mean %+.3f se %.3f -> %s | "
              "contact-ticks median base %s candidate %s, paired mean %+.1f se %.1f, worst base seed %s (%d) candidate seed %s (%d) | "
              "pending per rig event (candidate, pooled) n %d median %s max %s ticks" % (
                  squad, n, row["arrived"]["base"], row["arrived"]["candidate"], units, arr["mean"], arr["se"],
                  "PASS" if arr_pass else ("NOT JUDGED (n < 6)" if n < 6 else "MISS"),
                  row["contacts"]["base_median"], row["contacts"]["candidate_median"], con["mean"], con["se"],
                  row["contacts"]["worst_base"], base[(squad, row["contacts"]["worst_base"])]["contacts"],
                  row["contacts"]["worst_candidate"], cand[(squad, row["contacts"]["worst_candidate"])]["contacts"],
                  row["pending_per_event"]["n"], row["pending_per_event"]["median"], row["pending_per_event"]["max"]))
    # The seam, per candidate run and summed.
    totals = {"requests": 0, "plans": 0, "driven": 0, "aborted": 0, "abandoned": 0, "rerequested": 0, "queue_waits": 0,
              "pending_ticks": 0, "refused": {}, "runs_fired": 0, "runs_silent": 0, "holds_max": 0, "holds_medians": []}
    for run in sorted(reports):
        rep = reports[run]
        if rep is None:
            totals["runs_silent"] += 1
            print("PLANNER_SERIES_SEAM %s: never fired (an equality check, not a sample)" % run)
            continue
        totals["runs_fired"] += 1
        for key in ("requests", "plans", "driven", "aborted", "abandoned", "rerequested", "queue_waits", "pending_ticks"):
            totals[key] += int(rep.get(key, 0))
        for code, count in rep.get("refused", {}).items():
            totals["refused"][code] = totals["refused"].get(code, 0) + int(count)
        holds = rep.get("holds", {})
        totals["holds_max"] = max(totals["holds_max"], int(holds.get("max", 0)))
        if int(holds.get("n", 0)) > 0:
            totals["holds_medians"].append(int(holds["median"]))
        print("PLANNER_SERIES_SEAM %s: %s" % (run, json.dumps(rep, sort_keys=True)))
    base_fired = [run for run, rep in base_reports.items() if rep is not None and int(rep.get("requests", 0)) > 0]
    if base_fired:
        print("REFUSED: the BASE arm's seam fired in %s (the switch reached the base)" % sorted(base_fired))
        return 2
    totals["holds_median_of_medians"] = statistics.median(totals["holds_medians"]) if totals["holds_medians"] else 0
    del totals["holds_medians"]
    totals["pending_per_event"] = pooled_holds(reports)   # every event in the arm, pooled: n / median / max hull-ticks
    verdict["seam"] = totals
    print("PLANNER_SERIES_SEAM_TOTAL %s" % json.dumps(totals, sort_keys=True))
    print("PLANNER_SERIES %s" % json.dumps(verdict, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
