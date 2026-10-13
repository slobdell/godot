#!/usr/bin/env python3
"""Round 28 (manoeuvre M1): the `make manoeuvre-hull-rest` table.

Reads <dir>/<arm>/<faction>/<task>-<seed>/screen.json (ScreenPlaytest's faced_* rows, per-crew `each`) for the arms
new_drawn / base_drawn / new_clicked / base_clicked (base = --nav-off=turnhull on the same commit) and prints:
  M1_HULL   per task and hull class, per arm: crews n, median / p90 hull error from the drawn heading, share <= 15 deg,
            share >= 100 deg; and a permutation p for new v base medians (drawn, then clicked).
  M1_SETTLE per task: settled_after_s (every crew still 3 s, measured from the order; -1 = never in 75 s) for the runs
            whose squads hold a wheeled turreted hull, new v base drawn, paired by faction and seed: medians, the median
            paired difference, and how many never settled.
Report only: exits 0 whenever it read something.
"""
import json
import pathlib
import random
import statistics
import sys

ARMS = ("new_drawn", "base_drawn", "new_clicked", "base_clicked")
FOCUS = "wheels/turret"


def pct(values, q):
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(q * (len(ordered) - 1) + 0.5))]


def perm_p(a, b, rounds=4000):
    if not a or not b:
        return float("nan")
    seen = abs(statistics.median(a) - statistics.median(b))
    pool = a + b
    rng = random.Random(28)
    hits = 0
    for _ in range(rounds):
        rng.shuffle(pool)
        if abs(statistics.median(pool[:len(a)]) - statistics.median(pool[len(a):])) >= seen - 1e-9:
            hits += 1
    return (hits + 1) / (rounds + 1)


def main(root: str) -> int:
    crews = {}  # (task, class) -> arm -> [errors]
    settle = {}  # task -> arm -> {(faction, seed): seconds}
    moving = {}  # task -> arm -> crews not still when judged (every class): round 28's guard, base + 5 a task
    runs = {}
    for path in sorted(pathlib.Path(root).glob("*/*/*/screen.json")):
        arm, faction, case = path.parts[-4], path.parts[-3], path.parts[-2]
        seed = case.rsplit("-", 1)[-1]
        for row in json.loads(path.read_text()):
            if "squads" not in row:
                continue
            runs[arm] = runs.get(arm, 0) + 1
            task = row["scenario"]
            has_focus = False
            for squad in row["squads"]:
                for crew in squad.get("each", []):
                    has_focus = has_focus or crew["class"] == FOCUS
                    if not crew.get("still", True):
                        moving.setdefault(task, {}).setdefault(arm, 0)
                        moving[task][arm] += 1
                    for key in ((task, crew["class"]), (task, "ALL")):
                        crews.setdefault(key, {}).setdefault(arm, []).append(crew["hull_error_deg"])
            if has_focus:
                settle.setdefault(task, {}).setdefault(arm, {})[(faction, seed)] = float(row.get("settled_after_s", -1.0))
    if not crews:
        print(f"M1_HULL no rows under {root}")
        return 1
    print(f"M1_HULL runs {runs}")
    print("M1_HULL task | class | arm | n | median | p90 | <=15 deg | >=100 deg | p(new v base medians)")
    for (task, klass) in sorted(crews):
        arms = crews[(task, klass)]
        for arm in ARMS:
            v = arms.get(arm, [])
            if not v:
                continue
            p = ""
            if arm.startswith("new_"):
                p = "%.3f" % perm_p(v, arms.get(arm.replace("new_", "base_"), []))
            within = sum(1 for e in v if e <= 15.0) / len(v)
            tail = sum(1 for e in v if e >= 100.0) / len(v)
            print(f"M1_HULL {task} | {klass} | {arm} | {len(v)} | {statistics.median(v):.1f} | {pct(v, 0.9):.1f} | "
                  f"{within:.0%} | {tail:.0%} | {p}")
    print("M1_SETTLE task | runs paired | new_drawn median s | base_drawn median s | median paired diff s | never new/base")
    for task in sorted(settle):
        new = settle[task].get("new_drawn", {})
        base = settle[task].get("base_drawn", {})
        keys = sorted(set(new) & set(base))
        if not keys:
            continue
        def val(s):
            return 75.0 if s < 0 else s  # never settled in the window: counted at the window
        diffs = [val(new[k]) - val(base[k]) for k in keys]
        print(f"M1_SETTLE {task} | {len(keys)} | {statistics.median([val(new[k]) for k in keys]):.1f} | "
              f"{statistics.median([val(base[k]) for k in keys]):.1f} | {statistics.median(diffs):+.1f} | "
              f"{sum(1 for k in keys if new[k] < 0)}/{sum(1 for k in keys if base[k] < 0)}")
    print("M1_MOVING task | " + " | ".join(ARMS) + " | new_drawn - base_drawn (guard: <= +5)")
    for task in sorted(moving):
        counts = [moving[task].get(arm, 0) for arm in ARMS]
        print(f"M1_MOVING {task} | " + " | ".join(str(c) for c in counts) + f" | {counts[0] - counts[1]:+d}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "build/manoeuvre/hull-rest"))
