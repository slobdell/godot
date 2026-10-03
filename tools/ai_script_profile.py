#!/usr/bin/env python3
"""Round 16 (brains): a FUNCTION-LEVEL profile of GDScript, from Godot's own script profiler.

`godot -d --profiling` (the local stdout debugger) prints, at an interval, one frame's script functions as
    FRAME: total: <s> script: <s>/<pct> %
    <i>:<path>::<line>::<function>
    \ttotal: <s>/<pct> % \tself: <s>/<pct> % tcalls: <n>
for every function that ran in that frame. (Its ACCUMULATED line is empty in 4.7.2.) Summing the sampled frames over a
whole match gives where script time goes, by function: a sampling profile whose samples are whole frames. Every
number here is a share of the SAMPLED frames' script time, so the profiler's own overhead does not skew the ranking,
but the absolute seconds include it (instrumented calls run slower than plain ones).

Usage: ai_script_profile.py <log> [--top N] [--json out.json]
"""
import argparse
import json
import re
import sys
from collections import defaultdict

FRAME = re.compile(r"^FRAME: total: ([0-9.e-]+) script: ([0-9.e-]+)/")
FUNC = re.compile(r"^\d+:(.*)::(\d+)::(.+)$")
STATS = re.compile(r"total: ([0-9.e-]+)/[0-9.]+ % \s*self: ([0-9.e-]+)/[0-9.]+ % tcalls: (\d+)")


def parse_frames(path):
    """[(script_s, {function: (total_s, self_s, calls)})] in log order."""
    frames = []
    current = None
    with open(path, errors="replace") as f:
        for raw in f:
            line = raw.rstrip("\n")
            m = FRAME.match(line)
            if m:
                frames.append((float(m.group(2)), {}))
                continue
            m = FUNC.match(line)
            if m and frames:
                path_ = m.group(1).replace("res://", "")
                current = f"{path_}:{m.group(2)} {m.group(3)}"
                continue
            m = STATS.search(line)
            if m and current is not None and frames:
                frames[-1][1][current] = (float(m.group(1)), float(m.group(2)), int(m.group(3)))
                current = None
    return frames


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--top", type=int, default=40)
    ap.add_argument("--json", default="")
    ap.add_argument("--only-with", default="OrderController._physics_process",
                    help="keep only sampled frames in which a function matching this substring ran (the fight)")
    ap.add_argument("--skip-with", default="Match.spawn_tank,Arena._bake,Arena.load_layout,VisualSlot.fill",
                    help="drop sampled frames in which any of these ran (setup frames are long and swamp the sample)")
    args = ap.parse_args()
    skips = [x for x in args.skip_with.split(",") if x]
    self_s = defaultdict(float)
    total_s = defaultdict(float)
    calls = defaultdict(int)
    frames = 0
    dropped = 0
    script_sum = 0.0
    for script, funcs in parse_frames(args.log):
        names = funcs.keys()
        if (args.only_with and not any(args.only_with in n for n in names)) or any(s in n for n in names for s in skips):
            dropped += 1
            continue
        frames += 1
        script_sum += script
        for name, (total, self_, n) in funcs.items():
            total_s[name] += total
            self_s[name] += self_
            calls[name] += n
    if frames == 0:
        print(f"ai-script-profile: no usable FRAME blocks ({dropped} dropped; was the run started with -d --profiling?)")
        return 1
    print(f"AI_SCRIPT_PROFILE {frames} sampled fight frames ({dropped} setup/other frames dropped), "
          f"{script_sum / frames * 1000:.2f} ms of script a sampled frame (profiler on: absolute ms are inflated, "
          f"shares are what to read)")
    print(f"{'self %':>7} {'self ms/fr':>10} {'total %':>8} {'calls/fr':>9}  function")
    rows = sorted(self_s, key=lambda k: -self_s[k])
    for key in rows[:args.top]:
        print(f"{100 * self_s[key] / script_sum:7.2f} {self_s[key] / frames * 1000:10.3f} "
              f"{100 * total_s[key] / script_sum:8.2f} {calls[key] / frames:9.1f}  {key}")
    if args.json:
        with open(args.json, "w") as out:
            json.dump({"frames": frames, "dropped": dropped, "script_s": script_sum,
                       "functions": [{"function": k, "self_s": self_s[k], "total_s": total_s[k], "calls": calls[k]}
                                     for k in rows]}, out, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
