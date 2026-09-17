#!/usr/bin/env python3
"""Static analysis and top-down plots of arena layouts (arena X2/X4; _agents/arenas.md "How we test that a map delivers").

Mirrors the game's rules closely enough to iterate on a layout in seconds, never instead of the game's own checks
(Arena.validate, the navmesh test, match series):
  - sight: anything at or above EYE_HEIGHT (1.3 m) blocks an eye-level ray (Perception)
  - driving: obstacles grown by the nav agent radius (2 m) on a 1 m grid
  - doctrine terrain: cover features within 45 m (0-1 open, 2-4 lanes, 5+ dense; ElementSituation)

Usage:
  python3 tools/arena_report.py arenas/yard.json [...]          text report
  python3 tools/arena_report.py --plot build/arenas arenas/*.json  also a PNG per layout
  python3 tools/arena_report.py --json build/arenas/report.json arenas/*.json
"""
import argparse, heapq, json, math, os, sys

EYE_HEIGHT = 1.3
AGENT_RADIUS = 2.0
HALF = 120.0
DRIVABLE = 116.0
TERRAIN_RADIUS = 45.0
SUPPORT_RANGE = 85.0
GRID = 1.0
## The contested field: in front of both spawn zones (front rows at z = +-90). Sightlines are measured inside it.
FIELD_Z = 84.0
KIT = {  # ArenaKit.PROPS (game/arena/arena_kit.gd): one level [x, height, z], cover, collides
    "container_20": ([6.06, 2.59, 2.44], "hard", True),
    "container_40": ([12.19, 2.59, 2.44], "hard", True),
    "ad_screen": ([7.4, 1.4, 1.4], "hard", True),
    "barricade": ([6.0, 0.9, 0.8], "low", True),
    "wreck": ([3.2, 2.0, 6.4], "hard", True),
    "floodlight": ([2.4, 3.0, 2.4], "hard", True),
    "sign": ([0.4, 6.0, 0.4], "none", False),
}
LEGACY = {"crate": [4.5, 3.0, 4.5], "wall": [18.0, 3.0, 1.5]}


class Box:
    def __init__(self, kind, x, z, rot_deg, size):
        self.kind, self.x, self.z = kind, x, z
        self.w, self.h, self.d = size
        a = math.radians(rot_deg)
        self.c, self.s = math.cos(a), math.sin(a)

    def local(self, px, pz):
        dx, dz = px - self.x, pz - self.z
        return dx * self.c - dz * self.s, dx * self.s + dz * self.c

    def distance(self, px, pz):
        lx, lz = self.local(px, pz)
        ox, oz = max(abs(lx) - self.w / 2, 0.0), max(abs(lz) - self.d / 2, 0.0)
        return math.hypot(ox, oz)

    def corners(self):
        out = []
        for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            lx, lz = sx * self.w / 2, sz * self.d / 2
            # Basis(UP, a): local x -> (cos, -sin), local z -> (sin, cos)
            out.append((self.x + lx * self.c + lz * self.s, self.z - lx * self.s + lz * self.c))
        return out

    def segment_hits(self, ax, az, bx, bz):
        """Slab test of segment a-b against the box in its local frame."""
        lax, laz = self.local(ax, az)
        lbx, lbz = self.local(bx, bz)
        t0, t1 = 0.0, 1.0
        for p, q, half in ((lax, lbx - lax, self.w / 2), (laz, lbz - laz, self.d / 2)):
            if abs(q) < 1e-9:
                if abs(p) > half:
                    return False
                continue
            ta, tb = (-half - p) / q, (half - p) / q
            if ta > tb:
                ta, tb = tb, ta
            t0, t1 = max(t0, ta), min(t1, tb)
            if t0 > t1:
                return False
        return True


