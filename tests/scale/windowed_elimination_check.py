#!/usr/bin/env python3
"""Round 17 (sim F5): the regression check for the kill-cam fork. Two windowed runs of one seed that END in an
elimination, dumped every tick (SIM_HASH + the detail's clock line). Passes when:
  1. the kill-cam fired (some tick ran at time_scale < 1: the run really went past a decided elimination);
  2. in each run the slow motion lasted EXACTLY KillCam.HOLD_TICKS + RAMP_TICKS consecutive ticks (read from
     game/theme/fx/kill_cam.gd), i.e. its schedule is a function of ticks, not of how fast the frames came;
  3. the two runs hashed identically on every tick (the same fight past the end);
  4. the kill-cam reported `wall_cap=false` (its real-time bound is off in a --fixed-fps run: Godot hides --fixed-fps
     from scripts, so it reads /proc/self/cmdline; an empty read would leave the bound on and show ~4 slowed ticks).
On the wall-clock kill-cam (the round-16/17 defect) builder0's ~1 s windowed frames give ~3 slowed ticks: (2) fails.
Usage: windowed_elimination_check.py run1.txt run2.txt [kill_cam.gd]
"""
import re
import sys


def schedule_ticks(path):
    text = open(path).read()
    hold = int(re.search(r"const HOLD_TICKS := (\d+)", text).group(1))
    ramp = int(re.search(r"const RAMP_TICKS := (\d+)", text).group(1))
    return hold + ramp


def load(path):
    hashes, scales, caps = [], {}, []
    for line in open(path, errors="replace"):
        parts = line.split()
        if line.startswith("KILL_CAM start"):
            caps += [p.split("=")[1] for p in parts if p.startswith("wall_cap=")]
        if len(parts) >= 3 and parts[0] == "SIM_HASH":
            hashes.append((parts[1], parts[2]))
        elif len(parts) >= 3 and parts[0] == "SIM_HASH_DETAIL" and parts[2] == "clock":
            tick = int(parts[1].split("=")[1])
            for p in parts[3:]:
                if p.startswith("time_scale="):
                    scales[tick] = float(p.split("=")[1])
    return hashes, scales, caps


def slowed_runs(scales):
    runs, start, prev = [], None, None
    for tick in sorted(scales):
        slow = scales[tick] < 1.0
        if slow and start is None:
            start = tick
        if not slow and start is not None:
            runs.append((start, prev - start + 1))
            start = None
        prev = tick
    if start is not None:
        runs.append((start, prev - start + 1, "open"))
    return runs


def main():
    expected = schedule_ticks(sys.argv[3] if len(sys.argv) > 3 else "game/theme/fx/kill_cam.gd")
    (h1, s1, c1), (h2, s2, c2) = load(sys.argv[1]), load(sys.argv[2])
    r1, r2 = slowed_runs(s1), slowed_runs(s2)
    problems = []
    if not h1 or not h2:
        problems.append("a run printed no hashes (%d / %d lines)" % (len(h1), len(h2)))
    for name, runs in (("run1", r1), ("run2", r2)):
        if not runs:
            problems.append("%s: the kill-cam never fired (no tick below time_scale 1): not past an elimination" % name)
        elif len(runs) != 1 or len(runs[0]) != 2 or runs[0][1] != expected:
            problems.append("%s: slow motion %s, expected one run of exactly %d ticks" % (name, runs, expected))
    for name, caps in (("run1", c1), ("run2", c2)):
        if caps != ["false"]:
            problems.append("%s: the kill-cam reported wall_cap=%s in a --fixed-fps run (expected one start line, false)" % (name, caps or "nothing"))
    first = next((a[0] for a, b in zip(h1, h2) if a != b), None)
    if first is not None or len(h1) != len(h2):
        problems.append("the runs forked at %s (lines %d / %d)" % (first, len(h1), len(h2)))
    print("WINDOWED_ELIMINATION %s slowed=%s/%s expected=%d wall_cap=%s/%s lines=%d/%d first_divergence=%s" % (
        "ok" if not problems else "FAILED", r1, r2, expected, c1, c2, len(h1), len(h2), first or "none"))
    for p in problems:
        print("  " + p)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
