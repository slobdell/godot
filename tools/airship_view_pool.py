#!/usr/bin/env python3
"""Pool `make airship-view` runs (round 14, airship A1/A3): per map and arm, over every seed.

    python3 tools/airship_view_pool.py build/airship-view

Each run writes <dir>/<arm>/<seed>/airship_view_<map>_<arm>.json. Intrusions are rare and lumpy (1-3 in a four-minute
run, each hiding most of the fight), so one seed cannot separate the arms: the verdict is pooled over seeds, with the
per-seed paired comparison beside it so a single seed carrying the pool is visible.
"""
import glob
import json
import os
import sys
from collections import defaultdict


def main(root):
    runs = defaultdict(dict)  # (map, arm) -> seed -> row
    for path in glob.glob(os.path.join(root, "*", "*", "airship_view_*.json")):
        seed = os.path.basename(os.path.dirname(path))
        with open(path) as handle:
            row = json.load(handle)
        runs[(row["arena"], row["viewavoid"])][seed] = row
    if not runs:
        print("AIRSHIP_VIEW_POOL no runs under %s" % root)
        return 1
    print("AIRSHIP_VIEW_POOL map        arm  seeds  frame%%  hides%%  intrusions  longest_s  hidden_while%%  yaw_deg_s  causes(camera/hull/both)")
    pooled = {}
    for (arena, arm), seeds in sorted(runs.items()):
        ticks = sum(r["ticks"] for r in seeds.values())
        frame = sum(r["frame_pct"] * r["ticks"] for r in seeds.values()) / max(ticks, 1)
        hides = sum(r["between_pct"] * r["ticks"] for r in seeds.values()) / max(ticks, 1)
        between_ticks = sum(r["between_pct"] * r["ticks"] / 100.0 for r in seeds.values())
        hidden_while = sum(r["hidden_pct_while_between"] * r["between_pct"] * r["ticks"] / 100.0 for r in seeds.values()) / max(between_ticks, 1)
        intrusions = sum(r["intrusions"] for r in seeds.values())
        longest = max(r["longest_s"] for r in seeds.values())
        yaw = sum(r["mean_yaw_deg_s"] * r["ticks"] for r in seeds.values()) / max(ticks, 1)
        causes = [sum(r.get("causes", {}).get(k, 0) for r in seeds.values()) for k in ("camera", "hull", "both")]
        pooled[(arena, arm)] = {"hides": hides, "frame": frame, "longest": longest, "seeds": seeds}
        print("AIRSHIP_VIEW_POOL %-10s %-4s %5d  %6.1f  %6.2f  %10d  %9.1f  %13.1f  %9.1f  %d/%d/%d" % (
            arena, arm, len(seeds), frame, hides, intrusions, longest, hidden_while, yaw, *causes))
    for arena, arm_on in sorted({(a, arm) for a, arm in pooled if arm != "off"}):
        off, on = pooled.get((arena, "off")), pooled.get((arena, arm_on))
        if not off or not on:
            continue
        common = sorted(set(off["seeds"]) & set(on["seeds"]))
        better = sum(1 for s in common if on["seeds"][s]["between_pct"] < off["seeds"][s]["between_pct"])
        worse = sum(1 for s in common if on["seeds"][s]["between_pct"] > off["seeds"][s]["between_pct"])
        ratio = on["hides"] / off["hides"] if off["hides"] > 0 else float("nan")
        scored = off["hides"] >= 2.0
        verdict = "not scored (off < 2 %)" if not scored else " ".join([
            "(a) %s ratio %.2f <= 0.40" % ("PASS" if ratio <= 0.4 else "FAIL", ratio),
            "(b) %s longest %.1f s <= 3.0" % ("PASS" if on["longest"] <= 3.0 else "FAIL", on["longest"]),
            "(c) %s frame %.1f >= 0.5 x %.1f" % ("PASS" if on["frame"] >= 0.5 * off["frame"] else "FAIL", on["frame"], off["frame"]),
            "(c') %s seen-not-hiding %.1f >= 0.5 x %.1f" % ("PASS" if on["frame"] - on["hides"] >= 0.5 * (off["frame"] - off["hides"]) else "FAIL",
                                                        on["frame"] - on["hides"], off["frame"] - off["hides"])])
        print("AIRSHIP_VIEW_VERDICT %-10s %-10s hides %.2f%% -> %.2f%%; paired seeds on better %d, worse %d, tied %d; %s" % (
            arena, arm_on, off["hides"], on["hides"], better, worse, len(common) - better - worse, verdict))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "build/airship-view"))