def boxes_of(layout):
    boxes = []
    for o in layout.get("obstacles", []):
        if o.get("kit"):
            continue
        boxes.append(Box(o["type"], o["position"][0], o["position"][1], o.get("rotation_deg", 0.0), o.get("size", LEGACY.get(o["type"]))))
    for p in layout.get("props", []):
        size, _, collides = KIT[p["type"]]
        if collides:
            boxes.append(Box(p["type"], p["position"][0], p["position"][1], p.get("rotation_deg", 0.0),
                             [size[0], size[1] * p.get("stack", 1), size[2]]))
    return boxes


def entry_t(box, ax, az, bx, bz):
    """Where segment a-b first enters the box, as a fraction of its length, or None."""
    lax, laz = box.local(ax, az)
    lbx, lbz = box.local(bx, bz)
    t0, t1 = 0.0, 1.0
    for p, q, half in ((lax, lbx - lax, box.w / 2), (laz, lbz - laz, box.d / 2)):
        if abs(q) < 1e-9:
            if abs(p) > half:
                return None
            continue
        ta, tb = (-half - p) / q, (half - p) / q
        if ta > tb:
            ta, tb = tb, ta
        t0, t1 = max(t0, ta), min(t1, tb)
        if t0 > t1:
            return None
    return t0


VIEW_RANGE = 170.0  # the longest weapon range
VIEW_SPACING = 12.0
VIEW_RAYS = 16


