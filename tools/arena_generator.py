#!/usr/bin/env python3
"""Arena stretch: propose layout candidates for a human to approve (_agents/arenas.md "Proposing layouts").

A candidate is half a layout of arena-kit pieces plus its 180-degree mirror, so it is point-symmetric by construction.
Hard constraints: every piece inside the field and clear of the spawn zones, no two pieces overlapping, both bases
connected to each other and to the centre, and three distinct routes (west, centre, east) all drivable. Within those,
a hill climb moves, turns, stacks, adds and removes pieces toward a CHARACTER's targets, measured the same way as
`make arena-report` (view distance from the field, cover pieces near each point).

Nothing is shipped: candidates go to build/arena-candidates/<character>_<n>.json with a plot each and an index.html
to look through. A candidate someone likes is copied into tools/make_arenas.py by hand, named, and then proven like
any arena (make arena-series).

Usage: python3 tools/arena_generator.py [--character yard|boulevard|pit|open] [--count 3] [--steps 400] [--seed 1]
"""
import argparse, copy, html, json, math, os, random, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import arena_report as report  # noqa: E402

HALF = report.HALF
FIELD_Z = report.FIELD_Z
SPAWN_Z = 80.0  # nothing south of this inside the spawn zone's width (Arena.SPAWN_CLEARANCE from the z = 90 row)
SPAWN_HALF_WIDTH = 74.0
KINDS = ["container_20", "container_40", "wreck", "barricade"]

## Targets per character: mean eye-level view (m), share of views >= 120 m, pieces (half layout), and the weight of each.
CHARACTERS = {
    # per_group: sight-blocking pieces per merged piece of cover (arena_report.cover_groups). View distance alone gets
    # met by confetti (tried first: 84 scattered boxes hit the yard's 45 m exactly and had no lanes at all); walls are
    # what make lanes, so a yard wants ~2 pieces a group, a boneyard ~1.
    "yard": {"mean_view": 45.0, "long_views": 0.06, "per_group": 2.2, "pieces": (28, 48), "kinds": [0.35, 0.45, 0.15, 0.05]},
    "boneyard": {"mean_view": 60.0, "long_views": 0.13, "per_group": 1.1, "pieces": (22, 36), "kinds": [0.35, 0.2, 0.4, 0.05]},
    "boulevard": {"mean_view": 72.0, "long_views": 0.21, "per_group": 2.0, "pieces": (18, 32), "kinds": [0.25, 0.25, 0.15, 0.35]},
    "open": {"mean_view": 85.0, "long_views": 0.3, "per_group": 1.0, "pieces": (8, 18), "kinds": [0.3, 0.2, 0.4, 0.1]},
}
STACKS = {"container_20": 3, "container_40": 3, "wreck": 1, "barricade": 1}


def piece(rng, kinds):
    kind = rng.choices(KINDS, weights=kinds)[0]
    return {"type": kind, "position": [round(rng.uniform(-110, 110), 1), round(rng.uniform(4, SPAWN_Z - 2), 1)],
            "rotation_deg": float(rng.choice([0, 90, 0, 90, rng.uniform(0, 180)])), "stack": rng.randint(1, STACKS[kind])}


def layout_of(name, half):
    props = []
    for p in half:
        props.append(clean(p))
        m = clean(p)
        m["position"] = [-p["position"][0], -p["position"][1]]
        m["rotation_deg"] = round((p["rotation_deg"] + 180.0) % 360.0, 3)
        props.append(m)
    spawns = {"green": [], "rust": []}
    for row in range(4):
        for x in [0.0, -11.0, 11.0, -22.0, 22.0, -33.0, 33.0, -44.0, 44.0, -55.0, 55.0, -66.0, 66.0]:
            spawns["green"].append([x, 90.0 + row * 8.0])
            spawns["rust"].append([-x if x else 0.0, -(90.0 + row * 8.0)])
    return {"name": name, "schema": 2, "half_size": 120.0, "obstacles": [], "props": props, "spawns": spawns,
            "spawn_zones": {"green": {"center": [0.0, 102.0], "size": [150.0, 32.0]},
                            "rust": {"center": [0.0, -102.0], "size": [150.0, 32.0]}},
            "lanes": [], "regions": [], "control_point": {"radius": 16.0}}


def clean(p):
    out = {"type": p["type"], "position": [round(p["position"][0], 2), round(p["position"][1], 2)],
           "rotation_deg": round(p["rotation_deg"], 3)}
    if p.get("stack", 1) > 1:
        out["stack"] = p["stack"]
    return out


def valid(layout):
    boxes = report.boxes_of(layout)
    for b in boxes:
        corners = b.corners()
        if any(abs(x) > report.DRIVABLE - 1 or abs(z) > report.DRIVABLE - 1 for x, z in corners):
            return False
        for x, z in layout["spawns"]["green"] + layout["spawns"]["rust"]:
            if b.distance(x, z) < 6.0:
                return False
        if b.distance(0.0, 0.0) < 17.0:  # keep the control ring drivable
            return False
    for i, a in enumerate(boxes):
        for b in boxes[i + 1:]:
            if math.hypot(a.x - b.x, a.z - b.z) < (max(a.w, a.d) + max(b.w, b.d)) / 2 and \
                    (a.distance(b.x, b.z) < 0.2 or b.distance(a.x, a.z) < 0.2):
                return False  # one's centre inside the other: a real overlap (end-to-end runs only touch)
    return connected(boxes)


