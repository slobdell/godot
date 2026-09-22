#!/usr/bin/env python3
"""Round 10, squad item 3: summarise `make squad-settle-series` (build/squad-settle.jsonl).

Pairs the two arms of PIN (the leader pinned to the head of a plain move's shape: on = round 9) on the SAME seed,
arena and direction (the paired-seeds rule, C6), and prints per cell the medians of arrival and stop times and the
discordant pairs: how many seeds each arm settled faster on. A run that never stopped inside the cap counts as the cap.
"""
import json
import statistics
import sys
from collections import defaultdict

CAP_S = 45.0


def val(row, key):
    v = row.get(key)
    return CAP_S if v is None else float(v)


def main(path):
    runs = defaultdict(dict)
    for line in open(path):
        line = line.strip()
        if not line:
            continue
        row = json.loads(line)
        cell = (row["arena"], row["dir"])
        runs[cell].setdefault(row["seed"], {})["on" if row["pin"] else "off"] = row
    print("%-9s %-8s %4s | %-19s | %-19s | %s" % ("arena", "dir", "n", "arrived med off/on", "stopped med off/on",
                                                   "stopped: off faster / on faster / tie"))
    total = [0, 0, 0]
    for cell in sorted(runs):
        pairs = [p for p in runs[cell].values() if "on" in p and "off" in p]
        if not pairs:
            continue
        arr_off = statistics.median(val(p["off"], "arrived_s") for p in pairs)
        arr_on = statistics.median(val(p["on"], "arrived_s") for p in pairs)
        st_off = statistics.median(val(p["off"], "stopped_s") for p in pairs)
        st_on = statistics.median(val(p["on"], "stopped_s") for p in pairs)
        better = sum(1 for p in pairs if val(p["off"], "stopped_s") < val(p["on"], "stopped_s") - 0.5)
        worse = sum(1 for p in pairs if val(p["off"], "stopped_s") > val(p["on"], "stopped_s") + 0.5)
        ties = len(pairs) - better - worse
        for i, n in enumerate((better, worse, ties)):
            total[i] += n
        print("%-9s %-8s %4d | %8.1f / %-8.1f | %8.1f / %-8.1f | %d / %d / %d" % (
            cell[0], cell[1], len(pairs), arr_off, arr_on, st_off, st_on, better, worse, ties))
    print("SETTLE_SERIES discordant (stopped, 0.5 s): off faster %d, on faster %d, tie %d" % tuple(total))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "build/squad-settle.jsonl")
