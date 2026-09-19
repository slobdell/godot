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


def cover_groups(boxes, touch=1.5):
    """Sight-blocking boxes merged when their footprints come within `touch` m: a wall of containers is one piece."""
    hard = [b for b in boxes if b.h >= EYE_HEIGHT]
    parent = list(range(len(hard)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for i, a in enumerate(hard):
        for j in range(i + 1, len(hard)):
            b = hard[j]
            if math.hypot(a.x - b.x, a.z - b.z) > (max(a.w, a.d) + max(b.w, b.d)) / 2 + touch:
                continue
            if min(b.distance(*c) for c in a.corners()) <= touch or min(a.distance(*c) for c in b.corners()) <= touch:
                parent[find(i)] = find(j)
    groups = {}
    for i, b in enumerate(hard):
        groups.setdefault(find(i), []).append(b)
    return list(groups.values())


def terrain_class(boxes, x, z, hard_only=False, groups=None):
    if groups is not None:
        count = sum(1 for g in groups if any(math.hypot(b.x - x, b.z - z) <= TERRAIN_RADIUS for b in g))
    else:
        count = sum(1 for b in boxes if math.hypot(b.x - x, b.z - z) <= TERRAIN_RADIUS and (not hard_only or b.h >= EYE_HEIGHT))
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


# ---- X2: can this map host an ambush? (round 6) ---------------------------------------------------------------
# The lead wants ambush and flanking to be POSSIBLE. That is a property of sightlines, not of prop count, and it is
# measurable before anyone plays the map: if the centre sees everything, nothing can be set up behind it.
#
# Everything below works on a SIGHT grid -- cells covered by something at or above eye level, with NO agent-radius
# inflation, because sight is not driving -- and marches along it. That keeps the whole pass to a few seconds per
# layout while staying consistent with `clear()`, which is the exact test used elsewhere in this file.

SIGHT_GRID = 1.0
## Where exposure is sampled: the contested field, every 4 m.
EXPOSURE_STEP = 4.0
## Defending positions are subsampled to this many, spread evenly, so the pass stays a few seconds. They are ordered
## by position (not by the layout's authoring order) so the choice does not change when a prop is added elsewhere.
WATCHER_SAMPLE = 24
## An overwatch position is judged on how much of the crossing it sees, and whether it can itself be approached
## unseen from this far out.
OVERWATCH_APPROACH_M = 28.0
## The exposure-vs-detour curve. A penalty big enough to saturate answers "is there ANY covered way across", which is
## almost always yes and so tells you nothing; these are sized to keep the detour informative. Read them as a curve:
## what a unit buys for a 15% longer drive is a more useful fact about a map than what it buys for a 100% longer one.
ROUTE_PENALTIES = (("direct", 0.0), ("flanking", 2.0), ("covered", 8.0))


def sight_grid(boxes):
    """1 where something at or above eye level stands. No agent inflation: this is what blocks a look, not a hull."""
    n = int(2 * HALF / SIGHT_GRID)
    grid = bytearray(n * n)
    for b in boxes:
        if b.h < EYE_HEIGHT:
            continue
        reach = max(b.w, b.d) / 2 + 1
        for gx in range(int((b.x - reach + HALF) / SIGHT_GRID), int((b.x + reach + HALF) / SIGHT_GRID) + 1):
            for gz in range(int((b.z - reach + HALF) / SIGHT_GRID), int((b.z + reach + HALF) / SIGHT_GRID) + 1):
                if 0 <= gx < n and 0 <= gz < n:
                    px, pz = gx * SIGHT_GRID - HALF + SIGHT_GRID / 2, gz * SIGHT_GRID - HALF + SIGHT_GRID / 2
                    if b.distance(px, pz) <= 0.0:
                        grid[gz * n + gx] = 1
    return grid, n


def sees(grid, n, ax, az, bx, bz, step=1.0):
    """March the sight grid from a to b. True if nothing at eye level stands in between."""
    dist = math.hypot(bx - ax, bz - az)
    if dist < 1e-6:
        return True
    steps = int(dist / step)
    dx, dz = (bx - ax) / dist * step, (bz - az) / dist * step
    for i in range(1, steps + 1):
        gx, gz = int((ax + dx * i + HALF) / SIGHT_GRID), int((az + dz * i + HALF) / SIGHT_GRID)
        if 0 <= gx < n and 0 <= gz < n and grid[gz * n + gx]:
            return False
    return True


def field_points(blocked, n, step=EXPOSURE_STEP):
    """Drivable sample points across the contested field."""
    out = []
    z = -FIELD_Z
    while z <= FIELD_Z:
        x = -DRIVABLE
        while x <= DRIVABLE:
            if not blocked[int((z + HALF) / GRID) * n + int((x + HALF) / GRID)]:
                out.append((x, z))
            x += step
        z += step
    return out


def standing_point(blocked, n, want):
    """The nearest DRIVABLE point to `want`. An observer placed inside a box sees nothing at all, and foundry has a
    crate on the exact centre: the first version of centre_sees_share reported 0.000 for the most open arena in the
    game. An eye has to be somewhere a vehicle could be."""
    cell = snap(blocked, n, (int((want[0] + HALF) / GRID), int((want[1] + HALF) / GRID)))
    if cell is None:
        return want
    return (cell[0] * GRID - HALF + GRID / 2, cell[1] * GRID - HALF + GRID / 2)


def visible_share(grid, gn, origin, points):
    """Share of `points` that `origin` can see at eye level, within the longest weapon range."""
    if not points:
        return None
    seen = sum(1 for p in points
               if math.dist(origin, p) <= VIEW_RANGE and sees(grid, gn, origin[0], origin[1], p[0], p[1]))
    return seen / len(points)


def defending_positions(boxes, layout):
    """The enemy's covered firing positions: 4 m out from each piece of hard cover on the north half, plus its front
    spawn row. Subsampled evenly to WATCHER_SAMPLE so the pass stays cheap and stable."""
    spots = [(b.x, b.z - (b.d / 2 + 4.0)) for b in boxes if b.h >= EYE_HEIGHT and b.z < -10.0]
    spots += [tuple(p) for p in layout["spawns"]["rust"][:13]]
    spots.sort()
    if len(spots) <= WATCHER_SAMPLE:
        return spots
    stride = len(spots) / WATCHER_SAMPLE
    return [spots[int(i * stride)] for i in range(WATCHER_SAMPLE)]


## How far a defending position is taken to MATTER, not merely to see. Two reaches, because they are two different
## tactical situations rather than two kinds of unit (combat derived the numbers, squad the distinction):
##
##   idle   ~45 m  a defender acting on its OWN judgement. combat's median of min(effective_range, sight_radius)
##                 across all four rosters (n=14, mean 52, range 24-104). **This is the ambush question:** can an
##                 element cross unpunished if the enemy has not specifically set up to cover this approach?
##   posted ~70 m  a cannon's full range, reached when a commander SPENDS a support-by-fire task on an element
##                 (squad: TankBrain._order_weapon sets `long_shot: true` for an SBF task, lifting fire discipline
##                 to the weapon's full range). **This is the overwatch question:** which positions are worth
##                 posting, and therefore which approaches a competent opponent can deny.
##
## THE DIFFERENCE BETWEEN THEM IS THE INTERESTING NUMBER. A map where the two agree has no positions worth posting;
## a map where they diverge makes the defender choose and lets the attacker read the choice. An approach denied at
## 45 m by anyone standing nearby is just bad terrain.
##
## An approach that is safe at 45 m is therefore NOT absolutely safe -- it is safe from crews using their own
## judgement. That caveat must travel with any "covered approach" number, or it reads as a guarantee.
##
## **These are a FALLBACK, not the source of truth.** The real answer is derived from the catalog by combat's
## `Engagement.covering_range()`; `make arena-reach` writes it to build/arena-reach.json and this tool reads that
## file when it exists (`--reach` still overrides both). Carrying a copy here is what went wrong the first time --
## the hand-picked "posted" value was 70 m, from "a cannon's full range", where the catalog's own median of
## min(full range, sight radius) over all 14 units is 60 m: several units cannot SEE as far as they can shoot.
## A number derived from data belongs in one place, and this is not it.
WATCHER_REACH_M = {"idle": 45.0, "posted": 60.0}
REACH_FILE = "build/arena-reach.json"


def load_reach(path=None):
    """The covering ranges from the catalog (make arena-reach), falling back to the constants above."""
    file = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), path or REACH_FILE)
    try:
        with open(file) as f:
            data = json.load(f)
    except (OSError, ValueError):
        print("ARENA_REACH_FALLBACK using built-in %s (run: make arena-reach)" % WATCHER_REACH_M, file=sys.stderr)
        return dict(WATCHER_REACH_M)
    return {key: float(data[key]) for key in ("idle", "posted") if key in data} or dict(WATCHER_REACH_M)


