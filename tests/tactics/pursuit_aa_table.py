#!/usr/bin/env python3
"""Round 31 (brains B5c-v5): the pursuit A/A's table. Per speed: each seed's pass and margins at nudge 0 and the nudged
arm; the pass count, the margins' min / median, and how often the nudge alone flipped the verdict (the knife-edge rate)."""
import json
import math
import statistics
import sys


def main(path):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    missing = [r for r in rows if r.get("missing")]
    rows = [r for r in rows if not r.get("missing")]
    for speed in sorted({r["speed"] for r in rows}):
        arms = {}
        for r in rows:
            if r["speed"] == speed:
                arms.setdefault(r["nudge"], {})[r["seed"]] = r
        print(f"\n== {speed:g} m/s ==")
        nudges = sorted(arms)
        print("seed | " + " | ".join(f"nudge {n:g}: pass  closing_margin_m  reversal_margin_deg  let_go" for n in nudges))
        seeds = sorted(set().union(*[set(a) for a in arms.values()]))
        for s in seeds:
            cells = []
            for n in nudges:
                r = arms[n].get(s)
                cells.append("-" if r is None else f"{'PASS' if r['pass'] else 'FAIL'} {r['closing_margin_m']:+.1f} "
                             f"{r['reversal_margin_deg']:+.0f} {r['let_go_at'] or '-'}")
            print(f"{s} | " + " | ".join(cells))
        for n in nudges:
            a = list(arms[n].values())
            # +inf: no crew was still chasing at both ends of any window (the closing line had nothing to judge).
            cm = [r["closing_margin_m"] for r in a if r["closing_margin_m"] != float("inf")]
            rm = [r["reversal_margin_deg"] for r in a]
            print(f"nudge {n:g}: {sum(r['pass'] for r in a)}/{len(a)} pass; let go {sum(bool(r['let_go_at']) for r in a)}; "
                  f"closing margin (finite {len(cm)}) min {min(cm):+.1f} median "
                  f"{statistics.median(cm):+.1f} sd {statistics.pstdev(cm):.1f} m; reversal margin min {min(rm):+.0f} "
                  f"median {statistics.median(rm):+.0f} sd {statistics.pstdev(rm):.0f} deg")
        if len(nudges) == 2:
            a, b = arms[nudges[0]], arms[nudges[1]]
            both = [s for s in a if s in b]
            flips = [s for s in both if a[s]["pass"] != b[s]["pass"]]
            same = [s for s in both if a[s]["closing_worst_m"] == b[s]["closing_worst_m"]
                    and a[s]["reversal_worst_deg"] == b[s]["reversal_worst_deg"]]
            print(f"paired: {len(flips)}/{len(both)} verdicts flipped by the nudge alone (seeds {flips}); "
                  f"{len(same)}/{len(both)} runs identical in both measures")
    if missing:
        print(f"\nMISSING runs: {len(missing)}: {missing}")
        sys.exit(1)


if __name__ == "__main__":
    main(sys.argv[1])
