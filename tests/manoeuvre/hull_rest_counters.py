#!/usr/bin/env python3
"""Round 31 (manoeuvre M6, C31.9): the manoeuvre counters per hull-rest arm.

Each run's LAST `MANOEUVRE_TURNS {json}` line (printed by ManoeuvreCensus under --turn-states / --turn-census) carries
`counters` (face_plans, face_slot_kept/refused, the H1 escape arms, ...). Summed over every run of an arm:
HULL_COUNTERS <arm> | runs n | key=value ...  (runs without the line are counted as missing, never as zeros).
Usage: hull_rest_counters.py build/manoeuvre/hull-rest
"""
import json
import os
import sys


def last_counters(path: str):
    found = None
    with open(path, errors="replace") as handle:
        for line in handle:
            if line.startswith("MANOEUVRE_TURNS "):
                found = line[len("MANOEUVRE_TURNS "):]
    if found is None:
        return None
    try:
        return json.loads(found).get("counters")
    except json.JSONDecodeError:
        return None


def add(total: dict, counters: dict, prefix: str = "") -> None:
    for key, value in counters.items():
        if isinstance(value, dict):
            add(total, value, prefix + key + ".")
        elif isinstance(value, (int, float)):
            total[prefix + key] = total.get(prefix + key, 0) + value


def main(root: str) -> int:
    if not os.path.isdir(root):
        print(f"HULL_COUNTERS no directory {root}")
        return 0
    for arm in sorted(os.listdir(root)):
        arm_dir = os.path.join(root, arm)
        if not os.path.isdir(arm_dir):
            continue
        total, runs, missing = {}, 0, 0
        for base, _dirs, files in os.walk(arm_dir):
            if "run.log" not in files:
                continue
            runs += 1
            counters = last_counters(os.path.join(base, "run.log"))
            if counters is None:
                missing += 1
                continue
            add(total, counters)
        pairs = " ".join(f"{k}={v}" for k, v in sorted(total.items()))
        print(f"HULL_COUNTERS {arm} | runs {runs} | missing {missing} | {pairs}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "build/manoeuvre/hull-rest"))
