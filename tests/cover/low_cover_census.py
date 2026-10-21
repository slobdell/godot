#!/usr/bin/env python3
"""K1 (cover, round 37): the low cover on every dealt map, and how much of the fighting happens beside it.

    python3 tests/cover/low_cover_census.py [--heat build/cover-heat] [--json out.json]

LOW cover = a colliding feature lower than Perception.EYE_HEIGHT (1.3 m): today only the jersey `barricade` (0.9 m). A hull
behind it shows everything above 0.9 m; everything taller (wreck 2.0 m, containers 2.59 m, walls/crates 3 m) blocks sight
and is all-or-nothing cover already (TacticalQuery.hull_hidden).

Per piece: its length, which way it faces (FRONTAL = its long side faces the base axis z within 45 deg, so a crew behind it
faces the enemy's half; FLANK = it runs along the axis), and its distance to the nearest lane centreline and to the centre.
A RUN is pieces end to end (< 1.5 m apart). RE-SHAPE SOURCES are the clutter near the fighting that could become low cover
without adding anything: lone single-level container_20s and wrecks within 20 m of a lane.

--heat reads COMBAT_EVENT logs (tests/cover/heat.sh): every direct hit on a hull, with the target's position from the
nearest `poses` sample; reports the share of hits on hulls within SEAT_M of a low piece (where a crew could have been
hull-down), and the hit density per 10 m cell for the page.
"""
import argparse, glob, json, math, os, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EYE = 1.3
SEAT_M = 4.0   # a hull this close to a low piece counts as "beside it" (C37.4's max_shift_m)
SIZES = {"barricade": (6.0, 0.9, 0.8), "wreck": (3.2, 2.0, 3.3), "container_20": (6.06, 2.59, 2.44),
         "container_40": (12.19, 2.59, 2.44)}


def dealt():
    src = (ROOT / "game/arena/arena.gd").read_text()
    default = re.search(r'const DEFAULT_LAYOUT := "(\w+)"', src).group(1)
    rotation = re.findall(r'"(\w+)"', re.search(r"const ROTATION := \[(.*?)\]", src).group(1))
    return [default] + rotation


def seg_dist(p, a, b):
    ax, az = a; bx, bz = b; px, pz = p
    dx, dz = bx - ax, bz - az
    L = dx * dx + dz * dz
    t = 0.0 if L == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / L))
    return math.hypot(px - ax - t * dx, pz - az - t * dz)


def lane_dist(p, lanes):
    best = 1e9
    for lane in lanes:
        pts = lane["points"]
        for a, b in zip(pts, pts[1:]):
            best = min(best, seg_dist(p, a, b))
    return best


def footprint_dist(p, piece):
    """Distance from p (x, z) to the piece's rotated rectangle (ArenaKit.distance_to_footprint)."""
    ang = math.radians(piece["rot"])
    dx, dz = p[0] - piece["pos"][0], p[1] - piece["pos"][1]
    lx = dx * math.cos(ang) - dz * math.sin(ang)
    lz = dx * math.sin(ang) + dz * math.cos(ang)
    ox = max(abs(lx) - piece["size"][0] / 2, 0.0)
    oz = max(abs(lz) - piece["size"][2] / 2, 0.0)
    return math.hypot(ox, oz)


def low_pieces(layout):
    out = []
    for o in layout.get("obstacles", []):
        size = o.get("size", {"crate": [4.5, 3.0, 4.5], "wall": [18.0, 3.0, 1.5]}.get(o["type"], [1, 1, 1]))
        if size[1] < EYE:
            out.append({"type": o["type"], "pos": o["position"], "rot": float(o.get("rotation_deg", 0.0)), "size": size})
    for p in layout.get("props", []):
        if p["type"] == "barricade":
            out.append({"type": "barricade", "pos": p["position"], "rot": float(p.get("rotation_deg", 0.0)),
                        "size": list(SIZES["barricade"])})
    return out


def facing(rot):
    # long axis along local x -> world (cos, -sin) in (x, z); FRONTAL when that axis is within 45 deg of world x.
    along_x = abs(math.cos(math.radians(rot)))
    return "frontal" if along_x >= math.cos(math.radians(45)) else "flank"