def occupancy(boxes, cell=1.0):
    """arena_report.occupancy, vectorized: True where a vehicle's centre can't be (within the nav agent radius)."""
    n = int(2 * HALF / cell)
    centres = (np.arange(n) + 0.5) * cell - HALF
    gx, gz = np.meshgrid(centres, centres)  # [z, x]
    blocked = np.zeros((n, n), dtype=bool)
    for b in boxes:
        reach = max(b.w, b.d) / 2 + report.AGENT_RADIUS + 1
        x0, x1 = max(0, int((b.x - reach + HALF) / cell)), min(n, int((b.x + reach + HALF) / cell) + 1)
        z0, z1 = max(0, int((b.z - reach + HALF) / cell)), min(n, int((b.z + reach + HALF) / cell) + 1)
        dx, dz = gx[z0:z1, x0:x1] - b.x, gz[z0:z1, x0:x1] - b.z
        lx, lz = dx * b.c - dz * b.s, dx * b.s + dz * b.c
        ox, oz = np.maximum(np.abs(lx) - b.w / 2, 0), np.maximum(np.abs(lz) - b.d / 2, 0)
        blocked[z0:z1, x0:x1] |= np.hypot(ox, oz) < report.AGENT_RADIUS
    edge = int((HALF - report.DRIVABLE) / cell)
    blocked[:edge, :] = blocked[-edge:, :] = blocked[:, :edge] = blocked[:, -edge:] = True
    return blocked


def connected(boxes):
    """Both bases, the centre, and a strip down each flank are one drivable region (4-connected components)."""
    from scipy import ndimage
    blocked = occupancy(boxes)
    labels, _ = ndimage.label(~blocked)
    at = lambda x, z: labels[int(z + HALF), int(x + HALF)]
    base = at(0.0, 90.0)
    if base == 0 or at(0.0, -90.0) != base or at(0.0, 0.0) != base:
        return False
    for x in (-100.0, 100.0):
        # a flank is open when its column of cells, x +- 10 m, has a drivable cell of the base's region at every z
        strip = labels[int(-FIELD_Z + HALF):int(FIELD_Z + HALF), int(x - 10 + HALF):int(x + 10 + HALF)]
        if not (strip == base).any(axis=1).all():
            return False
    return True


def views(layout, spacing=16.0, rays=12):
    """A coarser, vectorized arena_report.view_distances: mean view and share of views >= 120 m."""
    tall = [b for b in report.boxes_of(layout) if b.h >= report.EYE_HEIGHT]
    points = [(x, z) for z in np.arange(-FIELD_Z, FIELD_Z + 1, spacing) for x in np.arange(-112, 113, spacing)
              if all(b.distance(x, z) > 0.5 for b in tall)]
    if not points:
        return 0.0, 0.0
    cx = np.array([b.x for b in tall]); cz = np.array([b.z for b in tall])
    cc = np.array([b.c for b in tall]); ss = np.array([b.s for b in tall])
    hw = np.array([b.w / 2 for b in tall]); hd = np.array([b.d / 2 for b in tall])
    lengths = []
    for x, z in points:
        for r in range(rays):
            a = 2 * math.pi * r / rays
            dx, dz = math.cos(a), math.sin(a)
            reach = report.VIEW_RANGE
            for limit, d in ((report.DRIVABLE - x, dx), (-report.DRIVABLE - x, dx), (report.DRIVABLE - z, dz), (-report.DRIVABLE - z, dz)):
                if abs(d) > 1e-9 and limit / d > 0:
                    reach = min(reach, limit / d)
            bx, bz = x + dx * reach, z + dz * reach
            # slab test against every box at once, in each box's local frame
            ax_, az_ = (x - cx) * cc - (z - cz) * ss, (x - cx) * ss + (z - cz) * cc
            qx = (bx - cx) * cc - (bz - cz) * ss - ax_
            qz = (bx - cx) * ss + (bz - cz) * cc - az_
            with np.errstate(divide="ignore", invalid="ignore"):
                t0 = np.zeros(len(tall)); t1 = np.ones(len(tall)); ok = np.ones(len(tall), dtype=bool)
                for p, q, h in ((ax_, qx, hw), (az_, qz, hd)):
                    flat = np.abs(q) < 1e-9
                    ok &= ~(flat & (np.abs(p) > h))
                    ta = np.where(flat, -np.inf, (-h - p) / np.where(flat, 1, q))
                    tb = np.where(flat, np.inf, (h - p) / np.where(flat, 1, q))
                    t0 = np.maximum(t0, np.minimum(ta, tb)); t1 = np.minimum(t1, np.maximum(ta, tb))
                hit = ok & (t0 <= t1)
            t = t0[hit].min() if hit.any() else 1.0
            lengths.append(reach * t)
    lengths = np.array(lengths)
    return float(lengths.mean()), float((lengths >= 120.0).mean())


