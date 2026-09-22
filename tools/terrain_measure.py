"""Terrain maps' own figures beside `arena_report`'s (terrain stream, round 10).

`centre_sees_share` puts its eye at the drivable point nearest the centre, but `arena_report.standing_point` only
looks 12 m out: on a map whose centre is a 40 m building the eye stays INSIDE the building and the map scores 0.00,
which reads as a perfect score and is an artifact (the same shape as the instrument's own first bug, the foundry
crate). So this reports the share from the nearest drivable point in each of the eight directions round the centre,
and their mean -- a figure that cannot be won by standing inside a wall.

Usage: python3 tools/terrain_measure.py arenas/pits.json [...]
"""
import json
import math
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import arena_report as A
import arena_terrain


def ring_eyes(blocked, n, reach_m=80.0):
    eyes = []
    for k in range(8):
        a = 2 * math.pi * k / 8
        r = 0.0
        while r <= reach_m:
            x, z = math.cos(a) * r, math.sin(a) * r
            if not blocked[int((z + A.HALF) / A.GRID) * n + int((x + A.HALF) / A.GRID)]:
                eyes.append((round(x, 1), round(z, 1)))
                break
            r += 1.0
    return eyes


def measure(layout):
    A.use_extent(layout)
    boxes = A.boxes_of(layout)
    blocked, n = A.occupancy(boxes)
    arena_terrain.carve(blocked, n, layout, A.HALF, A.GRID, A.AGENT_RADIUS)
    grid, gn = A.sight_grid(boxes)
    points = A.field_points(blocked, n, 6.0, A.CALIBRATION_HALF)
    eyes = ring_eyes(blocked, n)
    shares = [A.visible_share(grid, gn, e, points) for e in eyes]
    green, rust = tuple(layout["spawns"]["green"][0]), tuple(layout["spawns"]["rust"][0])
    plain = {}
    for o in layout.get("objectives", []):
        at = tuple(o["position"])
        mine, theirs = A.route(blocked, n, green, at), A.route(blocked, n, rust, at)
        plain[o["name"]] = {"green_m": round(A.length(mine), 1) if mine else None,
                            "rust_m": round(A.length(theirs), 1) if theirs else None}
    return {"name": layout["name"], "centre_ring_eyes": eyes,
            "centre_ring_sees_mean": round(sum(shares) / len(shares), 3) if shares else None,
            "centre_ring_sees_max": round(max(shares), 3) if shares else None,
            "objective_routes_plain": plain}


if __name__ == "__main__":
    for path in sys.argv[1:]:
        print("TERRAIN_MEASURE " + json.dumps(measure(json.load(open(path)))))