def view_distances(boxes, blocked, n):
    """From drivable points every VIEW_SPACING m in the contested field, how far an eye-level ray sees in VIEW_RAYS
    directions (clipped at the perimeter and VIEW_RANGE). Returns the list of ray lengths."""
    tall = [b for b in boxes if b.h >= EYE_HEIGHT]
    lengths = []
    steps = int(FIELD_Z // VIEW_SPACING)
    for iz in range(-steps, steps + 1):
        for ix in range(-int(DRIVABLE // VIEW_SPACING), int(DRIVABLE // VIEW_SPACING) + 1):
            x, z = ix * VIEW_SPACING, iz * VIEW_SPACING
            if blocked[int((z + HALF) / GRID) * n + int((x + HALF) / GRID)]:
                continue
            for r in range(VIEW_RAYS):
                a = 2 * math.pi * r / VIEW_RAYS
                dx, dz = math.cos(a), math.sin(a)
                reach = VIEW_RANGE
                for limit, d in ((DRIVABLE - x, dx), (-DRIVABLE - x, dx), (DRIVABLE - z, dz), (-DRIVABLE - z, dz)):
                    if abs(d) > 1e-9 and limit / d > 0:
                        reach = min(reach, limit / d)
                bx, bz = x + dx * reach, z + dz * reach
                t = min((tt for tt in (entry_t(b, x, z, bx, bz) for b in tall) if tt is not None), default=1.0)
                lengths.append(reach * t)
    return lengths


def clear(boxes, ax, az, bx, bz):
    return not any(b.h >= EYE_HEIGHT and b.segment_hits(ax, az, bx, bz) for b in boxes)


def longest_sightline(boxes):
    """The longest unbroken eye-level line inside the contested field (|z| <= FIELD_Z) that crosses the centre line,
    over directions within 45 degrees of base-to-base, and where it runs. Samples x every 2 m on the centre line."""
    best = (0.0, None)
    for angle in range(-45, 46, 5):
        dx, dz = math.sin(math.radians(angle)), -math.cos(math.radians(angle))
        for i in range(-58, 59):
            x0 = i * 2.0
            if clear_len := _open_length(boxes, x0, dx, dz):
                if clear_len[0] > best[0]:
                    best = clear_len
    return best


def _open_length(boxes, x0, dx, dz, step=2.0):
    def walk(sign):
        dist = 0.0
        while True:
            nx, nz = x0 + sign * dx * (dist + step), sign * dz * (dist + step)
            if abs(nx) > DRIVABLE or abs(nz) > FIELD_Z:
                return dist
            if not clear(boxes, x0 + sign * dx * dist, sign * dz * dist, nx, nz):
                return dist
            dist += step
    a, b = walk(1), walk(-1)
    return (a + b, ((x0 - dx * b, -dz * b), (x0 + dx * a, dz * a)))


def occupancy(boxes):
    n = int(2 * HALF / GRID)
    blocked = bytearray(n * n)
    for b in boxes:
        reach = max(b.w, b.d) / 2 + AGENT_RADIUS + 1
        for gx in range(int((b.x - reach + HALF) / GRID), int((b.x + reach + HALF) / GRID) + 1):
            for gz in range(int((b.z - reach + HALF) / GRID), int((b.z + reach + HALF) / GRID) + 1):
                if 0 <= gx < n and 0 <= gz < n:
                    px, pz = gx * GRID - HALF + GRID / 2, gz * GRID - HALF + GRID / 2
                    if b.distance(px, pz) < AGENT_RADIUS:
                        blocked[gz * n + gx] = 1
    lim = int((HALF - DRIVABLE) / GRID)
    for g in range(n):
        for e in range(lim):
            for idx in (g * n + e, g * n + n - 1 - e, e * n + g, (n - 1 - e) * n + g):
                blocked[idx] = 1
    return blocked, n


def route(blocked, n, a, b):
    """8-connected A* on the grid; returns the path as world points, or None."""
    def cell(p):
        return int((p[0] + HALF) / GRID), int((p[1] + HALF) / GRID)
    start, goal = snap(blocked, n, cell(a)), snap(blocked, n, cell(b))
    if start is None or goal is None:
        return None
    frontier = [(0.0, 0.0, start)]
    came = {start: None}
    cost = {start: 0.0}
    while frontier:
        _, g, cur = heapq.heappop(frontier)
        if cur == goal:
            path = []
            while cur is not None:
                path.append((cur[0] * GRID - HALF + GRID / 2, cur[1] * GRID - HALF + GRID / 2))
                cur = came[cur]
            return path[::-1]
        if g > cost[cur]:
            continue
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                if not dx and not dz:
                    continue
                nx, nz = cur[0] + dx, cur[1] + dz
                if not (0 <= nx < n and 0 <= nz < n) or blocked[nz * n + nx]:
                    continue
                if dx and dz and (blocked[cur[1] * n + nx] or blocked[nz * n + cur[0]]):
                    continue
                ng = g + (1.4142 if dx and dz else 1.0) * GRID
                if ng < cost.get((nx, nz), 1e18):
                    cost[(nx, nz)] = ng
                    came[(nx, nz)] = cur
                    h = math.hypot(nx - goal[0], nz - goal[1]) * GRID
                    heapq.heappush(frontier, (ng + h, ng, (nx, nz)))
    return None


def snap(blocked, n, c, reach=12):
    """The nearest drivable cell to `c` within `reach` cells (a waypoint authored on top of cover), or None."""
    best = None
    for r in range(reach + 1):
        for dx in range(-r, r + 1):
            for dz in range(-r, r + 1):
                if max(abs(dx), abs(dz)) != r:
                    continue
                x, z = c[0] + dx, c[1] + dz
                if 0 <= x < n and 0 <= z < n and not blocked[z * n + x]:
                    d = dx * dx + dz * dz
                    if best is None or d < best[0]:
                        best = (d, (x, z))
        if best is not None:
            return best[1]
    return None


def length(path):
    return sum(math.dist(path[i - 1], path[i]) for i in range(1, len(path))) if path else 0.0


def terrain_class(boxes, x, z):
    count = sum(1 for b in boxes if math.hypot(b.x - x, b.z - z) <= TERRAIN_RADIUS)
    return "open" if count <= 1 else ("lanes" if count <= 4 else "dense")


def exposure(boxes, path, watchers):
    """Share of the path's samples (every 4 m) that at least one watcher position sees at eye level."""
    if not path:
        return None
    samples = path[::4]
    seen = sum(1 for p in samples if any(math.dist(p, w) <= 110.0 and clear(boxes, w[0], w[1], p[0], p[1]) for w in watchers))
    return seen / len(samples)


def lane_route(blocked, n, lane):
    pts = [tuple(p) for p in lane["points"]]
    total = []
    for i in range(1, len(pts)):
        leg = route(blocked, n, pts[i - 1], pts[i])
        if leg is None:
            return None
        total.extend(leg if not total else leg[1:])
    return total


def cover_gap(boxes, path):
    """The longest stretch of the path with no hard cover within 12 m (a bound with nowhere to stop)."""
    worst, run, prev = 0.0, 0.0, None
    for p in path or []:
        if prev is not None:
            run += math.dist(prev, p)
        if any(b.h >= EYE_HEIGHT and b.distance(p[0], p[1]) <= 12.0 for b in boxes):
            run = 0.0
        worst = max(worst, run)
        prev = p
    return worst


def analyze(layout):
    boxes = boxes_of(layout)
    blocked, n = occupancy(boxes)
    green_front = tuple(layout["spawns"]["green"][0])
    rust_front = tuple(layout["spawns"]["rust"][0])
    report = {"name": layout["name"], "features": len(boxes),
              "hard": sum(1 for b in boxes if b.h >= EYE_HEIGHT), "low": sum(1 for b in boxes if b.h < EYE_HEIGHT)}
    sight, where = longest_sightline(boxes)
    report["longest_sightline_m"] = round(sight, 1)
    views = view_distances(boxes, blocked, n)
    report["mean_view_m"] = round(sum(views) / len(views), 1)
    report["views_over_120m"] = round(sum(1 for v in views if v >= 120.0) / len(views), 2)
    report["longest_sightline_at"] = [[round(v, 1) for v in p] for p in where] if where else None
    direct = route(blocked, n, green_front, rust_front)
    report["base_to_base_m"] = round(length(direct), 1) if direct else None
    to_centre = route(blocked, n, green_front, (0.0, 0.0))
    report["base_to_centre_m"] = round(length(to_centre), 1) if to_centre else None
    # Watchers: the enemy's covered positions, approximated by points 4 m outside hard cover on the north half.
    watchers = [(b.x, b.z - (b.d / 2 + 4.0)) for b in boxes if b.h >= EYE_HEIGHT and b.z < -10.0]
    watchers += [tuple(p) for p in layout["spawns"]["rust"][:13]]
    report["direct_route_exposure"] = round(exposure(boxes, direct, watchers), 2) if direct else None
    classes = {"open": 0, "lanes": 0, "dense": 0}
    for p in (direct or [])[::10]:
        classes[terrain_class(boxes, *p)] += 1
    report["terrain_along_direct_route"] = classes
    lanes = []
    for lane in layout.get("lanes", []):
        path = lane_route(blocked, n, lane)
        entry = {"name": lane["name"], "reachable": path is not None}
        if path:
            entry.update({"length_m": round(length(path), 1), "exposure": round(exposure(boxes, path, watchers), 2),
                          "longest_uncovered_m": round(cover_gap(boxes, path), 1)})
        lanes.append(entry)
    report["lanes"] = lanes
    free = n * n - sum(blocked)
    report["open_ground_share"] = round(sum(1 for gz in range(4, n, 8) for gx in range(4, n, 8)
                                            if terrain_class(boxes, gx * GRID - HALF, gz * GRID - HALF) == "open")
                                        / len(range(4, n, 8)) ** 2, 2)
    report["drivable_share"] = round(free / (n * n), 2)
    report["_paths"] = {"direct": direct, "lanes": {l["name"]: lane_route(blocked, n, l) for l in layout.get("lanes", [])}}
    report["_boxes"] = boxes
    return report


def plot(layout, report, out_dir):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.patches import Polygon, Circle, Rectangle
    fig, ax = plt.subplots(figsize=(9, 9))
    ax.set_facecolor("#15161a")
    ax.add_patch(Rectangle((-HALF, -HALF), 2 * HALF, 2 * HALF, fill=False, ec="#888", lw=1.5))
    colors = {"container_20": "#c46a3a", "container_40": "#b0552c", "ad_screen": "#44d7ff", "barricade": "#9a9a9a",
              "wreck": "#7a5a3a", "floodlight": "#ffe066", "crate": "#8b7d6b", "wall": "#6b6b80"}
    for b in report["_boxes"]:
        shade = colors.get(b.kind, "#aaa")
        ax.add_patch(Polygon(b.corners(), closed=True, fc=shade, ec="white" if b.h >= 5 else "black",
                             lw=1.2 if b.h >= 5 else 0.5, alpha=0.95 if b.h >= EYE_HEIGHT else 0.55))
    for p in layout.get("props", []):
        if p["type"] == "sign":
            ax.plot(p["position"][0], -p["position"][1], "m*", ms=8)
    for side, col in (("green", "#3cff7a"), ("rust", "#ff5a3c")):
        xs = [s[0] for s in layout["spawns"][side]]
        zs = [s[1] for s in layout["spawns"][side]]
        ax.scatter(xs, zs, s=6, c=col)
        zone = layout.get("spawn_zones", {}).get(side)
        if zone:
            ax.add_patch(Rectangle((zone["center"][0] - zone["size"][0] / 2, zone["center"][1] - zone["size"][1] / 2),
                                   zone["size"][0], zone["size"][1], fill=False, ec=col, ls="--"))
    for h in layout.get("hazards", []):
        ax.add_patch(Circle(tuple(h["position"]), h["radius"], color="#ff7b00", alpha=0.5))
    cp = layout.get("control_point")
    if isinstance(cp, dict):
        ax.add_patch(Circle((0, 0), cp.get("radius", 16), fill=False, ec="#ffd500", lw=1.5))
    for region in layout.get("regions", []):
        ax.add_patch(Circle(tuple(region["position"]), region["radius"], fill=False, ec="#b388ff", ls=":", lw=1))
        ax.text(region["position"][0], region["position"][1], region["kind"], color="#b388ff", fontsize=6, ha="center")
    for name, path in report["_paths"]["lanes"].items():
        if path:
            ax.plot([p[0] for p in path], [p[1] for p in path], lw=1, alpha=0.6)
    if report["_paths"]["direct"]:
        path = report["_paths"]["direct"]
        ax.plot([p[0] for p in path], [p[1] for p in path], color="white", lw=1.5, ls="--")
    if report["longest_sightline_at"]:
        (ax_, az_), (bx_, bz_) = report["longest_sightline_at"]
        ax.plot([ax_, bx_], [az_, bz_], color="red", lw=2)
    ax.set_xlim(-HALF - 2, HALF + 2)
    ax.set_ylim(HALF + 2, -HALF - 2)  # north (-z) at the top: green attacks upward
    ax.set_aspect("equal")
    ax.set_title("%s: sightline %.0f m, base-to-base %s m, exposure %s" % (
        layout["name"], report["longest_sightline_m"], report["base_to_base_m"], report["direct_route_exposure"]), fontsize=10)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, layout["name"] + ".png")
    fig.savefig(path, dpi=90, bbox_inches="tight")
    plt.close(fig)
    return path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("layouts", nargs="+")
    parser.add_argument("--plot", help="write a PNG per layout into this folder")
    parser.add_argument("--json", help="write every report to this file")
    args = parser.parse_args()
    reports = []
    for file in args.layouts:
        with open(file) as f:
            layout = json.load(f)
        report = analyze(layout)
        if args.plot:
            report["plot"] = plot(layout, report, args.plot)
        clean = {k: v for k, v in report.items() if not k.startswith("_")}
        reports.append(clean)
        print("ARENA_REPORT " + json.dumps(clean))
    if args.json:
        os.makedirs(os.path.dirname(args.json) or ".", exist_ok=True)
        with open(args.json, "w") as f:
            json.dump(reports, f, indent=1)


if __name__ == "__main__":
    sys.exit(main())
