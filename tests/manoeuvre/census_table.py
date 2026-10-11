#!/usr/bin/env python3
"""Pool `MANOEUVRE_TURN` rows (game/ai/manoeuvre_census.gd, `--turn-log`) from census logs.

Usage: census_table.py LOG [LOG ...] [--json OUT]
The workload is the log name's first dash-separated word (terminus / sim / sumps). Per workload x kind: episodes,
legs histogram, share <= 3 legs, worst; per workload x cause: episodes and share <= 3. Excludes `direct` (combat hops)
and `face`/`idle` (post turns) from the kind table and reports them apart: the pass line is about turns on the way.
"""
import collections
import json
import os
import sys

APART = {"direct", "face", "idle"}


def load(paths):
    out = []
    for path in paths:
        workload = os.path.basename(path).split("-")[0].split(".")[0]
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("MANOEUVRE_TURN {"):
                    row = json.loads(line.split(" ", 1)[1])
                    row["workload"] = workload
                    row["log"] = os.path.basename(path)
                    out.append(row)
    return out


def summarise(rows):
    n = len(rows)
    le3 = sum(1 for r in rows if r["legs"] <= 3)
    hist = collections.Counter(r["legs"] for r in rows)
    return {"episodes": n, "le3": le3, "share_le3": round(le3 / n, 3) if n else None,
            "worst": max((r["legs"] for r in rows), default=0),
            "hist": dict(sorted(hist.items()))}


def main(argv):
    out_json = None
    if "--json" in argv:
        i = argv.index("--json")
        out_json = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    rows = load(argv)
    table = {"by_kind": {}, "by_cause": {}, "apart": {}, "rows": len(rows)}
    print("MANOEUVRE_CENSUS rows=%d logs=%d" % (len(rows), len(argv)))
    groups = collections.defaultdict(list)
    causes = collections.defaultdict(list)
    apart = collections.defaultdict(list)
    for r in rows:
        if r["cause"] in APART:
            apart[(r["workload"], r["cause"])].append(r)
            continue
        groups[(r["workload"], r["kind"])].append(r)
        groups[("ALL", r["kind"])].append(r)
        causes[(r["workload"], r["cause"])].append(r)
    print("%-9s %-9s %8s %6s %6s  %s" % ("workload", "kind", "episodes", "<=3", "worst", "legs histogram"))
    for key in sorted(groups):
        s = summarise(groups[key])
        table["by_kind"]["%s/%s" % key] = s
        print("%-9s %-9s %8d %6s %6d  %s" % (key[0], key[1], s["episodes"], s["share_le3"], s["worst"], s["hist"]))
    print("%-9s %-14s %8s %6s %6s" % ("workload", "cause", "episodes", "<=3", "worst"))
    for key in sorted(causes):
        s = summarise(causes[key])
        table["by_cause"]["%s/%s" % key] = s
        print("%-9s %-14s %8d %6s %6d" % (key[0], key[1], s["episodes"], s["share_le3"], s["worst"]))
    for key in sorted(apart):
        s = summarise(apart[key])
        table["apart"]["%s/%s" % key] = s
        print("apart     %-9s %-9s %8d %6s %6d" % (key[0], key[1], s["episodes"], s["share_le3"], s["worst"]))
    if out_json:
        with open(out_json, "w") as f:
            json.dump(table, f, indent=1)


if __name__ == "__main__":
    main(sys.argv[1:])
