#!/usr/bin/env python3
"""Round 12: summarise `make squad-transit-series` (build/squad-transit.jsonl).

Pairs the two arms of TRANSIT (the travelling anchor a plain move rides: on = round 12, off = round 10's path, every
crew straight to its final slot) on the SAME seed, arena, direction and squad (the paired-seeds rule, C6). Per cell:
medians of arrival, stop and in-slot times (a run that never reached one inside the cap counts as the cap), the ON
arm's mean station error while travelling (`transit_gap_m`: the lead's "they all split apart" as a number; the OFF arm
has no stations and reads -1), and the discordant pairs on the stop time.

Round 12, S3: `--arm=fallin` pairs the two arms of FALLIN instead (the fall-in rule; both arms ride the anchor), and
both arms then have a station error: `gap` over the whole transit and `gap10` over its first 10 s (the rule's target),
each against the SHAPE's stations. S5: `--arm=shape --off=column` pairs a column (reported as "off") against a wedge
("on") ordered with G.
"""
import json
import statistics
import sys
from collections import defaultdict

CAP_S = 90.0


def val(row, key):
    v = row.get(key)
    return CAP_S if v is None else float(v)


def main(path, arm="transit", off_value="off"):
    runs = defaultdict(dict)
    for line in open(path):
        line = line.strip()
        if not line:
            continue
        row = json.loads(line)
        cell = (row["arena"], row["dir"], row["units"])
        runs[cell].setdefault(row["seed"], {})["on" if row.get(arm, True) not in (False, off_value) else "off"] = row
    print("arms: %s off / on" % arm.upper())
    print("%-9s %-7s %-24s %2s | %-15s | %-15s | %-15s | %-13s | %-13s | %s" % (
        "arena", "dir", "units", "n", "arrived off/on", "stopped off/on", "in_slot off/on", "gap off/on",
        "gap10 off/on", "stopped: off faster / on faster / tie"))
    total = [0, 0, 0]
    for cell in sorted(runs):
        pairs = [p for p in runs[cell].values() if "on" in p and "off" in p]
        if not pairs:
            continue
        med = lambda arm, key: statistics.median(val(p[arm], key) for p in pairs)
        gap = lambda a, key="transit_gap_m": statistics.median(float(p[a].get(key, -1.0)) for p in pairs)
        better = sum(1 for p in pairs if val(p["off"], "stopped_s") < val(p["on"], "stopped_s") - 0.5)
        worse = sum(1 for p in pairs if val(p["off"], "stopped_s") > val(p["on"], "stopped_s") + 0.5)
        ties = len(pairs) - better - worse
        for i, n in enumerate((better, worse, ties)):
            total[i] += n
        print("%-9s %-7s %-24s %2d | %6.1f / %-6.1f | %6.1f / %-6.1f | %6.1f / %-6.1f | %5.1f / %-5.1f | %5.1f / %-5.1f | %d / %d / %d" % (
            cell[0], cell[1], cell[2], len(pairs), med("off", "arrived_s"), med("on", "arrived_s"),
            med("off", "stopped_s"), med("on", "stopped_s"), med("off", "in_slot_s"), med("on", "in_slot_s"),
            gap("off"), gap("on"), gap("off", "transit_gap10_m"), gap("on", "transit_gap10_m"), better, worse, ties))
        for seed in sorted(runs[cell]):
            p = runs[cell][seed]
            if "on" in p and "off" in p and abs(val(p["off"], "stopped_s") - val(p["on"], "stopped_s")) > 0.5:
                print("    discordant seed %s: stopped off %.1f / on %.1f, gap10 off %.1f / on %.1f" % (
                    seed, val(p["off"], "stopped_s"), val(p["on"], "stopped_s"),
                    float(p["off"].get("transit_gap10_m", -1)), float(p["on"].get("transit_gap10_m", -1))))
    print("%s_SERIES discordant (stopped, 0.5 s): off faster %d, on faster %d, tie %d" % ((arm.upper(),) + tuple(total)))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    arms = [a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--arm=")]
    offs = [a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--off=")]
    main(args[0] if args else "build/squad-transit.jsonl", arms[0] if arms else "transit", offs[0] if offs else "off")