def exposure_cost_field(grid, gn, blocked, n, watchers, reach):
    """cell -> share of defending positions that can both see it and reach it. The raw material for 'is there a
    covered way across?'. Sight is computed once per (cell, watcher) pair and reused for every reach."""
    fields = {key: {} for key in reach}
    for p in field_points(blocked, n):
        distances = [math.dist(p, w) for w in watchers]
        visible = [d <= max(reach.values()) and sees(grid, gn, w[0], w[1], p[0], p[1])
                   for w, d in zip(watchers, distances)]
        for key, limit in reach.items():
            seen = sum(1 for d, v in zip(distances, visible) if v and d <= limit)
            fields[key][(int(p[0]), int(p[1]))] = seen / max(1, len(watchers))
    return fields


def route_exposure(field, path):
    """Mean over the route of the share of defending positions that see it -- THE SAME measure covered_route()
    minimises, so a bigger penalty can never report a worse route. (An earlier version optimised the grid-marched
    field and reported `exposure()`'s independent box test instead; the two disagree at the margins and the
    "balanced" route came out MORE exposed than the direct one, which is arithmetically impossible for the thing
    being optimised. If these two ever need to differ again, they need two names.)"""
    if not path:
        return None
    return sum(_exposure_at(field, p[0], p[1]) for p in path) / len(path)


