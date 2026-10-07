#!/usr/bin/env python3
"""Pool `make airship-view` runs (round 14, airship A1/A3): per map and arm, over every seed.

    python3 tools/airship_view_pool.py build/airship-view
    python3 tools/airship_view_pool.py --trace build/airship-view   # round 15 B1: every intrusion, from the traces

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
    print("AIRSHIP_VIEW_POOL map        arm  seeds  frame%%  hides%%  intrusions  longest_s  hidden_while%%  yaw_deg_s  causes(camera/hull/both)  inside%  seen_clean%  visible%  belly%")
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
        inside = sum(r.get("inside_pct", 0.0) * r["ticks"] for r in seeds.values()) / max(ticks, 1)
        visible = sum(r.get("visible_pct", float("nan")) * r["ticks"] for r in seeds.values()) / max(ticks, 1)
        belly = sum(r.get("belly_pct", float("nan")) * r["ticks"] for r in seeds.values()) / max(ticks, 1)
        pooled[(arena, arm)] = {"hides": hides, "frame": frame, "longest": longest, "seeds": seeds}
        print("AIRSHIP_VIEW_POOL %-10s %-4s %5d  %6.1f  %6.2f  %10d  %9.1f  %13.1f  %9.1f  %d/%d/%d  %7.2f  %11.2f  %8.1f  %6.1f" % (
            arena, arm, len(seeds), frame, hides, intrusions, longest, hidden_while, yaw, *causes, inside, frame - hides, visible, belly))
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


TICK_RATE = 30
CRUISE = 18.2  # SyndicateAdAirship.ALTITUDE (6.2 belly clearance + 1.15 float + 0.1904 x 57 m)


def _rows(path):
    with open(path) as handle:
        header = handle.readline().strip().split(",")
        for line in handle:
            yield dict(zip(header, (float(v) for v in line.strip().split(","))))


def intrusions(path):
    """Every run of ticks the hull hides the fight, with what led up to it: when the driver last ordered (the camera's
    jump), how far the camera travelled in the 3 s before, how long the view term had been asking for a climb before
    the hull got in the way (the warning the plan had), and how far below the height it wanted the hull was."""
    rows = list(_rows(path))
    out = []
    i = 0
    last_order = -10 ** 9
    orders = [r["tick"] for r in rows if r["order"] > 0]
    while i < len(rows):
        if rows[i]["hidden"] <= 0.0:
            i += 1
            continue
        start = i
        while i < len(rows) and rows[i]["hidden"] > 0.0:
            i += 1
        r = rows[start]
        before = rows[max(0, start - 3 * TICK_RATE)]
        asked = start
        while asked > 0 and rows[asked - 1]["view_need_now"] > CRUISE + 0.5:
            asked -= 1
        prior = [o for o in orders if o <= r["tick"]]
        cam = (r["cam_x"], r["cam_z"])
        out.append({
            "t": r["tick"] / TICK_RATE, "dur": (i - start) / TICK_RATE,
            "peak_hidden": max(x["hidden"] for x in rows[start:i]),
            "since_order": (r["tick"] - prior[-1]) / TICK_RATE if prior else float("nan"),
            "cam_moved": ((r["cam_x"] - before["cam_x"]) ** 2 + (r["cam_z"] - before["cam_z"]) ** 2) ** 0.5,
            "cam_y": r["cam_y"], "cam_dy": r["cam_y"] - before["cam_y"],
            "hull_moved": ((r["hull_x"] - before["hull_x"]) ** 2 + (r["hull_z"] - before["hull_z"]) ** 2) ** 0.5,
            "hull_to_cam": ((r["hull_x"] - cam[0]) ** 2 + (r["hull_z"] - cam[1]) ** 2) ** 0.5,
            "alt": r["alt"], "wanted": r["wanted"], "need_now": r["view_need_now"],
            "warning_s": (start - asked) / TICK_RATE,
            "action_moved": ((r["action_x"] - before["action_x"]) ** 2 + (r["action_z"] - before["action_z"]) ** 2) ** 0.5,
            "orbit": r["orbit"],
        })
    return out


def trace_main(root):
    paths = sorted(glob.glob(os.path.join(root, "*", "*", "trace_*.csv")))
    if not paths:
        print("AIRSHIP_VIEW_TRACE no traces under %s (run with VIEW_TRACE=1)" % root)
        return 1
    print("AIRSHIP_VIEW_TRACE map        arm   seed      t    dur  peak  since_order  cam_moved  cam_y  cam_dy  hull_moved  "
          "hull_to_cam   alt  wanted  need_now  warning_s  action_moved")
    for path in paths:
        seed = os.path.basename(os.path.dirname(path))
        arena, arm = os.path.basename(path)[len("trace_"):-len(".csv")].rsplit("_", 1)
        for x in intrusions(path):
            print("AIRSHIP_VIEW_TRACE %-10s %-5s %4s  %5.1f  %5.1f  %4.2f  %11.1f  %9.0f  %5.1f  %6.1f  %10.0f  %11.0f  %4.1f  %6.1f  %8.1f  %9.1f  %12.0f" % (
                arena, arm, seed, x["t"], x["dur"], x["peak_hidden"], x["since_order"], x["cam_moved"], x["cam_y"],
                x["cam_dy"], x["hull_moved"], x["hull_to_cam"], x["alt"], x["wanted"], x["need_now"], x["warning_s"],
                x["action_moved"]))
    # B2: what the climb bought and cost, tick by tick, against the same hull at cruise (traces with those columns).
    print("AIRSHIP_VIEW_LEDGER map        arm   seed  ticks  seen_clean%  climbing%  climb_for_squads_only%  "
          "saved%(hid_at_cruise,not_now)  cost%(clean_at_cruise,unseen_now)  cost_squads_only%")
    for path in paths:
        rows = list(_rows(path))
        if not rows or "frame_at_cruise" not in rows[0]:
            continue
        seed = os.path.basename(os.path.dirname(path))
        arena, arm = os.path.basename(path)[len("trace_"):-len(".csv")].rsplit("_", 1)
        n = float(len(rows))
        clean = sum(1 for r in rows if r["in_frame"] and r["hidden"] <= 0.0)
        climbing = [r for r in rows if r["alt"] > CRUISE + 0.5]
        squads_only = [r for r in rows if r["view_need_now"] > CRUISE + 0.5 and r["need_live"] <= CRUISE + 0.5]
        saved = sum(1 for r in rows if r["hidden_at_cruise"] > 0.0 and r["hidden"] <= 0.0)
        cost = [r for r in rows if r["frame_at_cruise"] and r["hidden_at_cruise"] <= 0.0 and not r["in_frame"]]
        cost_squads = sum(1 for r in cost if r["need_live"] <= CRUISE + 0.5)
        print("AIRSHIP_VIEW_LEDGER %-10s %-5s %4s  %5d  %10.1f  %9.1f  %22.1f  %29.1f  %31.1f  %17.1f" % (
            arena, arm, seed, n, 100 * clean / n, 100 * len(climbing) / n, 100 * len(squads_only) / n, 100 * saved / n,
            100 * len(cost) / n, 100 * cost_squads / n))
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--trace":
        sys.exit(trace_main(sys.argv[2] if len(sys.argv) > 2 else "build/airship-view"))
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "build/airship-view"))
