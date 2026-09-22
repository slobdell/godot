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


# ---- R4 lanes with the terrain in them (round 10) -------------------------------------------------------------
# `arena_report.lane_table` models no terrain (its own docstring says so) and `ArenaLanes` sees the carved water but
# not the rims and bridge rails. A terrain map's lanes run along banks and over decks, so this measures them with
# all three: the carved ground, the rims, the rails. Used while AUTHORING (`terrain_maps.check_terrain` refuses a
# failing lane); `tests/test_arena_lanes.gd` stays the assertion.

def _free_ray(layout, boxes, walls, poly, px, pz, dx, dz, reach=60.0, step=0.25):
    far = reach
    for b in boxes:
        t = A.entry_t(b, px, pz, px + dx * reach, pz + dz * reach)
        if t is not None:
            far = min(far, t * reach)
    far = min(far, A._ray_exit_polygon(poly, px, pz, dx, dz, reach))
    terrain = layout.get("terrain", [])
    for w in walls:
        box = A.Box("rim", w[0], w[1], 0.0, [w[2], 0.9, w[3]])
        t = A.entry_t(box, px, pz, px + dx * reach, pz + dz * reach)
        if t is not None:
            far = min(far, t * reach)
    d = 0.0
    while d < far:
        if arena_terrain.in_water(terrain, px + dx * d, pz + dz * d):
            return d
        d += step
    return far


def lanes_with_terrain(layout, step=1.0):
    bar = A.lane_bar()
    A.use_extent(layout)
    boxes = A.boxes_of(layout)
    walls = arena_terrain.walls(layout.get("terrain", []))
    poly = A.perimeter_polygon(layout)
    out = []
    for lane in layout.get("lanes", []):
        pts = lane["points"]
        narrow, at = 1e9, None
        for i in range(1, len(pts)):
            (ax, az), (bx, bz) = pts[i - 1], pts[i]
            leg = math.hypot(bx - ax, bz - az)
            ux, uz = (bx - ax) / leg, (bz - az) / leg
            for k in range(max(1, math.ceil(leg / step)) + 1):
                px, pz = ax + ux * leg * k / math.ceil(leg / step), az + uz * leg * k / math.ceil(leg / step)
                w = (_free_ray(layout, boxes, walls, poly, px, pz, -uz, ux)
                     + _free_ray(layout, boxes, walls, poly, px, pz, uz, -ux))
                if w < narrow:
                    narrow, at = w, (round(px, 1), round(pz, 1))
        drivable = narrow - 2 * bar["bake_radius_m"]
        corners = []
        for i in range(1, len(pts) - 1):
            a0 = math.atan2(pts[i][1] - pts[i - 1][1], pts[i][0] - pts[i - 1][0])
            a1 = math.atan2(pts[i + 1][1] - pts[i][1], pts[i + 1][0] - pts[i][0])
            delta = abs(math.remainder(a1 - a0, 2 * math.pi))
            r_eff = bar["physical_bar_m"] / 2 + bar["rig_min_turn_m"] * (1 / math.cos(delta / 2) - 1)
            x, z = pts[i]
            clear = min([b.distance(x, z) for b in boxes] + [arena_terrain._rect_distance(w, x, z) for w in walls] + [60.0])
            r = 0.25
            while r < clear:
                if any(arena_terrain.in_water(layout.get("terrain", []), x + math.cos(2 * math.pi * k / 32) * r,
                                              z + math.sin(2 * math.pi * k / 32) * r) for k in range(32)):
                    clear = r
                    break
                r += 0.25
            corners.append({"at": pts[i], "delta_deg": round(math.degrees(delta), 1), "r_eff": round(r_eff, 2),
                            "clear": round(clear, 2), "pass": clear >= r_eff - 0.001})
        out.append({"name": lane["name"], "narrowest_physical_m": round(narrow, 2), "drivable_m": round(drivable, 2),
                    "at": at, "pass": drivable >= bar["drivable_bar_m"] - 0.001, "corners": corners})
    return out