def _exposure_at(field, x, z):
    """Nearest sampled exposure cell (the field is on a 4 m lattice; paths are on a 1 m one)."""
    step = int(EXPOSURE_STEP)
    key = (int(round(x / step) * step), int(round(z / step) * step))
    return field.get(key, 0.0)


def covered_route(blocked, n, field, a, b, penalty):
    """A* from a to b minimising distance * (1 + penalty * exposure). penalty 0 gives the shortest route; a large
    penalty gives the most covered one the map allows. The gap between them IS the map's flanking headroom."""
    def cell(p):
        return int((p[0] + HALF) / GRID), int((p[1] + HALF) / GRID)
    start, goal = snap(blocked, n, cell(a)), snap(blocked, n, cell(b))
    if start is None or goal is None:
        return None
    frontier = [(0.0, 0.0, start)]
    came, cost = {start: None}, {start: 0.0}
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
                wx, wz = nx * GRID - HALF + GRID / 2, nz * GRID - HALF + GRID / 2
                step_m = (1.4142 if dx and dz else 1.0) * GRID
                ng = g + step_m * (1.0 + penalty * _exposure_at(field, wx, wz))
                if ng < cost.get((nx, nz), 1e18):
                    cost[(nx, nz)] = ng
                    came[(nx, nz)] = cur
                    # Admissible: the cheapest a remaining metre can ever be is 1.0 per metre.
                    h = math.hypot(nx - goal[0], nz - goal[1]) * GRID
                    heapq.heappush(frontier, (ng + h, ng, (nx, nz)))
    return None


def longest_hidden_run(grid, gn, path, origin):
    """The longest stretch of `path` that `origin` cannot see. This is the sightline break an element crosses in."""
    worst = run = 0.0
    prev = None
    for p in path or []:
        if prev is not None:
            leg = math.dist(prev, p)
            if sees(grid, gn, origin[0], origin[1], p[0], p[1]):
                run = 0.0
            else:
                run += leg
                worst = max(worst, run)
        prev = p
    return worst


