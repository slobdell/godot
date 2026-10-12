#!/usr/bin/env python3
"""Round 27 (brains B2): the table for `make cell-series` (build/cell-series.jsonl, one SETTLE_PROBE per run).

Per arm and seed: arrived k of n under the every-crew line (all_in_s, median s), hollow runs (the element said arrived,
the line never held), re-seats, swaps, and the worst crew's distance off its slot at the end (median). Exit 1 on a
missing run.
"""
import json
import statistics
import sys
from collections import defaultdict


def main(path: str) -> int:
    rows = [json.loads(line) for line in open(path) if line.strip()]
    cells = defaultdict(list)
    for row in rows:
        cells[(row.get("arm"), row.get("seed"))].append(row)
    missing = sum(1 for r in rows if r.get("missing"))
    for arm in sorted({r.get("arm") for r in rows}):
        total = arrived = 0
        for seed in sorted({r.get("seed") for r in rows}):
            runs = [r for r in cells[(arm, seed)] if not r.get("missing")]
            done = [r["all_in_s"] for r in runs if r.get("all_in_s") is not None]
            offs = [float(r.get("worst_off_m", -1)) for r in runs]
            total += len(cells[(arm, seed)])
            arrived += len(done)
            loose = sum(1 for r in runs if r.get("all_in8_s") is not None)
            print("CELL arm=%s seed=%s arrived %d/%d%s (8 m line %d) hollow %d reseats %d swaps %d worst_off_median %.1f m ticks_failed %s" % (
                arm, seed, len(done), len(cells[(arm, seed)]),
                " (median %.1f s)" % statistics.median(done) if done else "", loose,
                sum(1 for r in runs if r.get("hollow")), sum(int(r.get("reseats", 0)) for r in runs),
                sum(int(r.get("swaps", 0)) for r in runs), statistics.median(offs) if offs else -1,
                [r.get("start_tick") for r in runs if r.get("all_in_s") is None]))
        print("CELL_TOTAL arm=%s arrived %d of %d (every crew on its slot)" % (arm, arrived, total))
    print("CELL missing %d" % missing)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
