#!/usr/bin/env python3
"""Spotter S1: the feature table. Reads tests/spotter/feature_probe.gd's fight files and derives, per crew-second, the signals a
player would read as "that looks dumb". Stdlib only (it runs on builder3's system python and on the laptop).

    python3 tools/spotter/features.py build/spotter/fights            # writes features.csv beside the fights, prints a summary

Every SIGNAL is >= 0, 0 meaning "nothing odd here", and carries the words used to explain it (REASON). Run lengths (seconds the
condition has held, this second included) are what make a moment: one second against a wall is driving; twelve is stuck.
"""
import csv
import glob
import gzip
import json
import math
import os
import sys

# The probe's raw keys (tests/spotter/feature_probe.gd) that the table keeps as they are.
FIELDS = ["fight", "arena", "seed", "s", "tick", "crew", "team", "unit", "loco", "squad", "x", "z", "yaw", "speed", "vmax", "hp",
          "order", "move", "weap", "phase", "blocked", "touch", "touch_cause", "touch_what", "intent", "choice", "shots",
          "range", "arc", "seen", "near_enemy", "near_any", "since_fire", "lane_blocker", "to_go", "gain_2", "gain_5", "route_off",
          "squad_d", "squad_n", "hit_dmg", "fire_off", "fire_far"]

# Derived signals, each with what a player would see (the moment's readable reason) and its unit.
SIGNALS = {
    "noprog_s": ("no progress toward its goal", "s"),
    "wall_s": ("pressed against a wall or prop", "s"),
    "friend_s": ("blocked by a friendly", "s"),
    "reverse_s": ("reversing on a move order", "s"),
    "wrongway_s": ("driving away from its route", "s"),
    "holdfire_s": ("enemy in sight and in range, not firing", "s"),
    "rearfire_s": ("taking fire from behind", "s"),
    "outranged_s": ("hit from beyond its own range", "s"),
    "idlehit_s": ("sitting still under fire, not shooting back", "s"),
    "spread_m": ("far from its squad", "m"),
    "spin_dps": ("turning on the spot", "deg/s"),
}

# Below these a signal is ordinary driving, whatever its rarity: it reads 0 (one second against a wall is a brush, a
# squadmate 12 m away is a formation). A player would not call any of these dumb.
MINIMUM = {"noprog_s": 3, "wall_s": 2, "friend_s": 3, "reverse_s": 3, "wrongway_s": 2, "holdfire_s": 1, "rearfire_s": 2,
           "outranged_s": 3, "idlehit_s": 2, "spread_m": 25.0, "spin_dps": 20.0}

TICK_RATE = 30
FAR_M = 15.0          # NoProgressCensus.FAR_M: a crew this close to its goal is arriving, not stuck
PROGRESS_M = 1.0      # gain over 5 s under this = no progress
SLOW_MPS = 0.6        # under this a crew counts as still
WRONGWAY_DEG = 100.0  # nose this far off the route's next point while driving forward
REAR_DEG = 120.0      # fire this far off the nose comes from behind
HOLD_TICKS = 3 * TICK_RATE  # no shot for this long with a target in range


def load_fight(path):
    header, rows = {}, []
    with (gzip.open(path, "rt") if path.endswith(".gz") else open(path)) as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("t") == "fight":
                header = row
            elif row.get("t") == "crew":
                rows.append(row)
    return header, rows


def _f(row, key, default=0.0):
    value = row.get(key)
    return default if value is None or value == "" else float(value)


def _turn(a, b):
    d = (b - a + 180.0) % 360.0 - 180.0
    return abs(d)


