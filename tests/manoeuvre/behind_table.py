#!/usr/bin/env python3
"""Pool `MANOEUVRE_BEHIND` rows (tests/manoeuvre/goal_behind_probe.gd) per hull x case x facing.

Usage: behind_table.py LOG [LOG ...] [--json OUT]
Prints one row per cell: n, median/worst seconds to done and to settled, legs (median / max / share <= 2), pivot
seconds, heading change, metres, reverse metres, end distance and end heading error (median). --json writes the cells.
"""
import json
import statistics
import sys


def rows(paths):
    out = []
    for path in paths:
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("MANOEUVRE_BEHIND {"):
                    out.append(json.loads(line.split(" ", 1)[1]))
    return out


def med(xs):
    return statistics.median(xs) if xs else float("nan")


def cells(data):
    by = {}
    for r in data:
        by.setdefault((r["hull"], r["case"], r["facing"]), []).append(r)
    out = []
    for (hull, case, facing), rs in sorted(by.items()):
        done = [r["done_s"] for r in rs if r["done_s"] >= 0]
        settled = [r["settled_s"] for r in rs if r["settled_s"] >= 0]
        legs = [r["legs"] for r in rs]
        out.append({
            "hull": hull, "case": case, "facing": facing, "n": len(rs),
            "never_done": len(rs) - len(done),
            "done_med": round(med(done), 2), "done_max": round(max(done), 2) if done else -1,
            "settled_med": round(med(settled), 2), "settled_max": round(max(settled), 2) if settled else -1,
            "legs_med": med(legs), "legs_max": max(legs), "legs_le2": round(sum(1 for x in legs if x <= 2) / len(legs), 2),
            "pivot_med": round(med([r["pivot_s"] for r in rs]), 2),
            "heading_med": round(med([r["heading_deg"] for r in rs])),
            "metres_med": round(med([r["metres"] for r in rs]), 1),
            "reverse_med": round(med([r["reverse_m"] for r in rs]), 1),
            "end_m_med": round(med([r["end_m"] for r in rs]), 1),
            "end_err_med": round(med([r["end_heading_err"] for r in rs])),
        })
    return out


def main(argv):
    out_json = None
    if "--json" in argv:
        i = argv.index("--json")
        out_json = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    data = rows(argv)
    table = cells(data)
    head = ("hull", "case", "facing", "n", "never_done", "done_med", "done_max", "settled_med", "settled_max", "legs_med",
            "legs_max", "legs_le2", "pivot_med", "heading_med", "metres_med", "reverse_med", "end_m_med", "end_err_med")
    print("MANOEUVRE_BEHIND_TABLE rows=%d" % len(data))
    print(" ".join("%-9s" % h[:9] for h in head))
    for c in table:
        print(" ".join("%-9s" % str(c[h])[:9] for h in head))
    if out_json:
        with open(out_json, "w") as f:
            json.dump(table, f, indent=1)


if __name__ == "__main__":
    main(sys.argv[1:])
