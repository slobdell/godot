#!/usr/bin/env python3
"""Round 27 (orders O3): the `make hull-rest-probe` table.

Reads <dir>/<arm>/<faction>/<task>-<seed>/screen.json (ScreenPlaytest's faced_* rows with per-crew `each`) and prints,
per task and hull class (locomotion/mount), for each arm (drawn, clicked): crews n, the median / 90th percentile / worst
hull error from the drawn heading, the share within 15 deg and the share 100 deg or more (the tail), and a two-sided
permutation p for drawn v clicked medians (same seeds, same factions). Report only: exits 0 whenever it read something.
"""
import json
import pathlib
import random
import statistics
import sys


def pct(values, q):
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(q * (len(ordered) - 1) + 0.5))]


def perm_p(a, b, rounds=4000):
    if not a or not b:
        return float("nan")
    seen = abs(statistics.median(a) - statistics.median(b))
    pool = a + b
    rng = random.Random(27)
    hits = 0
    for _ in range(rounds):
        rng.shuffle(pool)
        if abs(statistics.median(pool[:len(a)]) - statistics.median(pool[len(a):])) >= seen - 1e-9:
            hits += 1
    return (hits + 1) / (rounds + 1)


def main(root: str) -> int:
    crews = {}  # (task, class) -> arm -> [errors]
    runs = {}
    for path in sorted(pathlib.Path(root).glob("*/*/*/screen.json")):
        arm = path.parts[-4]
        for row in json.loads(path.read_text()):
            if "squads" not in row:
                continue
            runs[arm] = runs.get(arm, 0) + 1
            for squad in row["squads"]:
                for crew in squad.get("each", []):
                    for key in ((row["scenario"], crew["class"]), (row["scenario"], "ALL")):
                        crews.setdefault(key, {}).setdefault(arm, []).append(crew["hull_error_deg"])
    if not crews:
        print(f"HULL_TABLE no rows under {root}")
        return 1
    print(f"HULL_TABLE runs {runs}")
    print("HULL_TABLE task | class | arm | n | median | p90 | worst | <=15 deg | >=100 deg | p(drawn v clicked medians)")
    for (task, klass) in sorted(crews):
        arms = crews[(task, klass)]
        p = perm_p(arms.get("drawn", []), arms.get("clicked", []))
        for arm in ("drawn", "clicked"):
            v = arms.get(arm, [])
            if not v:
                continue
            within = sum(1 for e in v if e <= 15.0) / len(v)
            tail = sum(1 for e in v if e >= 100.0) / len(v)
            print(f"HULL_TABLE {task} | {klass} | {arm} | {len(v)} | {statistics.median(v):.1f} | {pct(v, 0.9):.1f} | "
                  f"{max(v):.1f} | {within:.0%} | {tail:.0%} | {'' if arm == 'clicked' else f'{p:.3f}'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "build/hull-rest"))