def score(layout, target):
    mean_view, long_views = views(layout)
    boxes = report.boxes_of(layout)
    hard = sum(1 for b in boxes if b.h >= report.EYE_HEIGHT)
    per_group = hard / max(1, len(report.cover_groups(boxes)))
    total = abs(mean_view - target["mean_view"]) / 10.0 + abs(long_views - target["long_views"]) * 10.0 \
        + abs(per_group - target["per_group"]) * 2.0
    return total, mean_view, long_views, per_group


def mutate(rng, half, target):
    half = copy.deepcopy(half)
    lo, hi = target["pieces"]
    move = rng.random()
    if (move < 0.15 and len(half) < hi) or len(half) < lo:
        half.append(piece(rng, target["kinds"]))
    elif move < 0.25 and len(half) > lo:
        half.pop(rng.randrange(len(half)))
    elif move < 0.4 and len(half) < hi:
        # Extend a container end to end: how walls (and so lanes) get built.
        base = rng.choice([q for q in half if q["type"].startswith("container")] or half)
        length = {"container_20": 6.06, "container_40": 12.19}.get(base["type"], 6.4)
        a = math.radians(base["rotation_deg"])
        side = rng.choice([-1, 1])
        grown = copy.deepcopy(base)
        grown["position"] = [round(base["position"][0] + side * math.cos(a) * (length - 0.05), 2),
                             round(base["position"][1] - side * math.sin(a) * (length - 0.05), 2)]
        half.append(grown)
    else:
        p = rng.choice(half)
        if move < 0.7:
            p["position"] = [round(p["position"][0] + rng.gauss(0, 8), 1), round(min(SPAWN_Z - 2, max(2, p["position"][1] + rng.gauss(0, 8))), 1)]
        elif move < 0.85:
            p["rotation_deg"] = float(rng.choice([0, 90, (p["rotation_deg"] + rng.gauss(0, 25)) % 180]))
        else:
            p["stack"] = rng.randint(1, STACKS[p["type"]])
    return half


def search(character, index, steps, seed):
    target = CHARACTERS[character]
    rng = random.Random(seed * 1000 + index)
    name = "%s_%d" % (character, index + 1)
    half = []
    while True:
        half = [piece(rng, target["kinds"]) for _ in range(rng.randint(*target["pieces"]))]
        if valid(layout_of(name, half)):
            break
    best, best_score = half, score(layout_of(name, half), target)
    for step in range(steps):  # a piece extended end to end touches its neighbour: allowed below
        candidate = mutate(rng, best, target)
        layout = layout_of(name, candidate)
        if not valid(layout):
            continue
        s = score(layout, target)
        if s[0] <= best_score[0]:
            best, best_score = candidate, s
    layout = layout_of(name, best)
    layout["note"] = "Generated candidate (%s): mean view %.0f m (target %.0f), views >= 120 m %.0f%% (target %.0f%%), " \
        "%.1f pieces per cover group (target %.1f). Not shipped: a human approves it first." % (
            character, best_score[1], target["mean_view"], best_score[2] * 100, target["long_views"] * 100, best_score[3], target["per_group"])
    return layout, best_score


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--character", default="yard", choices=sorted(CHARACTERS))
    parser.add_argument("--count", type=int, default=3)
    parser.add_argument("--steps", type=int, default=400)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--out", default="build/arena-candidates")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    rows = []
    for index in range(args.count):
        layout, (s, mean_view, long_views, per_group) = search(args.character, index, args.steps, args.seed)
        path = os.path.join(args.out, layout["name"] + ".json")
        with open(path, "w") as f:
            f.write(json.dumps(layout, indent=1) + "\n")
        analysed = report.analyze(layout)
        plot = report.plot(layout, analysed, args.out)
        print("ARENA_CANDIDATE " + json.dumps({"name": layout["name"], "score": round(s, 3), "mean_view_m": round(mean_view, 1),
                                               "long_views": round(long_views, 3), "per_group": round(per_group, 2), "pieces": len(layout["props"]),
                                               "report_mean_view_m": analysed["mean_view_m"], "json": path}))
        rows.append((layout, analysed, os.path.basename(plot)))
    with open(os.path.join(args.out, "index.html"), "a") as f:
        for layout, analysed, plot in rows:
            f.write("<section style='font-family:sans-serif;margin:2em'><h2>%s</h2><p>%s</p><p>mean view %s m, "
                    "views >= 120 m %d%%, %d pieces, base to base %s m</p><img src='%s' width='640'></section>\n" % (
                        html.escape(layout["name"]), html.escape(layout["note"]), analysed["mean_view_m"],
                        round(analysed["views_over_120m"] * 100), len(layout["props"]), analysed["base_to_base_m"], plot))


if __name__ == "__main__":
    sys.exit(main())
