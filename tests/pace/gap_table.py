#!/usr/bin/env python3
"""Round 25 pace (stretch b): the frame in the 8-20 s window by component, from `make native-tick-profile` logs.

Usage: gap_table.py <dir> [arm, default on] [arenas, default foundry,parade]
Reads <dir>/tp-<arm>-25-<arena>-main-<seed>.log (the NATIVE_TICK_PROFILE line). Per run and mean (se) over runs:
frame wall ms, ticks a frame, game speed (ticks a frame x 33.33 / frame ms, C24.7), the tick's scripts (instrumented)
by segment, the engine's physics step, Godot's TIME_PROCESS per frame, and the residual
frame - ticks a frame x (tick scripts + physics step). Then the tick a frame must reach for 0.97 at today's residual.
"""
import glob
import json
import math
import re
import statistics
import sys

TICK_MS = 1000.0 / 30.0
GROUPS = [
    ("controllers: think", ["brain/think"]),
    ("  situation", ["brain/situation"]),
    ("  t.poll", ["brain/t.poll"]),
    ("  act", ["brain/act"]),
    ("  decide", ["brain/decide"]),
    ("  rate_progress", ["brain/t.rate_progress"]),
    ("  incoming", ["brain/t.incoming"]),
    ("controllers: execute", ["brain/execute"]),
    ("  weapon", ["brain/weapon"]),
    ("  move", ["brain/move"]),
    ("controllers (segment)", ["segment:controllers"]),
    ("elements (segment)", ["segment:elements"]),
    ("tank", ["tank"]),
    ("match", ["match"]),
    ("visfield", ["visfield"]),
    ("shells", ["shell"]),
]


def mean_se(values):
    if not values:
        return float("nan"), float("nan")
    if len(values) < 2:
        return values[0], float("nan")
    return statistics.mean(values), statistics.stdev(values) / math.sqrt(len(values))


def load(directory, arm, arenas):
    rows = []
    for path in sorted(glob.glob(f"{directory}/tp-{arm}-25-*-main-*.log")):
        m = re.search(rf"tp-{re.escape(arm)}-25-(.+?)-main-(\d+)\.log$", path)
        if not m or m.group(1) not in arenas:
            continue
        for line in open(path, errors="replace"):
            if line.startswith("NATIVE_TICK_PROFILE "):
                r = json.loads(line[len("NATIVE_TICK_PROFILE "):])
                sections = r["sim"]["sections"]
                row = {"run": f"{m.group(1)}-{m.group(2)}", "frame": r["frame_wall_ms"], "tpf": r["ticks_per_frame"],
                       "tick": r["sim"]["tick_ms"], "phys": r.get("engine_physics_step_ms", 0.0),
                       "process": r.get("process_ms", 0.0), "alive": r.get("alive")}
                for label, keys in GROUPS:
                    row[label] = sum(sections.get(k, {}).get("ms_per_tick", 0.0) for k in keys)
                row["speed"] = row["tpf"] * TICK_MS / row["frame"]
                row["residual"] = row["frame"] - row["tpf"] * (row["tick"] + row["phys"])
                rows.append(row)
    return rows


def main(directory, arm="on", arenas="foundry,parade"):
    rows = load(directory, arm, arenas.split(","))
    if not rows:
        print(f"gap_table: no tp-{arm}-25-*.log with NATIVE_TICK_PROFILE in {directory}")
        return 1
    print(f"| run | alive | frame ms | ticks/frame | game speed | tick scripts ms | physics step ms | TIME_PROCESS ms | residual ms |")
    print("|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        print(f"| {r['run']} | {r['alive']} | {r['frame']:.1f} | {r['tpf']:.2f} | {r['speed']:.3f} | {r['tick']:.1f} | "
              f"{r['phys']:.2f} | {r['process']:.1f} | {r['residual']:.1f} |")
    print()
    for key in ["frame", "tpf", "speed", "tick", "phys", "process", "residual"] + [g[0] for g in GROUPS]:
        m, se = mean_se([r[key] for r in rows])
        print(f"{key:24s} {m:8.3f}  (se {se:.3f}, n = {len(rows)})")
    tpf = statistics.mean(r["tpf"] for r in rows)
    residual = statistics.mean(r["residual"] for r in rows)
    phys = statistics.mean(r["phys"] for r in rows)
    tick = statistics.mean(r["tick"] for r in rows)
    need = tpf * TICK_MS / 0.97
    target = (need - residual) / tpf - phys
    print(f"\nfor 0.97 at {tpf:.2f} ticks a frame and today's residual {residual:.1f} ms: frame <= {need:.1f} ms, "
          f"tick scripts <= {target:.1f} ms (today {tick:.1f}, instrumented): {tick - target:+.1f} ms a tick to find")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
