#!/usr/bin/env python3
"""Round 35 (brains E1): where an element's leg step waits, and on what.

Reads hull-rest style run logs (<dir>/<arm>/<faction>/<task>-<seed>/run.log) made with `--element-trace=all --turn-states`:
LEG_GATE lines (ElementPlan.LEG_TRACE: reached, closed, the crew `_cohesive` waits on) and MANOEUVRE_STATE lines (each crew's
order, its source, its real speed). A WAIT second is one where the element has reached its leg's anchor, is not arrived, and is
not closed up. Each is put on the crew it waits on, by what that crew was doing that second:

  closing   it made real progress (real_mps >= MOVING_MPS)
  wedged    it holds a move but makes no real progress (driving against something, or pinned)
  parked    it holds a move but sits inside its arrive radius of the move's goal (goal <= PARKED_GOAL_M) at rest
  face      it holds a face order (any source: sector, order, post, contact, squad)
  stop      it holds a stop (or nothing)

and a HOLD is a run of consecutive wait seconds on one element; `long` holds are >= LONG_S. Prints a table per arm x task and
the per-run rows of every long hold. Report only.

usage: leg_wait_table.py <dir> [--rows]
"""
import os
import re
import sys
from collections import defaultdict

MOVING_MPS = 0.5
PARKED_GOAL_M = 9.0
LONG_S = 10

GATE = re.compile(r"LEG_GATE t=([\d.]+) \[([^\]]*)\] id (\d+) arrived (\w+) reached (\w+) \(([-\d.]+) m\) closed (\w+)(?: held by (\S+) ([\d.]+) m)?")
STATE = re.compile(r"MANOEUVRE_STATE f (\d+) (\S+) \S+ order (\S+) from (\S*) .*? goal ([\d.inf]+) real ([\d.]+)")


def read_run(path):
    crews = {}  # second -> crew -> (order, source, goal, real)
    gates = []  # (second, element key, reached, closed, held_by, gap)
    releases = [0]  # LEG_GATE lines that say the straggler release stepped the leg (traced once a second: a lower bound)
    with open(path, errors="replace") as handle:
        for line in handle:
            if "LEG_GATE" in line:
                if " released " in line:
                    releases[0] += 1
                m = GATE.search(line)
                if m and m.group(4) == "false":
                    gates.append((int(float(m.group(1))), "%s#%s" % (m.group(2), m.group(3)), m.group(5) == "true",
                                  m.group(7) == "true", m.group(8), float(m.group(9) or 0.0)))
            elif "MANOEUVRE_STATE" in line:
                m = STATE.search(line)
                if m:
                    second = int(m.group(1)) // 30
                    goal = float(m.group(5)) if m.group(5) != "inf" else float("inf")
                    crews.setdefault(second, {})[m.group(2)] = (m.group(3), m.group(4), goal, float(m.group(6)))
    return gates, crews, releases[0]


def kind_of(state):
    if state is None:
        return "stop"
    order, _source, goal, real = state
    if real >= MOVING_MPS:
        return "closing"
    if order == "move_to":
        return "parked" if goal <= PARKED_GOAL_M else "wedged"
    if order == "face":
        return "face"
    return "stop"


def main():
    root = sys.argv[1]
    rows = "--rows" in sys.argv
    table = defaultdict(lambda: defaultdict(float))
    holds = []
    for arm in sorted(os.listdir(root)):
        arm_dir = os.path.join(root, arm)
        if not os.path.isdir(arm_dir):
            continue
        for faction in sorted(os.listdir(arm_dir)):
            for run in sorted(os.listdir(os.path.join(arm_dir, faction))):
                log = os.path.join(arm_dir, faction, run, "run.log")
                if not os.path.exists(log):
                    continue
                task = run.rsplit("-", 1)[0]
                gates, crews, released = read_run(log)
                table[(arm, task)]["released"] += released
                key = (arm, task)
                table[key]["runs"] += 1
                streak = {}
                for second, element, reached, closed, held_by, gap in gates:
                    if not reached or closed or held_by is None:
                        if element in streak:
                            holds.append((arm, task, faction, run, element) + streak.pop(element))
                        continue
                    kind = kind_of(crews.get(second, {}).get(held_by))
                    table[key]["wait"] += 1
                    table[key][kind] += 1
                    start, last, kinds, first_gap, _gap, who = streak.get(element, (second, second, defaultdict(int), gap, gap, held_by))
                    kinds[kind] += 1
                    streak[element] = (start, second, kinds, first_gap, gap, held_by)
                for element, value in streak.items():
                    holds.append((arm, task, faction, run, element) + value)
    for hold in holds:
        arm, task = hold[0], hold[1]
        length = hold[6] - hold[5] + 1
        if length >= LONG_S:
            table[(arm, task)]["long"] += 1
            table[(arm, task)]["long_s"] += length
    kinds = ["closing", "wedged", "parked", "face", "stop"]
    print("leg waits (element reached its anchor, not closed up), seconds summed over runs; long = holds >= %d s" % LONG_S)
    print("%-11s %-22s %5s %7s %s %6s %7s %8s" % ("arm", "task", "runs", "wait_s", " ".join("%8s" % k for k in kinds), "long", "long_s",
          "released"))
    for (arm, task), counts in sorted(table.items()):
        print("%-11s %-22s %5d %7d %s %6d %7d %8d" % (arm, task, counts["runs"], counts["wait"],
              " ".join("%8d" % counts[k] for k in kinds), counts["long"], counts["long_s"], counts["released"]))
    if rows:
        print("\nlong holds: arm task faction run element from-to (s) gap first->last (m) waiting on, seconds by kind")
        for arm, task, faction, run, element, start, last, kinds_seen, first_gap, gap, who in holds:
            if last - start + 1 >= LONG_S:
                print("  %s %s %s %s %s %d-%d %.1f->%.1f %s %s" % (arm, task, faction, run, element, start, last, first_gap, gap,
                      who, dict(kinds_seen)))


if __name__ == "__main__":
    main()
