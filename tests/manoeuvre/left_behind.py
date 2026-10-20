#!/usr/bin/env python3
"""Round 36 (manoeuvre S2 / X4b): the crews left behind at the judge, and what each is doing (one hull-rest arm).

usage: left_behind.py <hull-rest arm dir> [--list N]     (e.g. ~/overnight-manoeuvre/r36/x4b/hull-rest/new_drawn)

Left behind = Bar E1's (c): > e1_bar.LEFT_M (25 m) off its slot in its element's last ELEMENT_TRACE row (tests/tactics/e1_bar.py,
read in place). Each such crew is then named by its MANOEUVRE_STATE rows over the WINDOW_S before that row, by NET motion
(brains' X4a rule, mover_kind.py; never real_mps alone):
  closing  its goal distance fell by >= CLOSE_M          (catching up)
  wedged   net motion < STILL_M while it holds a move whose goal is > GOAL_M away; split by the throttle it is asking for:
           `pressing` (median |throttle| > 0.5: driving hard, going nowhere) or `idle` (a move held at ~0 throttle)
  stopped  order stop / no live goal (the element left it no move)
  wander   anything else (moving, not closer)
Measurement only.
"""
import collections
import math
import os
import re
import statistics
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tactics"))
import e1_bar  # noqa: E402

## e1_bar.OFF reads a crew name as one word; "Green_Eyes II_3" has a space (each crew follows " | " in the row).
OFF = re.compile(r"\| (.+?) at \([-\d.,]+\) slot \([-\d.,]+\) ([\d.]+) m off")
WINDOW_S = 10.0
CLOSE_M = 3.0
STILL_M = 1.0
GOAL_M = 5.0
STATE = re.compile(r"^MANOEUVRE_STATE f (\d+) (.+?) (\S+) order (\S+) .* cmd (-?[\d.]+)/(-?[\d.]+) .* touch (\S+) stuck ([\d.]+) "
                   r".* esc ([\d.]+) goal ([\d.]+) real ([\d.]+) at (-?[\d.]+) (-?[\d.]+) to")


def read(log):
    rows, last = collections.defaultdict(list), {}
    for line in open(log, errors="replace"):
        if line.startswith("SCREEN {"):
            break
        m = STATE.match(line)
        if m:
            f, name, unit, order, thr, turn, touch, stuck, esc, goal, real, x, z = m.groups()
            rows[name].append((int(f), unit, order, float(thr), touch == "true", float(stuck), float(esc), float(goal),
                               float(real), float(x), float(z)))
            continue
        if "ELEMENT_TRACE" in line:
            r = e1_bar.ROW.search(line)
            if r:
                last[r.group(2)] = (float(r.group(1)), line)
    return rows, last


def kind(track, at_s):
    window = [r for r in track if at_s - WINDOW_S <= r[0] / 30.0 <= at_s]
    if len(window) < 2:
        return "unknown", {}
    a, b = window[0], window[-1]
    net = math.hypot(b[9] - a[9], b[10] - a[10])
    thr = statistics.median(abs(r[3]) for r in window)
    info = {"unit": b[1], "order": b[2], "net": net, "goal": b[7], "thr": thr, "real": b[8], "touch": sum(r[4] for r in window),
            "esc": sum(r[6] > 0 for r in window), "max_stuck": max(r[5] for r in window), "at": (b[9], b[10])}
    if b[2] == "stop" or b[7] <= 0.0:
        return "stopped", info
    if a[7] - b[7] >= CLOSE_M:
        return "closing", info
    if net < STILL_M and b[7] > GOAL_M:
        return ("wedged:pressing" if thr > 0.5 else "wedged:idle"), info
    return "wander", info


def main():
    root = sys.argv[1]
    show = int(sys.argv[sys.argv.index("--list") + 1]) if "--list" in sys.argv else 12
    runs, total, kinds, per_task, out = 0, 0, collections.Counter(), collections.defaultdict(collections.Counter), []
    for faction in sorted(os.listdir(root)):
        for run in sorted(os.listdir(os.path.join(root, faction))):
            log = os.path.join(root, faction, run, "run.log")
            if not os.path.exists(log):
                continue
            runs += 1
            rows, last = read(log)
            task = run.rsplit("-", 1)[0]
            for at_s, line in last.values():
                for unit, off in OFF.findall(line):
                    if float(off) <= e1_bar.LEFT_M:
                        continue
                    total += 1
                    k, info = kind(rows.get(unit, []), at_s)
                    kinds[k] += 1
                    per_task[task][k] += 1
                    out.append((float(off), faction, run, unit, k, info, at_s))
    print("left_behind: %d runs, %d crews > %.0f m off their slot at the element's last row" % (runs, total, e1_bar.LEFT_M))
    print("  by kind (net motion over the last %.0f s): %s" % (WINDOW_S, dict(kinds.most_common())))
    for task, c in sorted(per_task.items()):
        print("  %-20s %3d  %s" % (task, sum(c.values()), dict(c.most_common())))
    print("  worst %d (off, run, crew, kind, net m, goal m, median |thr|, touch ticks, esc ticks, max stuck clock, at):" % show)
    for off, faction, run, unit, k, info, at_s in sorted(out, reverse=True, key=lambda r: r[0])[:show]:
        print("    %5.1f %s/%s %s %s net %.2f goal %.1f thr %.2f touch %s esc %s stuck %.2f at %s t %.0f" % (
            off, faction, run, unit, k, info.get("net", -1), info.get("goal", -1), info.get("thr", -1), info.get("touch"),
            info.get("esc"), info.get("max_stuck", -1), info.get("at"), at_s))
    wedged = [r for r in out if r[4].startswith("wedged")]
    print("  every wedged crew (%d):" % len(wedged))
    for off, faction, run, unit, k, info, at_s in sorted(wedged, reverse=True, key=lambda r: r[0]):
        print("    %5.1f %s/%s %s %s %s net %.2f goal %.1f thr %.2f touch %s esc %s stuck %.2f at (%.1f, %.1f) t %.0f" % (
            off, faction, run, unit, info["unit"], k, info["net"], info["goal"], info["thr"], info["touch"], info["esc"],
            info["max_stuck"], info["at"][0], info["at"][1], at_s))


if __name__ == "__main__":
    main()