def overwatch_positions(grid, gn, blocked, n, boxes, path, top=3):
    """Positions that dominate the crossing but can themselves be approached unseen. A position that sees the route
    AND every way up to it is a fortress, not an overwatch: the map has no answer to it."""
    if not path:
        return []
    samples = path[::6]
    ring = [(math.cos(a * math.pi / 8), math.sin(a * math.pi / 8)) for a in range(16)]
    found = []
    for spot in field_points(blocked, n, 8.0):
        if not any(b.h >= EYE_HEIGHT and b.distance(spot[0], spot[1]) <= 6.0 for b in boxes):
            continue  # an overwatch position is one with cover to shoot from
        lines = [(math.dist(spot, p), sees(grid, gn, spot[0], spot[1], p[0], p[1])) for p in samples]
        # Two different questions, and conflating them made every arena's best position score 0.48:
        #   covers  -- share of the WHOLE crossing this position denies. Bounded by 2 * reach / route length, so at
        #              45 m over a ~200 m crossing nothing can exceed ~0.45 however well placed it is. Read it as
        #              "how much of the route", never as "how good is this spot".
        #   commands -- of the samples INSIDE its reach, the share it can actually see. This is the geometry alone,
        #              and it is the number that separates a position overlooking a lane from one behind a wall.
        seen_at, commands_at = {}, {}
        for key, limit in WATCHER_REACH_M.items():
            within = [v for d, v in lines if d <= limit]
            seen_at[key] = sum(1 for d, v in lines if v and d <= limit) / len(samples)
            commands_at[key] = (sum(1 for v in within if v) / len(within)) if within else 0.0
        dominates = seen_at["posted"]
        if dominates < 0.15:
            continue
        approaches = [(spot[0] + dx * OVERWATCH_APPROACH_M, spot[1] + dz * OVERWATCH_APPROACH_M) for dx, dz in ring]
        approaches = [a for a in approaches if abs(a[0]) <= DRIVABLE and abs(a[1]) <= DRIVABLE
                      and not blocked[int((a[1] + HALF) / GRID) * n + int((a[0] + HALF) / GRID)]]
        hidden = sum(1 for a in approaches if not sees(grid, gn, spot[0], spot[1], a[0], a[1]))
        found.append({"at": [round(spot[0], 1), round(spot[1], 1)], "dominates": round(dominates, 2),
                      "covers_idle": round(seen_at["idle"], 2), "covers_posted": round(seen_at["posted"], 2),
                      "commands_idle": round(commands_at["idle"], 2), "commands_posted": round(commands_at["posted"], 2),
                      "hidden_approach": round(hidden / len(approaches), 2) if approaches else None})
    found.sort(key=lambda o: -o["dominates"])
    # One per neighbourhood: 40 positions on the same container wall are one overwatch, not forty.
    kept = []
    for o in found:
        if all(math.dist(o["at"], k["at"]) > 24.0 for k in kept):
            kept.append(o)
        if len(kept) == top:
            break
    return kept