def derive(header, rows, fight=""):
    """Rows of one fight -> the table's rows (raw FIELDS + SIGNALS), in crew then time order."""
    by_crew = {}
    for row in rows:
        by_crew.setdefault(row["crew"], []).append(row)
    out = []
    for crew, seq in by_crew.items():
        seq.sort(key=lambda r: r["tick"])
        runs = {k: 0.0 for k in SIGNALS if k.endswith("_s")}
        prev = None
        for row in seq:
            moving_order = row.get("move") == "move_to"
            speed = _f(row, "speed")
            still = abs(speed) < SLOW_MPS
            conds = {
                "noprog_s": moving_order and _f(row, "to_go") > FAR_M and "gain_5" in row and _f(row, "gain_5") < PROGRESS_M,
                "wall_s": bool(row.get("touch")) and row.get("touch_cause", "") != "" and moving_order and still,
                "friend_s": row.get("phase") in ("blocked", "yielding") and row.get("blocked", "") != "",
                "reverse_s": moving_order and speed < -SLOW_MPS,
                "wrongway_s": moving_order and speed > SLOW_MPS and _f(row, "route_off", 0.0) > WRONGWAY_DEG,
                "holdfire_s": (not row.get("arc")) and 0.0 <= _f(row, "near_enemy", -1.0) <= 0.9 * _f(row, "range")
                and int(row.get("shots", 0)) == 0 and _f(row, "since_fire") >= HOLD_TICKS,
                "rearfire_s": _f(row, "hit_dmg") > 0.0 and _f(row, "fire_off", 0.0) > REAR_DEG,
                "outranged_s": _f(row, "hit_dmg") > 0.0 and _f(row, "fire_far") > 1.05 * _f(row, "range"),
                "idlehit_s": _f(row, "hit_dmg") > 0.0 and still and not moving_order and int(row.get("shots", 0)) == 0,
            }
            # A gap (the crew skipped a sample) breaks every run.
            gap = prev is not None and row["tick"] - prev["tick"] > 1.5 * TICK_RATE
            table = {k: row.get(k, "") for k in FIELDS if k not in ("fight", "arena", "seed")}
            table.update({"fight": fight, "arena": header.get("arena", ""), "seed": header.get("seed", "")})
            for key, held in conds.items():
                runs[key] = (0.0 if gap else runs[key]) + 1.0 if held else 0.0
                table[key] = runs[key]
            table["spread_m"] = _f(row, "squad_d") if int(row.get("squad_n", 0) or 0) > 1 else 0.0
            table["spin_dps"] = 0.0
            if prev is not None and not gap and abs(speed) < SLOW_MPS:
                dt = (row["tick"] - prev["tick"]) / TICK_RATE
                table["spin_dps"] = round(_turn(_f(prev, "yaw"), _f(row, "yaw")) / max(dt, 1e-6), 1)
            for key, floor in MINIMUM.items():
                if float(table[key]) < floor:
                    table[key] = 0.0  # the run itself keeps counting in `runs`
            out.append(table)
            prev = row
    return out


def load_dir(fight_dir):
    table = []
    paths = glob.glob(os.path.join(fight_dir, "*.jsonl")) + glob.glob(os.path.join(fight_dir, "*.jsonl.gz"))
    for path in sorted(paths):
        header, rows = load_fight(path)
        if not header:
            continue
        name = os.path.basename(path)
        table.extend(derive(header, rows, name[: name.index(".jsonl")]))
    return table


def write_csv(table, path):
    keys = FIELDS + list(SIGNALS)
    with open(path, "w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=keys, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(table)


def main():
    fight_dir = sys.argv[1] if len(sys.argv) > 1 else "build/spotter/fights"
    table = load_dir(fight_dir)
    write_csv(table, os.path.join(fight_dir, "features.csv"))
    fights = len({r["fight"] for r in table})
    print(f"features: {len(table)} crew-seconds from {fights} fights -> {os.path.join(fight_dir, 'features.csv')}")
    for key, (words, unit) in SIGNALS.items():
        hot = sum(1 for r in table if r[key] > 0)
        print(f"  {key:12s} {hot:7d} crew-seconds > 0  ({words})")


if __name__ == "__main__":
    main()
