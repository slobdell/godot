#!/usr/bin/env python3
"""Round 41 (camera K1): add CameraPlaytest's per-seed camera_trace_<seed>.json files into one table.

usage: camera_report.py DIR [DIR_B]   (two dirs: side by side, e.g. a switch off v on)
"""
import glob
import json
import os
import sys

SOURCES = ["player", "jump", "follow", "order_track", "auto_frame", "yaw_follow", "cap", "frame", "solid", "hull", "shake",
           "all"]


def quantile(values, q):
    if not values:
        return 0.0
    values = sorted(values)
    return values[max(0, min(len(values) - 1, int(-(-q * len(values) // 1)) - 1))]


def load(directory):
    runs = []
    for path in sorted(glob.glob(os.path.join(directory, "camera_trace_*.json"))):
        with open(path) as f:
            runs.append(json.load(f))
    return runs


def table(runs):
    minutes = sum(r["summary"]["seconds"] for r in runs) / 60.0 or 1e-6
    rows = {}
    for source in SOURCES:
        events = [e for r in runs for e in r["events"] if e["source"] == source]
        moved = sum(r["summary"]["by_source"][source]["px_per_min"] * r["summary"]["seconds"] / 60.0 for r in runs)
        snaps = sum(r["summary"]["by_source"][source]["snaps"] for r in runs)
        reversals = sum(r["summary"]["by_source"][source]["reversals"] for r in runs)
        dv = [e["dv_px_s"] for e in events]
        rows[source] = {"events": len(events), "per_min": len(events) / minutes, "dv_p50": quantile(dv, 0.5),
                        "dv_p95": quantile(dv, 0.95), "snaps": snaps, "reversals_per_min": reversals / minutes,
                        "px_per_min": moved / minutes}
    clicks = [c for r in runs for c in r["clicks"]]
    slips = [c["slip_px"] for c in clicks]
    attacks = [c for c in clicks if c["kind"] == "attack"]
    by = {}
    for c in clicks:
        for source, px in c.get("by", {}).items():
            by.setdefault(source, []).append(px)
    slip = {"clicks": len(clicks), "attacks": len(attacks), "hit": sum(1 for c in attacks if c.get("hit")),
            "p50": quantile(slips, 0.5), "p95": quantile(slips, 0.95), "max": max(slips) if slips else 0.0,
            "over_10px": sum(1 for s in slips if s > 10.0),
            "by_source_p95": {s: quantile(v, 0.95) for s, v in sorted(by.items())},
            "by_source_clicks": {s: len(v) for s, v in sorted(by.items())}}
    seconds = minutes * 60.0
    held = sum(r["summary"].get("held_s", 0.0) for r in runs)
    action = sum(r["slip"].get("action_s", 0.0) for r in runs)
    play = {"held_pct": 100.0 * held / seconds, "action_pct": 100.0 * action / seconds,
            "aims_per_min": len(attacks) / minutes}
    return {"minutes": minutes, "seeds": [r["seed"] for r in runs], "rows": rows, "slip": slip, "play": play}


def show(name, t):
    print(f"## {name}: {len(t['seeds'])} seeds {t['seeds']}, {t['minutes']:.1f} min of play\n")
    print("| source | jerk events | per min | dv p50 (px/s) | dv p95 | snaps | reversals/min | px moved/min |")
    print("|---|---|---|---|---|---|---|---|")
    for source, row in t["rows"].items():
        if row["events"] == 0 and row["px_per_min"] < 1.0:
            continue
        print(f"| {source} | {row['events']} | {row['per_min']:.2f} | {row['dv_p50']:.0f} | {row['dv_p95']:.0f} | {row['snaps']} | "
              f"{row['reversals_per_min']:.2f} | {row['px_per_min']:.0f} |")
    s = t["slip"]
    print(f"\nTarget slip (px at 1080 rows, the ground under the cursor over the {0.5} s before a click): clicks {s['clicks']} "
          f"(attacks {s['attacks']}, still on the unit {s['hit']}), p50 {s['p50']:.1f}, p95 {s['p95']:.1f}, max {s['max']:.1f}, "
          f"over 10 px {s['over_10px']}")
    print("Slip by source (p95 px over the clicks it touched / clicks): " +
          ", ".join(f"{k} {v:.1f}/{s['by_source_clicks'][k]}" for k, v in s["by_source_p95"].items()))
    p = t["play"]
    print(f"Play: camera held for his aim {p['held_pct']:.1f} % of play; an aimable enemy on screen {p['action_pct']:.1f} % "
          f"(the action share); attack aims {p['aims_per_min']:.2f} / min")
    print()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    for directory in sys.argv[1:]:
        runs = load(directory)
        if not runs:
            print(f"no camera_trace_*.json in {directory}")
            return 1
        show(directory, table(runs))
    return 0


if __name__ == "__main__":
    sys.exit(main())
