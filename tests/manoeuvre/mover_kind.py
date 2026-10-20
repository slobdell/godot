#!/usr/bin/env python3
"""Round 35 extension (brains X4a): WHAT the late movers at the judge are doing. Bar E1 (d) counted crews with
real_mps >= 0.3 in screen.json (the judge) and read +3 in the release arm; this names each mover by its last WINDOW_S of
MANOEUVRE_STATE rows: `closing` (its goal distance fell by >= CLOSE_M), `jitter` (it moved < JITTER_M net: real_mps
from a hull rocking in place, typically wedged), else `wander`. Also: is the crew in an element that released a straggler
(inferred as e1_bar does), and is it the released crew itself. Usage: mover_kind.py <hull-rest root> [seed_lo seed_hi]."""
import json
import math
import os
import re
import sys

# Copied read-only from round35/brains tests/tactics/mover_kind.py (C36: manoeuvre may copy brains' readers); e1_bar stays brains'.
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tactics"))
import e1_bar  # noqa: E402

WINDOW_S = 10.0
CLOSE_M = 3.0
JITTER_M = 1.0
STATE = re.compile(r"^MANOEUVRE_STATE f (\d+) (.+?) \S+ order (\S+) .* goal ([\d.]+) real ([\d.]+) at (-?[\d.]+) (-?[\d.]+) to")


def tracks(log):
    out = {}
    for line in open(log, errors="replace"):
        m = STATE.match(line)
        if m:
            out.setdefault(m.group(2), []).append((int(m.group(1)), m.group(3), float(m.group(4)), float(m.group(5)),
                                                    float(m.group(6)), float(m.group(7))))
    return out


def kind(track):
    # The judge's own `stop` follows SCREEN: cut the track at the last row before it.
    while len(track) > 1 and track[-1][1] == "stop" and track[-2][1] != "stop":
        track = track[:-1]
        break
    last = track[-1]
    window = [r for r in track if r[0] >= last[0] - WINDOW_S * 30]
    first = window[0]
    net = math.hypot(last[4] - first[4], last[5] - first[5])
    if first[2] - last[2] >= CLOSE_M:
        return "closing", net, last[2]
    if net < JITTER_M:
        return "jitter", net, last[2]
    return "wander", net, last[2]


def movers(run_dir):
    rows = [r for r in json.load(open(os.path.join(run_dir, "screen.json"))) if "squads" in r]
    if not rows:
        return []
    return [(s["squad"], c["unit"]) for s in rows[0]["squads"] for c in s.get("each", [])
            if float(c.get("real_mps", 0.0)) >= e1_bar.MOVER_MPS]


def main():
    root = sys.argv[1]
    lo, hi = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (0, 10 ** 9)
    totals = {}
    for arm in sorted(os.listdir(root)):
        for faction in sorted(os.listdir(os.path.join(root, arm))):
            for run in sorted(os.listdir(os.path.join(root, arm, faction))):
                seed = int(run.rsplit("-", 1)[1])
                run_dir = os.path.join(root, arm, faction, run)
                if not lo <= seed <= hi or not os.path.exists(os.path.join(run_dir, "screen.json")):
                    continue
                found = movers(run_dir)
                if not found:
                    continue
                tr = tracks(os.path.join(run_dir, "run.log"))
                _, released = e1_bar.long_seconds(os.path.join(run_dir, "run.log"))
                for squad, unit in found:
                    k, net, goal = kind(tr.get(unit, [(0, "", 0, 0, 0, 0)]))
                    totals[(arm, run.rsplit("-", 1)[0], k)] = totals.get((arm, run.rsplit("-", 1)[0], k), 0) + 1
                    print("%-10s %-9s %-24s %-20s %-7s net %5.1f m goal %5.1f m  run releases %d" % (
                        arm, faction, run, unit, k, net, goal, released))
    print("== totals (arm, task, kind)")
    for key in sorted(totals):
        print("  %-10s %-20s %-7s %d" % (key[0], key[1], key[2], totals[key]))


if __name__ == "__main__":
    main()
