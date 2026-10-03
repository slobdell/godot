#!/usr/bin/env python3
"""Read a game's frame-time trace (round 16, play P2): `build/recordings/<stamp>-<arena>.perf`, one JSON line a second,
written beside the match recording by game/theme/fx/bench/perf_trace.gd.

    python3 tools/perf_trace_report.py build/recordings/2026-10-02T18-59-00-sumps.perf   # or no argument: the newest
    python3 tools/perf_trace_report.py FILE --every 1                                    # every second, not every 5

Prints the seconds (every `--every`th, plus every second over 100 ms or in slow motion), then the whole match and the
battle only: frame avg/p95/max (wall clock), the share over the locked-30 line, the battle's speed, the tick, game+UI,
GPU, and what the trace itself cost."""
import argparse
import glob
import json
import os
import statistics
import sys

COLS = [("t", "t s", "%6.0f"), ("phase", "phase", "%7s"), ("vehicles", "veh", "%4d"), ("avg_ms", "avg", "%6.1f"),
        ("p95_ms", "p95", "%6.1f"), ("max_ms", "max", "%6.1f"), ("over34", "over34", "%6.0f%%"),
        ("game_speed", "speed", "%5.2f"), ("tick_ms", "tick", "%5.1f"), ("ticks_per_frame", "t/f", "%5.2f"),
        ("ui_ms", "ui", "%5.1f"), ("gpu_ms", "gpu", "%5.1f"), ("self_ms", "self", "%6.3f")]


def cell(row, key, fmt):
    value = row.get(key)
    if value is None:
        return "%*s" % (len(fmt % 0) if "d" in fmt or "f" in fmt else 7, "-")
    return fmt % (value * 100 if key == "over34" else value)


def summary(rows):
    frames = sum(r["frames"] for r in rows) or 1
    weighted = lambda k: sum(r[k] * r["frames"] for r in rows) / frames
    return {"t": rows[-1]["t"], "phase": "", "vehicles": round(statistics.mean(r["vehicles"] for r in rows)),
            "avg_ms": weighted("avg_ms"), "p95_ms": statistics.median(r["p95_ms"] for r in rows),
            "max_ms": max(r["max_ms"] for r in rows), "over34": weighted("over34"),
            "game_speed": statistics.mean(r["game_speed"] for r in rows), "tick_ms": weighted("tick_ms"),
            "ticks_per_frame": weighted("ticks_per_frame"), "ui_ms": weighted("ui_ms"),
            "gpu_ms": statistics.median(r["gpu_ms"] for r in rows), "self_ms": weighted("self_ms")}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("path", nargs="?")
    parser.add_argument("--every", type=int, default=5)
    args = parser.parse_args()
    path = args.path or max(glob.glob("build/recordings/*.perf"), key=os.path.getmtime, default=None)
    if path is None:
        print("perf_trace_report: no build/recordings/*.perf yet (play a make skirmish)")
        return 1
    rows = [json.loads(line) for line in open(path) if line.strip()]
    rows = [r for r in rows if r.get("frames")]
    if not rows:
        print("perf_trace_report: %s has no rows" % path)
        return 1
    print(path)
    print("  ".join("%6s" % label for _, label, _ in COLS))
    for i, row in enumerate(rows):
        if i % args.every == 0 or row["max_ms"] > 100 or row["game_speed"] < 0.95:
            print("  ".join(cell(row, k, f) for k, _, f in COLS))
    print()
    battle = [r for r in rows if r.get("phase") == "battle"]
    for label, part in [("whole match", rows), ("battle only", battle)]:
        if part:
            print("%-12s " % label + "  ".join(cell(summary(part), k, f) for k, _, f in COLS[2:]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
