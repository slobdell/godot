#!/usr/bin/env python3
"""Round 30 (brains B6): make sbf-series' table: per unit and arm, crews in (within 8 m of the slot and still), the
median time in, and the hull's error from the drawn heading AT that moment (each crew read only once it is in), plus
the crews never in with where they ended. Usage: sbf_table.py build/sbf-series.jsonl"""
import json
import statistics
import sys


def main(path):
    rows = [json.loads(l) for l in open(path) if l.strip()]
    units = sorted({r["unit"] for r in rows})
    for unit in units:
        for arm in ("drawn", "none"):
            rs = [r for r in rows if r["unit"] == unit and r["facing"] == arm and not r.get("missing")]
            if not rs:
                continue
            ins = [t for r in rs for t in r["in_s"].values()]
            errs = [e for r in rs for e in r["err_in_deg"].values()]
            crews = sum(r["crews"] for r in rs)
            never = [(r["seed"], n, r["end"][n]["off_m"], r["end"][n]["err_deg"]) for r in rs for n in r["end"] if n not in r["in_s"]]
            print("%-10s %-5s in %2d/%2d  median in %5s s  hull err at in: median %5s deg, >= 45: %d, >= 100: %d  | never in: %s" % (
                unit, arm, len(ins), crews, "%.1f" % statistics.median(ins) if ins else "-",
                "%.1f" % statistics.median(errs) if errs else "-", sum(e >= 45 for e in errs), sum(e >= 100 for e in errs), never[:6]))
    missing = [r for r in rows if r.get("missing")]
    if missing:
        print("MISSING", [(r["unit"], r["seed"], r["facing"]) for r in missing])


if __name__ == "__main__":
    main(sys.argv[1])
