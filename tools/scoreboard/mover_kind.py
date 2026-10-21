"""The scoreboard's "still moving" rule: brains' tests/tactics/mover_kind.py (stream/brains f1e3e6a9b, Round 35 extension
X4a), copied with its rule unchanged and without e1_bar's release inference. A crew moving at the judge (screen.json
real_mps >= MOVER_MPS) is named by its last WINDOW_S of MANOEUVRE_STATE rows, cut at the judge's own `stop`:
`closing` (its goal distance fell by >= CLOSE_M), `jitter` (it moved < JITTER_M net: a hull rocking in place, typically
wedged; brains found all three of Bar E1's extra "movers" were these), else `wander`. Still moving = closing + wander;
jitter is counted with the stuck."""
import json
import math
import os
import re

MOVER_MPS = 0.3
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
    if not track:
        return "unknown"
    # The judge's own `stop` follows SCREEN: cut the track at the last row before it.
    if len(track) > 1 and track[-1][1] == "stop" and track[-2][1] != "stop":
        track = track[:-1]
    last = track[-1]
    window = [r for r in track if r[0] >= last[0] - WINDOW_S * 30]
    first = window[0]
    if first[2] - last[2] >= CLOSE_M:
        return "closing"
    if math.hypot(last[4] - first[4], last[5] - first[5]) < JITTER_M:
        return "jitter"
    return "wander"


def movers(run_dir):
    """[(unit, kind)] for every crew moving at the judge of one hull-rest run."""
    rows = [r for r in json.load(open(os.path.join(run_dir, "screen.json"))) if "squads" in r]
    if not rows:
        return []
    found = [c["unit"] for s in rows[0]["squads"] for c in s.get("each", []) if float(c.get("real_mps", 0.0)) >= MOVER_MPS]
    if not found:
        return []
    tr = tracks(os.path.join(run_dir, "run.log"))
    return [(unit, kind(tr.get(unit, []))) for unit in found]
