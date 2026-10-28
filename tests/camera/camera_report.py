#!/usr/bin/env python3
"""Round 41 (camera K1): add CameraPlaytest's per-seed camera_trace_<seed>.json files into one table.
Round 42 (camera K4.1): plus the look table (CameraLook: where the view looks against where the danger is), per
scenario and lane. A shooter that never came on screen counts as never (infinite) in the latency quantiles.

usage: camera_report.py DIR [DIR_B]   (two dirs: side by side, e.g. a switch off v on)
"""
import glob
import json
import os
import sys

SOURCES = ["player", "jump", "follow", "order_track", "auto_frame", "yaw_follow", "danger", "cap", "frame", "solid", "hull", "shake",
           "all"]


def quantile(values, q):
    if not values:
        return 0.0
    values = sorted(values)
    return values[max(0, min(len(values) - 1, int(-(-q * len(values) // 1)) - 1))]


def load(directory):
    runs = []
    for path in sorted(glob.glob(os.path.join(directory, "camera_trace_*.json"))):
        with open(path) as f:
            runs.append(json.load(f))
    return runs


def table(runs):
    minutes = sum(r["summary"]["seconds"] for r in runs) / 60.0 or 1e-6
    rows = {}
    for source in SOURCES:
        events = [e for r in runs for e in r["events"] if e["source"] == source]
        rows_of = [(r, r["summary"]["by_source"].get(source)) for r in runs]  # round 41's traces have no "danger"
        rows_of = [(r, row) for r, row in rows_of if row]
        moved = sum(row["px_per_min"] * r["summary"]["seconds"] / 60.0 for r, row in rows_of)
        snaps = sum(row["snaps"] for _, row in rows_of)
        reversals = sum(row["reversals"] for _, row in rows_of)
        dv = [e["dv_px_s"] for e in events]
        rows[source] = {"events": len(events), "per_min": len(events) / minutes, "dv_p50": quantile(dv, 0.5),
                        "dv_p95": quantile(dv, 0.95), "snaps": snaps, "reversals_per_min": reversals / minutes,
                        "px_per_min": moved / minutes}
    clicks = [c for r in runs for c in r["clicks"]]
    slips = [c["slip_px"] for c in clicks]
    attacks = [c for c in clicks if c["kind"] == "attack"]
    by = {}
    for c in clicks:
        for source, px in c.get("by", {}).items():
            by.setdefault(source, []).append(px)
    slip = {"clicks": len(clicks), "attacks": len(attacks), "hit": sum(1 for c in attacks if c.get("hit")),
            "p50": quantile(slips, 0.5), "p95": quantile(slips, 0.95), "max": max(slips) if slips else 0.0,
            "over_10px": sum(1 for s in slips if s > 10.0),
            "by_source_p95": {s: quantile(v, 0.95) for s, v in sorted(by.items())},
            "by_source_clicks": {s: len(v) for s, v in sorted(by.items())}}
    seconds = minutes * 60.0
    held = sum(r["summary"].get("held_s", 0.0) for r in runs)
    action = sum(r["slip"].get("action_s", 0.0) for r in runs)
    play = {"held_pct": 100.0 * held / seconds, "action_pct": 100.0 * action / seconds,
            "aims_per_min": len(attacks) / minutes}
    return {"minutes": minutes, "seeds": [r["seed"] for r in runs], "rows": rows, "slip": slip, "play": play}


def fmt_s(x):
    return "never" if x == float("inf") else f"{x:.1f}"


NEVER_S = 20.0  # R42.5: a shooter never on screen counts as 20 s in Bar K4's latency line


def mean_se(values):
    if not values:
        return 0.0, 0.0
    m = sum(values) / len(values)
    if len(values) < 2:
        return m, 0.0
    var = sum((v - m) ** 2 for v in values) / (len(values) - 1)
    return m, (var / len(values)) ** 0.5


def look_table(runs):
    groups = {}
    for r in runs:
        if "look" not in r:
            continue
        key = (r.get("scenario") or "attack", r.get("lane", "") if r.get("scenario") in ("ambush", "corner") else "")
        groups.setdefault(key, []).append(r)
        if key[1]:
            groups.setdefault((key[0], "all"), []).append(r)
    rows = []
    for key in sorted(groups):
        rs = groups[key]
        looks = [r["look"] for r in rs]
        play = sum(l["play_s"] for l in looks) or 1e-6
        under = sum(l["under_fire_s"] for l in looks)
        blind = sum(l["blind_s"] for l in looks)
        wall = sum(l["wall_s"] for l in looks)
        own = sum(l.get("own_shown_s", 0.0) for l in looks)
        inside = sum(l.get("inside_s", 0.0) for l in looks)
        lat = [x for l in looks for x in l["latencies"]] + [float("inf")] * sum(l["never"] for l in looks)
        minutes = sum(l["minutes"] for l in looks) or 1e-6
        bearing = {}
        for k in ("shooter", "centroid", "middle"):
            vals = [l["mean_abs_bearing"][k] for l in looks if l["mean_abs_bearing"].get(k)]
            bearing[k] = sum(vals) / len(vals) if vals else 0.0
        rows.append({"scenario": key[0], "lane": key[1], "runs": len(rs),
                     "staged": sum(1 for r in rs if r.get("staged", {}).get("ok", key[0] == "attack")),
                     "play_s": play, "under_pct": 100 * under / play, "blind_pct": 100 * blind / play,
                     "blind_of_fire_pct": 100 * blind / under if under else 0.0, "wall_pct": 100 * wall / play, "own_pct": 100 * own / play, "inside_s": inside,
                     "episodes": len(lat), "never": sum(l["never"] for l in looks),
                     "p50": quantile(lat, 0.5), "p90": quantile(lat, 0.9),
                     "capped": mean_se([min(x, NEVER_S) for x in lat]),
                     "reversals_per_min": sum(l["yaw_reversals"] for l in looks) / minutes, "bearing": bearing})
    return rows


def show_look(rows):
    if not rows:
        return
    print("| scenario | lane | runs (staged ok) | play s | under fire % | blind % of play | blind % of fire | facing wall % "
          "| own on screen % | off-screen shots | never | first shot -> on screen p50 / p90 s | mean (never = 20 s) +- se | yaw reversals/min "
          "| mean abs bearing shooter / enemies / middle (deg) | camera inside a solid s |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        b = r["bearing"]
        print(f"| {r['scenario']} | {r['lane']} | {r['runs']} ({r['staged']}) | {r['play_s']:.0f} | {r['under_pct']:.1f} | "
              f"{r['blind_pct']:.1f} | {r['blind_of_fire_pct']:.1f} | {r['wall_pct']:.1f} | {r['own_pct']:.1f} | {r['episodes']} | {r['never']} | "
              f"{fmt_s(r['p50'])} / {fmt_s(r['p90'])} | {r['capped'][0]:.1f} +- {r['capped'][1]:.1f} | {r['reversals_per_min']:.2f} | "
              f"{b['shooter']:.0f} / {b['centroid']:.0f} / {b['middle']:.0f} | {r['inside_s']:.2f} |")
    print()


def corner_table(runs):
    """Round 43 (K5.2): the corner census (CameraCorner) per lane side and pooled."""
    groups = {}
    for r in runs:
        if "corner" not in r:
            continue
        groups.setdefault(r.get("lane", ""), []).append(r)
        groups.setdefault("all", []).append(r)
    rows = []
    for lane in sorted(groups):
        rs = groups[lane]
        cs = [r["corner"] for r in rs]
        corner = sum(c["corner_s"] for c in cs) or 1e-6
        def gaps(key):
            return [c[key] for c in cs if c.get(key) is not None]
        bearings = [c["mean_abs_bearing"] for c in cs if c.get("mean_abs_bearing") is not None]
        rows.append({"lane": lane, "runs": len(rs), "opened": sum(1 for c in cs if c["opened"]),
                     "seen": sum(1 for c in cs if c["seen"]), "shown": sum(1 for c in cs if c["shown"]),
                     "open_seen": mean_se(gaps("open_to_seen_s")), "open_screen": mean_se(gaps("open_to_screen_s")),
                     "seen_screen": mean_se(gaps("seen_to_screen_s")), "corner_s": corner,
                     "facing_pct": 100 * sum(c["facing_s"] for c in cs) / corner,
                     "toward_pct": 100 * sum(c.get("toward_s", 0.0) for c in cs) / corner,
                     "facing_open_pct": 100 * sum(c.get("facing_open_s", 0.0) for c in cs) / (sum(c.get("open_s", 0.0) for c in cs) or 1e-6),
                     "away_pct": 100 * sum(c.get("away_s", 0.0) for c in cs) / corner,
                     "back_pct": 100 * sum(c.get("back_s", 0.0) for c in cs) / corner,
                     "bearing": sum(bearings) / len(bearings) if bearings else 0.0})
    return rows


def show_corner(rows):
    if not rows:
        return
    print("Corner (K5.2): seconds from the corner opening (his first crew past the wall's end) to the hidden squad seen / on "
          "screen, and seen -> on screen (mean +- se; never = 20 s); the corner seconds' share facing the building, within 45 deg "
          "of the uncovering side, and the mean |bearing| from the view to that side.")
    print("| lane | runs (opened / seen / on screen) | open -> seen s | open -> on screen s | seen -> on screen s | corner s "
          "| facing the building % (after it opens %) | toward the hidden side % | mean abs bearing to it (deg) | off the travel > 90 / > 135 deg % |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        print(f"| {r['lane']} | {r['runs']} ({r['opened']} / {r['seen']} / {r['shown']}) | "
              f"{r['open_seen'][0]:.1f} +- {r['open_seen'][1]:.1f} | {r['open_screen'][0]:.1f} +- {r['open_screen'][1]:.1f} | "
              f"{r['seen_screen'][0]:.1f} +- {r['seen_screen'][1]:.1f} | {r['corner_s']:.0f} | {r['facing_pct']:.1f} ({r['facing_open_pct']:.1f}) | "
              f"{r['toward_pct']:.1f} | {r['bearing']:.0f} | {r['away_pct']:.1f} / {r['back_pct']:.1f} |")
    print()


def show(name, t):
    print(f"## {name}: {len(t['seeds'])} seeds {t['seeds']}, {t['minutes']:.1f} min of play\n")
    print("| source | jerk events | per min | dv p50 (px/s) | dv p95 | snaps | reversals/min | px moved/min |")
    print("|---|---|---|---|---|---|---|---|")
    for source, row in t["rows"].items():
        if row["events"] == 0 and row["px_per_min"] < 1.0:
            continue
        print(f"| {source} | {row['events']} | {row['per_min']:.2f} | {row['dv_p50']:.0f} | {row['dv_p95']:.0f} | {row['snaps']} | "
              f"{row['reversals_per_min']:.2f} | {row['px_per_min']:.0f} |")
    s = t["slip"]
    print(f"\nTarget slip (px at 1080 rows, the ground under the cursor over the {0.5} s before a click): clicks {s['clicks']} "
          f"(attacks {s['attacks']}, still on the unit {s['hit']}), p50 {s['p50']:.1f}, p95 {s['p95']:.1f}, max {s['max']:.1f}, "
          f"over 10 px {s['over_10px']}")
    print("Slip by source (p95 px over the clicks it touched / clicks): " +
          ", ".join(f"{k} {v:.1f}/{s['by_source_clicks'][k]}" for k, v in s["by_source_p95"].items()))
    p = t["play"]
    print(f"Play: camera held for his aim {p['held_pct']:.1f} % of play; an aimable enemy on screen {p['action_pct']:.1f} % "
          f"(the action share); attack aims {p['aims_per_min']:.2f} / min")
    print()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    for directory in sys.argv[1:]:
        runs = load(directory)
        if not runs:
            print(f"no camera_trace_*.json in {directory}")
            return 1
        show(directory, table(runs))
        show_look(look_table(runs))
        show_corner(corner_table(runs))
    return 0


if __name__ == "__main__":
    sys.exit(main())
