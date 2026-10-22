#!/usr/bin/env python3
"""Round 37 (rules): the guard lines' shots by side and motion, from rules-guard-motion's rows.jsonl (GUARD_MOTION lines).

    python3 tests/rules/guard_motion_table.py rows.jsonl

Per line (blob / turtle) and side (the ordered guard / the CPU tactics): direct-fire shots still (< 0.15 of top speed, a
crawl), slow, fast, and the share fired faster than a crawl, pooled and with the per-seed se of that share.
"""
import json
import math
import sys


def main(path):
    rows = [json.loads(line) for line in open(path) if line.strip()]
    print("fights %d (%s), not listening %d" % (len(rows), sorted({r["rules"] for r in rows}),
                                                sum(1 for r in rows if not r["listening"])))
    for kind in sorted({r["guard"] for r in rows}):
        line = [r for r in rows if r["guard"] == kind]
        print("%s line: %d fights" % (kind.upper(), len(line)))
        for who in ("guard", "tactics"):
            tot = {k: sum(r["shots"][who][k] for r in line) for k in ("still", "slow", "fast")}
            n = sum(tot.values())
            by_seed = {}
            for r in line:
                s = by_seed.setdefault(r["seed"], [0, 0])
                s[0] += r["shots"][who]["slow"] + r["shots"][who]["fast"]
                s[1] += sum(r["shots"][who].values())
            shares = [m / t for m, t in by_seed.values() if t]
            se = None
            if len(shares) > 1:
                mean = sum(shares) / len(shares)
                se = math.sqrt(sum((x - mean) ** 2 for x in shares) / (len(shares) - 1)) / math.sqrt(len(shares))
            print("  %-8s shots %6d  still %5.1f %%  slow %5.1f %%  fast %5.1f %%  | moving (>= crawl) %5.1f %% (se %s)  arc %d" % (
                "blob" if who == "guard" and kind == "blob" else ("turtle" if who == "guard" else "CPU"), n,
                100 * tot["still"] / n if n else 0, 100 * tot["slow"] / n if n else 0, 100 * tot["fast"] / n if n else 0,
                100 * (tot["slow"] + tot["fast"]) / n if n else 0, "n/a" if se is None else "%.1f" % (100 * se),
                sum(r["arc"][who] for r in line)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
