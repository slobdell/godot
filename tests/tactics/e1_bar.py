#!/usr/bin/env python3
"""Round 35 (brains E1): Bar E1's lines (streams/brains.md) from one hull-rest series of two arms.

usage: e1_bar.py <dir> [new_arm] [base_arm]     (defaults new_drawn, base_drawn)

Per run (<dir>/<arm>/<faction>/<task>-<seed>/): long-hold seconds (leg waits >= LONG_S, leg_wait_table), releases (LEG_GATE
`released`), crews left behind (> LEFT_M off their slot in their element's last ELEMENT_TRACE row), late movers at the judge
(screen.json crews with real_mps >= MOVER_MPS), settled in 75 s (settled_after_s >= 0), squads arrived. Pairs the arms by
(faction, task, seed) and prints, per task, each arm's sum, the paired difference and its se (sd of the paired differences
x sqrt(n)). Report only; the verdict is read against the bar by hand.
"""
import json
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import leg_wait_table as lw  # noqa: E402

LEFT_M = 25.0
MOVER_MPS = 0.3
ROW = re.compile(r"ELEMENT_TRACE t=([\d.]+) \[[^\]]*\] id (\d+) ")
OFF = re.compile(r"(\S+) at \([-\d.,]+\) slot \([-\d.,]+\) ([\d.]+) m off")


def long_seconds(log):
    gates, _crews, released = lw.read_run(log)
    total, streak = 0, {}
    for second, element, reached, closed, held_by, _gap in gates:
        if reached and not closed and held_by is not None:
            start, _last = streak.get(element, (second, second))
            streak[element] = (start, second)
        elif element in streak:
            start, last = streak.pop(element)
            total += (last - start + 1) if last - start + 1 >= lw.LONG_S else 0
    for start, last in streak.values():
        total += (last - start + 1) if last - start + 1 >= lw.LONG_S else 0
    return total, released


def left_behind(log):
    """(left, left_wedged): crews > LEFT_M off their slot in their element's last row, and of those the ones whose
    MANOEUVRE_STATE at that row's second is wedged (holding a move, real speed under lw.MOVING_MPS, goal beyond lw.PARKED_GOAL_M): stuck where
    they were, which the release leaves behind but does not cause (the orchestrator's split, R35.3)."""
    last = {}
    with open(log, errors="replace") as handle:
        for line in handle:
            if "ELEMENT_TRACE" not in line:
                continue
            m = ROW.search(line)
            if m:
                last[m.group(2)] = (int(float(m.group(1))), line)
    _gates, crews, _released = lw.read_run(log)
    count, wedged = 0, 0
    for second, line in last.values():
        for unit, off in OFF.findall(line):
            if float(off) > LEFT_M:
                count += 1
                wedged += lw.kind_of(crews.get(second, {}).get(unit)) == "wedged"
    return count, wedged


def judge(run_dir):
    path = os.path.join(run_dir, "screen.json")
    if not os.path.exists(path):
        return None
    rows = [r for r in json.load(open(path)) if "squads" in r]
    if not rows:
        return None
    row = rows[0]
    movers = sum(1 for s in row["squads"] for c in s.get("each", []) if float(c.get("real_mps", 0.0)) >= MOVER_MPS)
    arrived = sum(1 for s in row["squads"] if s.get("arrived"))
    settled = 1 if float(row.get("settled_after_s", -1.0)) >= 0.0 else 0
    return movers, arrived, settled


def read_arm(root, arm):
    runs = {}
    arm_dir = os.path.join(root, arm)
    for faction in sorted(os.listdir(arm_dir)):
        for run in sorted(os.listdir(os.path.join(arm_dir, faction))):
            run_dir = os.path.join(arm_dir, faction, run)
            log = os.path.join(run_dir, "run.log")
            judged = judge(run_dir)
            if not os.path.exists(log) or judged is None:
                continue
            held, released = long_seconds(log)
            task, seed = run.rsplit("-", 1)
            left, left_wedged = left_behind(log)
            runs[(faction, task, seed)] = {"long_s": held, "released": released, "left": left, "left_wedged": left_wedged,
                                           "movers": judged[0], "arrived": judged[1], "settled": judged[2]}
    return runs


def main():
    root = sys.argv[1]
    new_arm = sys.argv[2] if len(sys.argv) > 2 else "new_drawn"
    base_arm = sys.argv[3] if len(sys.argv) > 3 else "base_drawn"
    new, base = read_arm(root, new_arm), read_arm(root, base_arm)
    keys = sorted(set(new) & set(base))
    print("E1 bar: %s v %s, %d paired runs (%d / %d read)" % (new_arm, base_arm, len(keys), len(new), len(base)))
    for task in sorted({k[1] for k in keys}):
        pairs = [k for k in keys if k[1] == task]
        print("== %s (n %d)" % (task, len(pairs)))
        for line in ["released", "long_s", "left", "left_wedged", "movers", "settled", "arrived"]:
            diffs = [new[k][line] - base[k][line] for k in pairs]
            n = len(diffs)
            mean = sum(diffs) / n
            sd = math.sqrt(sum((d - mean) ** 2 for d in diffs) / (n - 1)) if n > 1 else 0.0
            print("  %-9s new %6d base %6d  paired diff %+6d  se %6.1f" % (line, sum(new[k][line] for k in pairs),
                  sum(base[k][line] for k in pairs), sum(diffs), sd * math.sqrt(n)))


if __name__ == "__main__":
    main()
