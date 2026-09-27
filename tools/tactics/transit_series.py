#!/usr/bin/env python3
"""Round 12: summarise `make squad-transit-series` (build/squad-transit.jsonl).

Pairs the two arms of TRANSIT (the travelling anchor a plain move rides: on = round 12, off = round 10's path, every
crew straight to its final slot) on the SAME seed, arena, direction and squad (the paired-seeds rule, C6). Per cell:
medians of arrival, stop and in-slot times (a run that never reached one inside the cap counts as the cap), the ON
arm's mean station error while travelling (`transit_gap_m`: the lead's "they all split apart" as a number; the OFF arm
has no stations and reads -1), and the discordant pairs on the stop time.
"""
import json
import statistics
import sys
from collections import defaultdict

CAP_S = 90.0


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
        cell = (row["arena"], row["dir"], row["units"])
        runs[cell].setdefault(row["seed"], {})["on" if row.get("transit", True) else "off"] = row
    print("%-9s %-7s %-24s %2s | %-15s | %-15s | %-15s | %-7s | %s" % (
        "arena", "dir", "units", "n", "arrived off/on", "stopped off/on", "in_slot off/on", "gap on",
        "stopped: off faster / on faster / tie"))
    total = [0, 0, 0]
    for cell in sorted(runs):
        pairs = [p for p in runs[cell].values() if "on" in p and "off" in p]
        if not pairs:
            continue
        med = lambda arm, key: statistics.median(val(p[arm], key) for p in pairs)
        gap = statistics.median(float(p["on"].get("transit_gap_m", -1.0)) for p in pairs)
        better = sum(1 for p in pairs if val(p["off"], "stopped_s") < val(p["on"], "stopped_s") - 0.5)
        worse = sum(1 for p in pairs if val(p["off"], "stopped_s") > val(p["on"], "stopped_s") + 0.5)
        ties = len(pairs) - better - worse
        for i, n in enumerate((better, worse, ties)):
            total[i] += n
        print("%-9s %-7s %-24s %2d | %6.1f / %-6.1f | %6.1f / %-6.1f | %6.1f / %-6.1f | %5.1f m | %d / %d / %d" % (
            cell[0], cell[1], cell[2], len(pairs), med("off", "arrived_s"), med("on", "arrived_s"),
            med("off", "stopped_s"), med("on", "stopped_s"), med("off", "in_slot_s"), med("on", "in_slot_s"), gap,
            better, worse, ties))
    print("TRANSIT_SERIES discordant (stopped, 0.5 s): off faster %d, on faster %d, tie %d" % tuple(total))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "build/squad-transit.jsonl")
