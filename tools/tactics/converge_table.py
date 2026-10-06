#!/usr/bin/env python3
"""Round 20 (brains M1): orders' two-squad probe, every arm of form-up-on-the-move, as one table.

Per map x selection case (selected, grouped, single), for each arm (--converge=off is round 12's stations): the worst
distance any vehicle got FARTHER from the click in its first 5 s, and the worst distance off the straight line from
where it stood to where it is meant to stand ("away / off-line", metres). A run without two_squads.json is MISSING and
fails the target.

Usage: converge_table.py build/converge-probe   (directories <map>-<arm>-r<rep>)
"""
import json
import os
import sys


def main(root):
    runs = {}
    missing = 0
    for name in sorted(os.listdir(root)):
        path = os.path.join(root, name, "two_squads.json")
        if not os.path.isfile(path):
            print(f"CONVERGE_PROBE MISSING {name}")
            missing += 1
            continue
        runs[name] = json.load(open(path))["cases"]
    # Directory names are <map>-<arm>-r<rep>.
    maps = sorted({name.split("-")[0] for name in runs})
    arms = []
    for name in sorted(runs):
        arm = name.split("-")[1]
        if arm not in arms:
            arms.append(arm)
    arms.sort(key=lambda a: (a != "off", a))
    print("away / off-line in the first 5 s (m), one value per repeat")
    print("| map | case | " + " | ".join(arms) + " |")
    print("|---|---|" + "---|" * len(arms))
    for arena in maps:
        for case in ("selected", "grouped", "single"):
            cells = []
            for arm in arms:
                reps = [runs[n].get(case, {}).get("summary", {}) for n in sorted(runs) if n.startswith(f"{arena}-{arm}-r")]
                away = ", ".join(str(r.get("worst_away_5s_m", "?")) for r in reps)
                off_line = ", ".join(str(r.get("worst_off_line_5s_m", "?")) for r in reps)
                cells.append(f"{away} / {off_line}")
            print(f"| {arena} | {case} | " + " | ".join(cells) + " |")
    print(f"CONVERGE_PROBE runs {len(runs)} missing {missing}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
