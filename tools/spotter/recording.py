#!/usr/bin/env python3
"""Spotter stretch: the same ranking over HIS recordings (the black box, game/match/match_recorder.gd), read directly.

    python3 tools/spotter/recording.py references/round46/playtest/*.jsonl [--top 15] [--team 0]

A recording's census rows ARE his match (no replay, so R47.16's ~11 s replay limit does not apply to the reading; it applies
only to a clip, which would be a staged replay). The census has fewer fields than the feature probe, so only part of the signal
set exists here: no progress toward HIS order's point (straight-line, not route, metres: the census has no route), blocked by a
friendly (phase blocked / yielding), far from its squad (the name's squad part), and hit with no shot back is not knowable (hit
rows name no shooter). Rows are shaped like the probe's and go through the same derive / rank code; tails are per unit class
over the recordings given. Moments carry the recording's own seconds; a moment past ~11 s cannot be clipped exactly.
"""
import argparse
import gzip
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import features as F  # noqa: E402
import rank as R  # noqa: E402


def load(path):
    rows = []
    with (gzip.open(path, "rt") if path.endswith(".gz") else open(path)) as handle:
        for line in handle:
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    return rows


def squad_of(name):
    parts = name.split("_")
    return "_".join(parts[:-1]) if len(parts) > 2 else name


def crew_rows(rec):
    match = next(r for r in rec if r["t"] == "match")
    rate = match.get("tick_rate", 30)
    units = match.get("units", [])
    if isinstance(units, str):
        import ast
        units = ast.literal_eval(units)
    unit_of = {u["name"]: u.get("id", "") for u in units}
    goal = {}
    orders = sorted((r for r in rec if r["t"] == "order" and r.get("to")), key=lambda r: r["tick"])
    hits = [r for r in rec if r["t"] == "hit"]
    out, last, hist = [], {}, {}
    oi = 0
    for census in sorted((r for r in rec if r["t"] == "census"), key=lambda r: r["tick"]):
        tick = census["tick"]
        while oi < len(orders) and orders[oi]["tick"] <= tick:
            for u in orders[oi]["units"]:
                goal[u] = orders[oi]["to"]
                hist[u] = []
            oi += 1
        squads = {}
        for u in census["units"]:
            squads.setdefault((u["team"], squad_of(u["n"])), []).append(u["pos"])
        for u in census["units"]:
            name, (x, z) = u["n"], u["pos"]
            prev = last.get(name)
            speed = 0.0
            if prev:
                dt = (tick - prev[0]) / rate
                speed = math.hypot(x - prev[1], z - prev[2]) / dt if dt > 0 else 0.0
            last[name] = (tick, x, z)
            row = {"t": "crew", "tick": tick, "s": round(tick / rate), "crew": name, "team": u["team"],
                   "unit": unit_of.get(name, "?"), "squad": squad_of(name), "x": x, "z": z, "yaw": 0.0, "speed": speed,
                   "hp": u["hp"], "order": u.get("order", ""), "phase": u.get("phase", ""), "blocked": u.get("blocked", ""),
                   "range": 0.0, "near_enemy": -1.0, "shots": 0, "since_fire": 0}
            g = goal.get(name)
            if g and u.get("order") in ("move", "attack_move", "attack"):
                to_go = math.hypot(g[0] - x, g[1] - z)
                h = hist.setdefault(name, [])
                h.append(to_go)
                row.update({"move": "move_to", "to_go": to_go})
                if len(h) > 5:
                    row["gain_5"] = h[-6] - to_go
            mates = squads[(u["team"], squad_of(name))]
            if len(mates) > 1:
                cx = sum(p[0] for p in mates) / len(mates)
                cz = sum(p[1] for p in mates) / len(mates)
                row.update({"squad_n": len(mates), "squad_d": math.hypot(cx - x, cz - z)})
            row["hit_dmg"] = sum(float(h.get("damage", 0)) for h in hits
                                 if h.get("target") == name and tick - 3 * rate < h["tick"] <= tick)
            out.append(row)
    header = {"seed": match.get("seed", 0), "arena": match.get("arena", "")}
    return header, out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--top", type=int, default=15)
    ap.add_argument("--team", type=int, default=-1, help="only this team's moments (0 = his side in a skirmish)")
    args = ap.parse_args()
    table = []
    for path in args.paths:
        header, rows = crew_rows(load(path))
        name = os.path.basename(path).split(".")[0]
        table.extend(F.derive(header, rows, name))
    R.score_rows(table, R.build_tails(table))
    found = [m for m in R.moments(table) if args.team < 0 or m["team"] == args.team]
    chosen = R.pick(found, args.top, per_fight=6)
    print(f"recordings: {len(table)} crew-seconds from {len(args.paths)} recordings, {len(found)} moments")
    for i, m in enumerate(chosen, 1):
        exact = "exact" if m["end_s"] <= 11 else "staged past 11 s"
        print(f"{i:2d}. {m['score']:5.2f} {m['fight']:28s} {m['crew']:20s} {m['start_s']:4d}-{m['end_s']:<4d} "
              f"{R.reason_line(m)}  [{exact}]")


if __name__ == "__main__":
    main()
