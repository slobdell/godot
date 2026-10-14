#!/usr/bin/env python3
"""Round 30 (brains B5c-v4, the orchestrator's addition b): how each come-round ended, from --gate-trace logs.
A come-round starts when a hull's answer becomes `reached_facing_away` for a goal it was not already turning for; it ends
at the first of: `latched` (came round and reached the gate on the heading), `turn_blocked` (stuck on terrain or a hull),
`turn_capped` (GATE_TURN_SECONDS), the goal moving (> 3 m: a new order), or a reset (`stalled`/`near`/`aimed` for the
same goal after Movement.reset cleared the turn: counted as `reset`). Usage: gate_endings.py LOG [LOG...]"""
import collections
import re
import sys

LINE = re.compile(r"GATE_TRACE t=([\d.]+) (\S+) (\S+) goal \(([-\d.]+), ([-\d.]+)\)")
END = {"latched": "latched", "turn_blocked": "stuck", "turn_capped": "cap"}


def endings(path):
    turning = {}  # unit -> (goal, start t)
    out = collections.Counter()
    for line in open(path, errors="replace"):
        m = LINE.search(line)
        if not m:
            continue
        t, unit, answer = float(m.group(1)), m.group(2), m.group(3)
        goal = (float(m.group(4)), float(m.group(5)))
        if unit in turning:
            g, _ = turning[unit]
            moved = ((goal[0] - g[0]) ** 2 + (goal[1] - g[1]) ** 2) ** 0.5 > 3.0
            if moved:
                out["goal_moved"] += 1
                del turning[unit]
            elif answer in END:
                out[END[answer]] += 1
                del turning[unit]
                continue
            elif answer in ("stalled", "near", "latched_away"):
                out["reset"] += 1
                del turning[unit]
            else:
                continue
        if answer == "reached_facing_away":
            turning[unit] = (goal, t)
    out["unfinished"] += len(turning)
    return out


if __name__ == "__main__":
    total = collections.Counter()
    for path in sys.argv[1:]:
        e = endings(path)
        total.update(e)
        print("%-50s %s" % (path.split("/")[-1], dict(e)))
    print("TOTAL", dict(total))