def ambush_report(layout, boxes, blocked, n):
    """X2: the numbers that say whether this map can host an ambush or a flank at all."""
    grid, gn = sight_grid(boxes)
    points = field_points(blocked, n, 6.0)
    watchers = defending_positions(boxes, layout)
    fields = exposure_cost_field(grid, gn, blocked, n, watchers, WATCHER_REACH_M)
    # Routes are planned against the IDLE field: a unit picks its approach expecting crews using their own judgement,
    # not expecting to be personally targeted by a posted element. What it then costs if the enemy HAS posted one is
    # reported alongside, which is the decision the map is really offering.
    field = fields["idle"]
    green_front = tuple(layout["spawns"]["green"][0])
    rust_front = tuple(layout["spawns"]["rust"][0])
    centre = standing_point(blocked, n, (0.0, 0.0))
    out = {"centre_sees_share": round(visible_share(grid, gn, centre, points), 3),
           "centre_eye_at": [round(v, 1) for v in centre], "defending_positions": len(watchers)}
    routes = []
    for label, penalty in ROUTE_PENALTIES:
        path = covered_route(blocked, n, field, green_front, rust_front, penalty)
        if path is None:
            routes.append({"route": label, "reachable": False})
            continue
        entry = {"route": label, "reachable": True, "length_m": round(length(path), 1),
                 "exposure": round(route_exposure(field, path), 3),
                 "hidden_from_centre_m": round(longest_hidden_run(grid, gn, path[::2], centre), 1)}
        for key in WATCHER_REACH_M:
            entry["exposure_" + key] = round(route_exposure(fields[key], path), 3)
        # What a posted element adds over crews acting on their own judgement. A map where this is ~0 has no
        # positions worth spending a support-by-fire task on.
        entry["posting_gain"] = round(entry["exposure_posted"] - entry["exposure_idle"], 3)
        routes.append(entry)
    out["approach_routes"] = routes
    covered = next((r for r in routes if r["route"] == "covered" and r.get("reachable")), None)
    direct = next((r for r in routes if r["route"] == "direct" and r.get("reachable")), None)
    if covered and direct:
        # How much exposure the terrain lets a unit buy off, and what the detour costs. There is deliberately NO
        # can_cross_unseen boolean: the first version had one and it was True for all eight arenas, which is not a
        # measurement, it is a constant. The share the centre sees is the number that actually separates these maps.
        out["flank_gain"] = round(direct["exposure"] - covered["exposure"], 3)
        out["flank_detour"] = round(covered["length_m"] / max(1.0, direct["length_m"]), 2)
    direct_path = covered_route(blocked, n, field, green_front, rust_front, 0.0)
    out["overwatch"] = overwatch_positions(grid, gn, blocked, n, boxes, direct_path)
    return out


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
    # How doctrine would classify the field (ElementSituation: every obstacle counts), and how it would with only
    # sight-blocking cover counted: drivable points every 8 m in the contested field.
    groups = cover_groups(boxes)
    report["cover_groups"] = len(groups)
    for key, hard_only, grouped in (("doctrine_terrain_share", False, None), ("doctrine_terrain_share_hard_only", True, None),
                                    ("doctrine_terrain_share_grouped", True, groups)):
        shares = {"open": 0, "lanes": 0, "dense": 0}
        total = 0
        for gz in range(int(-FIELD_Z), int(FIELD_Z) + 1, 8):
            for gx in range(int(-DRIVABLE), int(DRIVABLE) + 1, 8):
                if blocked[int((gz + HALF) / GRID) * n + int((gx + HALF) / GRID)]:
                    continue
                shares[terrain_class(boxes, gx, gz, hard_only, grouped)] += 1
                total += 1
        report[key] = {k: round(v / total, 2) for k, v in shares.items()}
    free = n * n - sum(blocked)
    report["open_ground_share"] = round(sum(1 for gz in range(4, n, 8) for gx in range(4, n, 8)
                                            if terrain_class(boxes, gx * GRID - HALF, gz * GRID - HALF) == "open")
                                        / len(range(4, n, 8)) ** 2, 2)
    report["drivable_share"] = round(free / (n * n), 2)
    report["ambush"] = ambush_report(layout, boxes, blocked, n)
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
    # The centre-visibility share, not `direct_route_exposure`: the old one is the legacy 110 m box test and would
    # print a different "exposure" from the one the X2 table and the lead's review page quote. Two numbers with the
    # same name on one page is how a reader learns to distrust both.
    ax.set_title("%s: the middle sees %.0f%% of the field · longest sightline %.0f m · base to base %s m" % (
        layout["name"], report["ambush"]["centre_sees_share"] * 100.0,
        report["longest_sightline_m"], report["base_to_base_m"]), fontsize=10)
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
    parser.add_argument("--reach", help="override the watcher reaches, e.g. idle=45,posted=70 (see WATCHER_REACH_M); "
                                        "this is how the exposure numbers get re-derived after combat's CP4")
    args = parser.parse_args()
    WATCHER_REACH_M.update(load_reach())
    if args.reach:
        WATCHER_REACH_M.clear()
        for part in args.reach.split(","):
            key, _, value = part.partition("=")
            WATCHER_REACH_M[key.strip()] = float(value)
    reports = []
    for file in args.layouts:
        with open(file) as f:
            layout = json.load(f)
        report = analyze(layout)
        if args.plot:
            report["plot"] = plot(layout, report, args.plot)
        clean = {k: v for k, v in report.items() if not k.startswith("_")}
        reports.append(clean)
        a = clean["ambush"]
        by = {r["route"]: r for r in a["approach_routes"]}
        best = a["overwatch"][0] if a["overwatch"] else {}
        print("AMBUSH %-10s centre_sees=%.2f sightline=%3.0fm | crossing idle=%.3f posted=%.3f (posting +%.3f) | "
              "covered=%.3f at %.2fx | best overwatch commands %.2f idle / %.2f posted, %.2f unseen approach"
              % (clean["name"], a["centre_sees_share"], clean["longest_sightline_m"],
                 by["direct"].get("exposure_idle", -1), by["direct"].get("exposure_posted", -1),
                 by["direct"].get("posting_gain", -1), by["covered"].get("exposure", -1), a.get("flank_detour", -1),
                 best.get("commands_idle", -1), best.get("commands_posted", -1), best.get("hidden_approach", -1)))
        print("ARENA_REPORT " + json.dumps(clean))
    if args.json:
        os.makedirs(os.path.dirname(args.json) or ".", exist_ok=True)
        with open(args.json, "w") as f:
            json.dump(reports, f, indent=1)


if __name__ == "__main__":
    sys.exit(main())