def runs(pieces):
    n = len(pieces); parent = list(range(n))
    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i = parent[i]
        return i
    for i in range(n):
        for j in range(i + 1, n):
            a, b = pieces[i], pieces[j]
            if math.dist(a["pos"], b["pos"]) < (a["size"][0] + b["size"][0]) / 2 + 1.5:
                parent[find(i)] = find(j)
    groups = {}
    for i in range(n):
        groups.setdefault(find(i), []).append(i)
    return list(groups.values())


def reshape_sources(layout):
    lanes = layout.get("lanes", [])
    out = []
    for p in layout.get("props", []):
        if (p["type"] == "container_20" and int(p.get("stack", 1)) == 1) or p["type"] == "wreck":
            d = lane_dist(p["position"], lanes) if lanes else math.hypot(*p["position"])
            if d <= 20.0:
                out.append({"type": p["type"], "pos": p["position"], "rot": p.get("rotation_deg", 0.0),
                            "lane_m": round(d, 1)})
    return out


def read_heat(heat_dir, name):
    hits = []
    for log in sorted(glob.glob(os.path.join(heat_dir, f"{name}-*.log"))):
        poses = {}
        pending = []
        for line in open(log, errors="replace"):
            if not line.startswith("COMBAT_EVENT "):
                continue
            ev = json.loads(line[len("COMBAT_EVENT "):])
            kind = ev.get("event") or ev.get("kind")
            if kind == "poses":
                poses = {u["name"]: (u["x"], u["z"]) for u in ev["units"]}
            elif kind == "impact" and ev.get("target") and float(ev.get("damage", 0.0)) > 0.0:
                at = poses.get(ev["target"])
                if at is None:
                    at = (ev["position"][0], ev["position"][2])
                hits.append({"pos": at, "face": ev.get("face", "")})
    return hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--heat", default="")
    ap.add_argument("--json", default="")
    args = ap.parse_args()
    report = {}
    for name in dealt():
        layout = json.load(open(ROOT / "arenas" / f"{name}.json"))
        lanes = layout.get("lanes", [])
        pieces = low_pieces(layout)
        for piece in pieces:
            piece["facing"] = facing(piece["rot"])
            piece["lane_m"] = round(lane_dist(piece["pos"], lanes), 1) if lanes else None
            piece["centre_m"] = round(math.hypot(*piece["pos"]), 1)
        grouped = runs(pieces)
        row = {"low_pieces": len(pieces), "low_length_m": round(sum(p["size"][0] for p in pieces), 1),
               "runs": len(grouped), "frontal": sum(p["facing"] == "frontal" for p in pieces),
               "near_lane": sum(1 for p in pieces if p["lane_m"] is not None and p["lane_m"] <= 15.0),
               "pieces": pieces, "reshape_sources": reshape_sources(layout)}
        if args.heat:
            hits = read_heat(args.heat, name)
            beside = [h for h in hits if any(footprint_dist(h["pos"], p) <= SEAT_M for p in pieces)]
            front = [h for h in hits if h["face"] == "front"]
            row["heat"] = {"hull_hits": len(hits), "beside_low_cover": len(beside),
                           "beside_share": round(len(beside) / len(hits), 3) if hits else None,
                           "front_share": round(len(front) / len(hits), 3) if hits else None,
                           "cells": _cells(hits)}
        report[name] = row
    print(f"{'map':<12} {'low':>4} {'len_m':>6} {'runs':>4} {'front':>5} {'lane<=15':>8} {'reshape':>7}"
          + (f" {'hits':>6} {'beside':>7}" if args.heat else ""))
    for name, r in report.items():
        line = (f"{name:<12} {r['low_pieces']:>4} {r['low_length_m']:>6} {r['runs']:>4} {r['frontal']:>5} {r['near_lane']:>8}"
                f" {len(r['reshape_sources']):>7}")
        if args.heat:
            h = r["heat"]
            line += f" {h['hull_hits']:>6} {h['beside_share'] if h['beside_share'] is not None else '-':>7}"
        print(line)
    if args.json:
        Path(args.json).parent.mkdir(parents=True, exist_ok=True)
        Path(args.json).write_text(json.dumps(report, indent=1))


def _cells(hits, cell=10.0):
    out = {}
    for h in hits:
        key = f"{int(math.floor(h['pos'][0] / cell))},{int(math.floor(h['pos'][1] / cell))}"
        out[key] = out.get(key, 0) + 1
    return out


if __name__ == "__main__":
    main()
