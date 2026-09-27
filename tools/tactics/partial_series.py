#!/usr/bin/env python3
"""Round 12, S4: summarise `make squad-partial-series` (build/squad-partial.jsonl): per arena and case, the path the
order took, the card's readout, and medians of arrival, stop and the spread while moving (mean distance from the moving
crews' own centroid), with the per-seed rows under them."""
import json
import statistics
import sys
from collections import defaultdict


def main(path):
    cells = defaultdict(list)
    for line in open(path):
        if line.strip():
            row = json.loads(line)
            cells[(row["arena"], row["case"])].append(row)
    for (arena, case), rows in sorted(cells.items()):
        med = lambda k: statistics.median(float(r[k]) if r.get(k) is not None else 60.0 for r in rows)
        print("%-9s %-8s n=%d path=%s shape=%s card=%r | arrived %.1f s, stopped %.1f s, spread %.1f m (max %.1f)" % (
            arena, case, len(rows), rows[0]["path"], rows[0].get("group_formation") or rows[0]["formation"]["shape"],
            rows[0]["readout"] or rows[0]["formation"]["label"], med("arrived_s"), med("stopped_s"), med("spread_m"),
            med("spread_max_m")))
        for r in sorted(rows, key=lambda r: r["seed"]):
            print("    seed %d: arrived %s stopped %s spread %.1f left_squad %d" % (
                r["seed"], r["arrived_s"], r["stopped_s"], r["spread_m"], r["left_squad"]))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "build/squad-partial.jsonl")
