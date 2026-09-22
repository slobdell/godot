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
import argparse, heapq, json, math, os, pathlib, sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import units_catalog

## The half-extent `centre_sees_share` is ALWAYS measured over, whatever size the layout declares.
##
## The target (<0.30) carries the lead's own verdict — he cut the four most open maps and kept two of the three
## least open — and that verdict was given on 240 x 240 arenas. Measured over a layout's OWN extent the number is
## not comparable across sizes: yard scored 0.199 at half_size 120 and **0.153 at 140, same props, same map**, a
## 23% improvement bought by declaring the arena bigger. A map could pass the target by inflating its bound.
##
## So the window is fixed at the size the target was calibrated on, and `centre_sees_share_full` reports the
## layout's own extent beside it for the information that is genuinely there.
CALIBRATION_HALF = 120.0

EYE_HEIGHT = 1.3
AGENT_RADIUS = 2.0
## The arena's extent, in metres from the centre. **Set per layout by `analyze()`** — these are the defaults for a
## layout that declares nothing, not a constant. They were constants until layouts could differ in size, at which
## point the whole report measured a 240 x 240 window whatever the layout said: a hexagon at half_size 140 had its
## outer 20 m simply not looked at, and `centre_sees_share_full` came back identical to the fixed-window figure
## because both were reading the same hardcoded box.
##
## `CALIBRATION_HALF` above stays fixed on purpose. The grid follows the layout; the target metric does not.
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
    "ad_screen": ([7.8, 1.4, 2.0], "hard", True),
    "barricade": ([6.0, 0.9, 0.8], "low", True),
    "wreck": ([3.2, 2.0, 3.3], "hard", True),
    "floodlight": ([2.4, 3.0, 2.4], "hard", True),
    "sign": ([0.4, 6.0, 0.4], "none", False),
    "block": ([40.0, 24.0, 40.0], "hard", True),
}
# ⚠ THIS TABLE IS A SECOND COPY OF `ArenaKit.PROPS` AND NOTHING CHECKS THAT IT AGREES. A comment where a
# dependency should be -- the same trap combat found in this file's spawn pitch the same day, and it bit here
# immediately: `block` shipped in `arena_kit.gd` in round 7 and was missing from this table until the cityscape
# tried to use it, which failed loudly only because a KeyError is loud. A prop whose SIZE drifted instead of going
# missing would have failed silently, and every measurement taken with it would have been wrong and believable.
# `test_the_kit_table_still_matches_the_game` (tools/test_arena_report.py) now asserts the two agree, entry by entry.
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


## `centre_sees_share` has a target at the OPEN end (< 0.30, carrying the lead's verdict) and NOTHING at the closed
## end. Round 8 made that gap real: the cityscape scores 0.13, the lowest of any map, and "the middle can see very
## little" is a compliment right up to the point where it means "there is nowhere to see from".
##
## **These are not targets and the thresholds are not mine to invent.** The lead has ruled on six maps and every one
## of them was at the open end of the range; nobody has ever told us a map was too closed, so there is no verdict to
## encode and inventing a number would be exactly the post-hoc threshold this stream keeps writing lessons against.
## What this does instead is say when a layout is an OUTLIER against the maps he has actually played, and name the
## comparison, so a human is asked rather than a constant.
##
## The reference is **the maps the lead has actually ruled on** — and terminus is deliberately NOT among them, which
## is the whole point. My first version of this took the range from every shipping map including terminus, so
## terminus defined the low end and could never flag itself: a guard calibrated on the thing it is meant to watch.
## Measured by this tool over the seven he has judged:
##
##   drivable_share  0.48 (boneyard) .. 0.55 (pit)        mean_view_m  54.3 (yard) .. 81.8 (pit)
##
## terminus sits at **0.44 and 50.2 m — outside both**, and so it trips its own flag, which is the honest outcome:
## it IS the outlier, nobody has ruled on it, and the tool says so every time anyone runs it rather than relying on
## someone remembering the caveat in a document.
SHIPPED_DRIVABLE_LOW = 0.48
SHIPPED_MEAN_VIEW_LOW = 54.3


## The longest hull in the game, READ from combat's catalog rather than copied into this file. A copy would be a
## third table to keep in step, and the rig's length is actively being argued about (12 m vs 14 m), so a mirrored
## number here would be stale within the week. Same reason `KIT` now has a test against `ArenaKit.PROPS`.
##
## Round 9 (scale): the three-line regex that used to live here became `tools/units_catalog.py`, so this tool and
## `tools/roster_scale.py` share ONE parser instead of one each -- and that parser RAISES instead of returning an
## empty table when the catalog moves (Invariant 0: a reader must not fall back).
def hull_lengths():
    """{unit name: hull length in metres} from game/units/units.gd's `hull_size [w, h, l]`."""
    return units_catalog.hull_lengths()


## Can a hull of `length` hide behind anything here, and how much of the field can it do that from?
##
## **BEST CASE by construction**: a box's screening length is its longest horizontal side, which assumes the hull is
## parked along that side and the shooter is square to it. A hull that fails this cannot be hidden at all.
##
## Why it exists (round 8, combat found it): the longest prop in the arena kit is `container_40` at **12.19 m** and
## the War Rig is **14.0 m**, so on yard and pit there is nothing on the map it can hide behind — and **cover fails
## silently**: the rig still drives to cover, still counts as near cover, and simply is not covered. Stacking adds
## height, not length. The v1 maps are fine because the legacy `wall` obstacle is 18 m; **the regression came in
## with the arena kit**, which has no long prop at all.
def hull_cover_reach(layout, boxes, length, step=8.0):
    tall = [b for b in boxes if b.h >= EYE_HEIGHT and max(b.w, b.d) >= length]
    half = float(layout.get("half_size", HALF))
    points = covered = 0
    z = -FIELD_Z
    while z <= FIELD_Z:
        x = -half
        while x <= half:
            points += 1
            if any(b.distance(x, z) <= TERRAIN_RADIUS for b in tall):
                covered += 1
            x += step
        z += step
    return covered / max(1, points)


def openness_notes(report):
    """Human-facing flags, never failures: where does this layout sit against the maps the lead has played?"""
    out = []
    drivable = report.get("drivable_share", 0.0)
    view = report.get("mean_view_m", 0.0)
    if drivable < SHIPPED_DRIVABLE_LOW:
        out.append("drivable_share %.2f is below every map the lead has ruled on (lowest is %.2f): more of the floor is "
                   "building than any map he has played. Not a failure — a question for a human." % (drivable, SHIPPED_DRIVABLE_LOW))
    if view < SHIPPED_MEAN_VIEW_LOW:
        out.append("mean_view %.1f m is below every map the lead has ruled on (lowest is %.1f m): sightlines may be "
                   "shorter than a gunline needs. Not a failure — a question for a human." % (view, SHIPPED_MEAN_VIEW_LOW))
    # Read from `hull_cover`, NOT from a "_"-prefixed key: `main()` strips every key starting with "_" before the
    # notes are generated, so a private key here is a flag that can never fire. It did not fire, for exactly that
    # reason, until the 14 m rig landed and yard read reach 0.00 in the JSON with no WATCH line beside it.
    cover = report.get("hull_cover")
    if cover:
        name, length, reach = cover["longest_hull"], cover["longest_hull_m"], cover["reach"]
        # ROUND 9 (scale, A3): this line USED to say "NOTHING on this map can hide the longest hull", full stop.
        # That was true under the definition it was computed with -- a prop counts only if its longest horizontal
        # side is at least the whole hull -- and it is FALSE under the hull-chord query that replaced it
        # (`Arena.cover_fraction`, `game/arena/cover_tables.gd`), which measures the fraction of the hull's own
        # centreline that is occluded and therefore has no step at `container_40`'s 12.19 m. A WATCH line that is
        # confidently wrong is worse than silence (the lead's ruling in game_design.md *Ruling: the War Rig stays
        # at 14 m*), so the number is still printed -- it is the record of what the cliff was -- and it now says
        # which definition produced it and where the live one lives.
        #
        # The point sample stays printed BESIDE the chord figure for one round rather than instead of it
        # (lesson 49). `make arena-cover` prints the chord figure; it needs Godot, because it calls the tables
        # rather than reimplementing them in Python, which would be the mirror Invariant 0 is about.
        if reach < 0.01:
            out.append("SUPERSEDED MEASURE: under CENTRE-POINT registration, 0.00 of the field is within %.0f m of "
                       "a prop as long as the longest hull (%s, %.1f m) — the 12.19 m step that A3 replaced. It is "
                       "NOT the game's cover rule any more: `Arena.cover_fraction` measures the occluded fraction "
                       "of the hull's own chord and does not step. Run `make arena-cover` for the live figure."
                       % (TERRAIN_RADIUS, name, length))
        elif reach < 0.5:
            out.append("SUPERSEDED MEASURE: under CENTRE-POINT registration, only %.2f of the field is within %.0f m "
                       "of cover long enough for the longest hull (%s, %.1f m). Run `make arena-cover` for what the "
                       "game actually asks." % (reach, TERRAIN_RADIUS, name, length))
    # S1/round 9 (squad's finding): the tightest point on the base-to-base route against the roster's widest hull.
    # A WATCH line and NOT a failing test, deliberately: whether a map should be widened or an agent radius should
    # vary by hull class is a decision nobody has made, and a check that fails on an open question is an advocate
    # rather than an instrument (Invariant 0b).
    corridor = report.get("corridor")
    if corridor and corridor["narrowest_m"] < corridor["widest_hull_m"] + 1.0:
        out.append("the tightest point on the base-to-base route is %.2f m of clear ground at [%.0f, %.0f], and the "
                   "roster's widest hull (%s) is %.2f m: only %d of %d hulls pass there with a metre to spare. A "
                   "wide vehicle either files through or does not arrive at all."
                   % (corridor["narrowest_m"], corridor["narrowest_at"][0], corridor["narrowest_at"][1],
                      corridor["widest_hull"], corridor["widest_hull_m"], corridor["hulls_that_fit"],
                      corridor["hulls"]))
    if report["ambush"]["centre_sees_share"] < 0.10:
        out.append("centre_sees %.3f is very low: check the middle is a place you can fight FROM, not just a place "
                   "nothing reaches." % report["ambush"]["centre_sees_share"])
    return out


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


def corridor_widths(boxes, path, step=4, probe=0.5, reach=60.0):
    """The passable width (m) ACROSS the route at each point: the free span perpendicular to the direction of travel.

    ROUND 9 (scale), at squad's request. squad measured the Condemned `artillery` failing to cross the maze's
    defile at its pre-CP2 2.6 m width -- four squadmates used the same corridor in the same run and it never
    arrived in 70 s -- and asked whether the maps a player plays are dimensioned like the maze fixture.

    ⚠ THE FIRST VERSION OF THIS FUNCTION WAS WRONG AND ITS TABLE WAS CIRCULATED. It returned **twice the distance
    to the nearest obstacle**, which is the corridor width only when there is an obstacle on BOTH sides. On yard it
    reported the tightest point as 4.72 m; the route there passes 2.71 m from a single wreck with **20 m of open
    ground on the other side**, so the real span is 23 m. Every map looked like it had a pinch, and what was
    actually being measured was "how close does the route pass to one prop" -- a quantity no vehicle cares about.
    The lesson is the project's own: a confidently wrong instrument is worse than none, and it nearly bought a
    map-widening change.

    So: march PERPENDICULAR to the direction of travel, both ways, until something tall is hit or `reach` is spent,
    and sum. That is the gap a hull has to fit through. Measured against the obstacles' own footprints, not the
    agent-inflated navmesh -- what the router then believes is a separate question with its own radius.
    """
    if not path or len(path) < 2:
        return []
    tall = [b for b in boxes if b.h >= EYE_HEIGHT]
    out = []
    for i in range(0, len(path), step):
        x, z = path[i]
        ahead = path[min(i + 1, len(path) - 1)]
        behind = path[max(i - 1, 0)]
        dx, dz = ahead[0] - behind[0], ahead[1] - behind[1]
        span = math.hypot(dx, dz)
        if span < 1e-6:
            continue
        # The normal to the direction of travel.
        nx, nz = -dz / span, dx / span
        free = 0.0
        for sign in (-1.0, 1.0):
            reached = 0.0
            while reached < reach:
                reached += probe
                px, pz = x + sign * nx * reached, z + sign * nz * reached
                if any(b.distance(px, pz) <= 0.01 for b in tall):
                    break
            free += reached
        out.append((round(x, 1), round(z, 1), round(free, 2)))
    return out


## R4 (round 10): STREETS ARE LANES. The authority is `ArenaLanes` (game/arena/arena_lanes.gd) and its assertion
## `tests/test_arena_lanes.gd`, which run in `make check`; this is the same measurement for the page and for
## `make arena-report`, which FAILS (exit 1) on a short lane of an asserted layout. The round-9 corridor WATCH line
## stays a watch line for the open field; for declared lanes the question was closed by the lead's ruling.
##
## Every input is READ: the widest hull and the rig's turning radius from `game/units/units.gd`, the bake radius from
## `arena.tscn`'s NavigationMesh, the report-only list and the junction turn from `ArenaLanes`, the perimeter's
## sides from `ArenaShape.KINDS`. The one thing mirrored is the algorithm, and `test_the_lane_table_matches_the_game`
## pins it to the GDScript's numbers on the Terminus.
ARENA_TSCN = pathlib.Path(__file__).resolve().parent.parent / "game" / "arena" / "arena.tscn"
ARENA_LANES_GD = pathlib.Path(__file__).resolve().parent.parent / "game" / "arena" / "arena_lanes.gd"
ARENA_SHAPE_GD = pathlib.Path(__file__).resolve().parent.parent / "game" / "arena" / "arena_shape.gd"


def lane_bar():
    import gdscript_source, re
    hulls = units_catalog.load()
    widest = max(hulls, key=lambda u: float(hulls[u]["hull_size"][0]))
    rig = max(hulls, key=lambda u: float(hulls[u].get("min_turn_radius_m", 0.0)))
    found = re.search(r"^agent_radius = ([0-9.]+)$", ARENA_TSCN.read_text(), re.M)
    if not found:
        raise RuntimeError("arena.tscn declares no NavigationMesh agent_radius; the lane bar cannot be read")
    bake = float(found.group(1))
    w = float(hulls[widest]["hull_size"][0])
    return {"widest_hull": widest, "widest_hull_m": w, "bake_radius_m": bake, "drivable_bar_m": 2 * w,
            "physical_bar_m": 2 * w + 2 * bake, "rig": rig, "rig_min_turn_m": float(hulls[rig]["min_turn_radius_m"]),
            "junction_turn_deg": gdscript_source.const_float(ARENA_LANES_GD, "JUNCTION_TURN_DEG"),
            "report_only": list(gdscript_source.const(ARENA_LANES_GD, "REPORT_ONLY"))}


def perimeter_polygon(layout):
    """`ArenaShape.vertices`: a regular polygon whose widest axis extent is `half_size`, counter-clockwise."""
    import gdscript_source
    kind = (layout.get("shape") or {}).get("kind", "square")
    n = int(gdscript_source.const(ARENA_SHAPE_GD, "KINDS").get(kind, 4))
    bound = float(layout.get("half_size", 120.0))
    widest = max(abs(math.sin(2 * math.pi * k / n + math.pi / n)) for k in range(n))
    radius = bound / widest
    return [(radius * math.sin(2 * math.pi * k / n + math.pi / n), radius * math.cos(2 * math.pi * k / n + math.pi / n))
            for k in range(n)]


def _ray_exit_polygon(poly, px, pz, dx, dz, reach):
    best = reach
    for i in range(len(poly)):
        ax, az = poly[i]
        bx, bz = poly[(i + 1) % len(poly)]
        ex, ez = bx - ax, bz - az
        den = dx * ez - dz * ex
        if abs(den) < 1e-12:
            continue
        t = ((ax - px) * ez - (az - pz) * ex) / den
        u = ((ax - px) * dz - (az - pz) * dx) / den
        if 0.0 <= u <= 1.0 and t >= 0.0:
            best = min(best, t)
    return best


def _clearance(boxes, poly, x, z):
    best = min((b.distance(x, z) for b in boxes), default=1e9)
    for i in range(len(poly)):
        ax, az = poly[i]
        bx, bz = poly[(i + 1) % len(poly)]
        ex, ez = bx - ax, bz - az
        t = max(0.0, min(1.0, ((x - ax) * ex + (z - az) * ez) / (ex * ex + ez * ez)))
        best = min(best, math.hypot(x - ax - t * ex, z - az - t * ez))
    return best


def lane_table(layout, boxes, bar=None, step=1.0, reach=60.0):
    """Per declared lane: the narrowest physical width across it (every collider counts, low ones too: `boxes_of`
    keeps barricades) and where; per lane bend and lane crossing: the rig's r_eff against the clear disc. The same
    numbers as `ArenaLanes.describe`. Terrain (water, pits) is NOT modelled here; the GDScript measures it."""
    bar = bar or lane_bar()
    poly = perimeter_polygon(layout)
    lanes_out, corners = [], []
    for lane in layout.get("lanes", []):
        pts = lane["points"]
        narrow, at = 1e9, None
        for i in range(1, len(pts)):
            (ax, az), (bx, bz) = pts[i - 1], pts[i]
            leg = math.hypot(bx - ax, bz - az)
            if leg < 1e-6:
                continue
            ux, uz = (bx - ax) / leg, (bz - az) / leg
            nx, nz = -uz, ux
            steps = max(1, math.ceil(leg / step))
            for k in range(steps + 1):
                px, pz = ax + ux * leg * k / steps, az + uz * leg * k / steps
                width = 0.0
                for sgn in (1.0, -1.0):
                    dx, dz = sgn * nx, sgn * nz
                    far = reach
                    for b in boxes:
                        t = entry_t(b, px, pz, px + dx * reach, pz + dz * reach)
                        if t is not None:
                            far = min(far, t * reach)
                    width += min(far, _ray_exit_polygon(poly, px, pz, dx, dz, reach))
                if width < narrow:
                    narrow, at = width, (px, pz)
        drivable = narrow - 2 * bar["bake_radius_m"]
        lanes_out.append({"name": lane["name"], "narrowest_physical_m": round(narrow, 2),
                          "narrowest_drivable_m": round(drivable, 2), "at": [round(at[0], 1), round(at[1], 1)],
                          "pass": drivable >= bar["drivable_bar_m"] - 0.001})
    r_a = bar["physical_bar_m"] / 2
    found = []
    lanes = layout.get("lanes", [])
    for lane in lanes:
        pts = lane["points"]
        for i in range(1, len(pts) - 1):
            a0 = math.atan2(pts[i][1] - pts[i - 1][1], pts[i][0] - pts[i - 1][0])
            a1 = math.atan2(pts[i + 1][1] - pts[i][1], pts[i + 1][0] - pts[i][0])
            delta = abs(math.degrees(math.remainder(a1 - a0, 2 * math.pi)))
            if delta >= 1.0:
                found.append({"where": tuple(pts[i]), "lanes": [lane["name"]], "delta_deg": delta})
    for i in range(len(lanes)):
        for j in range(i + 1, len(lanes)):
            seen = []
            pa, pb = lanes[i]["points"], lanes[j]["points"]
            for a in range(1, len(pa)):
                for b in range(1, len(pb)):
                    hit = _segments_cross(pa[a - 1], pa[a], pb[b - 1], pb[b])
                    if hit is None:
                        continue
                    ang = abs(math.degrees(math.remainder(
                        math.atan2(pb[b][1] - pb[b - 1][1], pb[b][0] - pb[b - 1][0])
                        - math.atan2(pa[a][1] - pa[a - 1][1], pa[a][0] - pa[a - 1][0]), 2 * math.pi)))
                    if min(ang, 180 - ang) < 1.0 or any(math.dist(hit, s) < 0.5 for s in seen):
                        continue
                    seen.append(hit)
                    found.append({"where": hit, "lanes": [lanes[i]["name"], lanes[j]["name"]],
                                  "delta_deg": bar["junction_turn_deg"]})
    for c in found:
        d = math.radians(c["delta_deg"])
        r_eff = r_a + bar["rig_min_turn_m"] * (1 / math.cos(d / 2) - 1) if d < math.pi - 0.01 else float("inf")
        clear = _clearance(boxes, poly, *c["where"])
        corners.append({"where": [round(c["where"][0], 1), round(c["where"][1], 1)], "lanes": c["lanes"],
                        "delta_deg": round(c["delta_deg"], 1), "r_eff_m": round(r_eff, 2),
                        "clearance_m": round(clear, 2), "pass": clear >= r_eff - 0.001})
    return {"bar": {k: v for k, v in bar.items() if k != "report_only"}, "lanes": lanes_out, "corners": corners}


def _segments_cross(a0, a1, b0, b1):
    rx, rz = a1[0] - a0[0], a1[1] - a0[1]
    sx, sz = b1[0] - b0[0], b1[1] - b0[1]
    den = rx * sz - rz * sx
    if abs(den) < 1e-12:
        return None
    t = ((b0[0] - a0[0]) * sz - (b0[1] - a0[1]) * sx) / den
    u = ((b0[0] - a0[0]) * rz - (b0[1] - a0[1]) * rx) / den
    if -1e-9 <= t <= 1 + 1e-9 and -1e-9 <= u <= 1 + 1e-9:
        return (a0[0] + t * rx, a0[1] + t * rz)
    return None


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


def field_points(blocked, n, step=EXPOSURE_STEP, half=None):
    """Drivable sample points across the contested field. `half` caps the window, so a measure can be taken over a
    fixed extent rather than whatever the layout declares."""
    out = []
    # A fixed window ignores DRIVABLE/FIELD_Z entirely: deriving it from them would make it vary with the very
    # thing it exists to be independent of. 4 m in from the edge and 70% deep are the shipped proportions.
    reach = (half - 4.0) if half else DRIVABLE
    depth = (half * 0.7) if half else FIELD_Z
    # ANCHOR THE LATTICE AT THE ORIGIN. `_exposure_at` looks a route's point up by rounding to a multiple of
    # EXPOSURE_STEP, so the field's own keys must be multiples of it too. They were not once the window followed
    # the layout: at half_size 140 the depth is 98, so z ran -98, -94, -90 … and EVERY lookup missed, returning
    # the default 0.0. Exposure read 0.000 across both hexagonal maps -- a perfectly plausible number for a map
    # full of containers, and completely wrong. A square's 84 happens to be a multiple of 4, which is why this
    # never showed until an arena changed size.
    reach = math.floor(reach / step) * step
    depth = math.floor(depth / step) * step
    z = -depth
    while z <= depth:
        x = -reach
        while x <= reach:
            if not blocked[int((z + HALF) / GRID) * n + int((x + HALF) / GRID)]:
                out.append((x, z))
            x += step
        z += step
    return out


def standing_point(blocked, n, want):
    """The nearest DRIVABLE point to `want`. An observer placed inside a box sees nothing at all, and foundry has a
    crate on the exact centre: the first version of centre_sees_share reported 0.000 for the most open arena in the
    game. An eye has to be somewhere a vehicle could be."""
    # Search wide enough to leave any footprint: the 12-cell default could not get out of a 40 m city block from its
    # centre, so the eye stayed inside it and centre_sees read 0.00 (round 10, terrain's finding).
    cell = snap(blocked, n, (int((want[0] + HALF) / GRID), int((want[1] + HALF) / GRID)), reach=int(60 / GRID))
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


def front_row(layout, side):
    """The spawn points nearest the centre line: the row an army actually forms up on.

    Round 9 (scale): this used to be a slice of the first 13 spawn points, 13 being `Match.SLOT_X.size()` at the
    time -- a mirror of the grid's column count, hidden in a slice, with nothing naming it. When the grid went from
    13 columns x 4 rows to 19 x 3, the slice quietly took two thirds of the front row instead of all of it, and the
    only symptom was the route optimiser's monotonicity test wobbling by 0.001. Read the row off the points.
    """
    points = [tuple(pt) for pt in layout["spawns"][side]]
    nearest = min(abs(z) for _, z in points)
    return [(x, z) for x, z in points if abs(abs(z) - nearest) < 0.01]


def defending_positions(boxes, layout):
    """The enemy's covered firing positions: 4 m out from each piece of hard cover on the north half, plus its front
    spawn row. Subsampled evenly to WATCHER_SAMPLE so the pass stays cheap and stable."""
    spots = [(b.x, b.z - (b.d / 2 + 4.0)) for b in boxes if b.h >= EYE_HEIGHT and b.z < -10.0]
    spots += front_row(layout, "rust")
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


# ---- Round 7: cost AND reward. What a route costs, and what it reaches. --------------------------------------
#
# X2 scored a route by what it COSTS and never by what it REACHES, so it kept reporting that every arena offers a
# cheap flank while the game plays as one brawl. The lead named the missing half: *"there generally has to be some
# compelling reason to cross the bridge to take some advantageous ground."* A route that is cheap and leads nowhere
# worth going is not a tactical option, it is scenery.
#
# Reward is computable now that objectives are data. For each objective, the least-exposed route to it from green's
# base gives one (cost, reward) point; **a map's decision space is the SPREAD of those points.** One central
# objective produces exactly one point and therefore zero spread — which is not a failure of the metric, it is the
# diagnosis: with one thing worth holding, every route is the same route, and no terrain can change that.

## How much of an objective a position must see before it counts as denying it.
DENY_SHARE = 0.25
## Cost/reward thresholds for the quadrant labels. Deliberately round: this classifies, it does not rank.
COSTLY = 0.25
VALUABLE = 0.5


def objectives_of(layout):
    """Mirrors Arena.objectives_of: the layout's own list, else the single central control point."""
    listed = layout.get("objectives", [])
    if listed:
        return [{"name": o["name"], "at": (float(o["position"][0]), float(o["position"][1])),
                 "radius": float(o["radius"])} for o in listed]
    control = layout.get("control_point")
    if isinstance(control, dict):
        return [{"name": "control point", "at": (0.0, 0.0), "radius": float(control.get("radius", 16.0))}]
    return []


def covers_objective(grid, gn, spot, objective, reach):
    """Share of a ring of sample points around the objective that `spot` can see and reach."""
    seen = 0
    for k in range(12):
        a = 2 * math.pi * k / 12
        p = (objective["at"][0] + math.cos(a) * objective["radius"] * 0.7,
             objective["at"][1] + math.sin(a) * objective["radius"] * 0.7)
        if math.dist(spot, p) <= reach and sees(grid, gn, spot[0], spot[1], p[0], p[1]):
            seen += 1
    return seen / 12.0


def decision_report(layout, boxes, blocked, n, grid, gn, field, watchers):
    """One (cost, reward) point per objective, from GREEN's side.

    The cost axis is **contest**, not raw distance, and that took a wrong version to find. Measuring cost as
    exposure plus detour-over-straight-line gave a mirrored pair two nearly identical points (spread 0.04) and
    called them both free — because a pair IS symmetric by construction, so neither route is intrinsically harder.

    What actually differs is **whose objective it is**. A mirrored pair puts one near green and its twin near rust,
    so each side has a home objective it can hold cheaply and an away one it must contest. That is precisely the
    dilemma combat's share-of-objectives scoring creates: hold your own and score at half rate, or go and take
    theirs and score at full. So cost = how much further it is for me than for the enemy, plus what the trip is
    exposed to — and a map whose objectives are all equidistant offers no contest and therefore no decision,
    however far apart they are.
    """
    objectives = objectives_of(layout)
    if not objectives:
        return {"objectives": 0, "routes": [], "decision_spread": 0.0}
    green = tuple(layout["spawns"]["green"][0])
    routes = []
    for objective in objectives:
        mine = covered_route(blocked, n, field, green, objective["at"], 6.0)
        # The ENEMY routes against ITS OWN exposure field (round 10, terrain's finding): `field` is exposure to
        # RUST's watchers, so routing rust through it priced rust's trip by its own guns and flipped terrain's river
        # map between spread 0.45 and 0.03 on one alley. Every layout is point-symmetric (Arena.validate), so rust's
        # field is green's turned 180 degrees and rust's covered route to X is green's covered route to -X, mirrored.
        at = objective["at"]
        theirs = covered_route(blocked, n, field, green, (-at[0], -at[1]), 6.0)
        if mine is None:
            routes.append({"objective": objective["name"], "reachable": False})
            continue
        my_len = length(mine)
        their_len = length(theirs) if theirs else my_len
        # 0.5 = equidistant; above that the enemy is closer and taking it is contested.
        contest = my_len / max(1.0, my_len + their_len)
        exposure_cost = route_exposure(field, mine)
        cost = min(1.0, exposure_cost * 3.0 + max(0.0, contest - 0.5) * 4.0)
        hold = 1.0 / len(objectives)
        deny = 0.0
        for other in objectives:
            if other["name"] == objective["name"]:
                continue
            if covers_objective(grid, gn, objective["at"], other, WATCHER_REACH_M["posted"]) >= DENY_SHARE:
                deny += 0.5 / len(objectives)
        reward = min(1.0, hold + deny)
        costly = cost >= COSTLY
        valuable = reward >= VALUABLE
        routes.append({"objective": objective["name"], "reachable": True,
                       "length_m": round(my_len, 1), "enemy_length_m": round(their_len, 1),
                       "contest": round(contest, 3), "exposure": round(exposure_cost, 3),
                       "cost": round(cost, 3), "reward": round(reward, 3),
                       "quadrant": ("the one we want" if costly and valuable else
                                    "dominant" if valuable else "trap" if costly else "scenery")})
    live = [r for r in routes if r.get("reachable")]
    spread = 0.0
    for i in range(len(live)):
        for j in range(i + 1, len(live)):
            spread = max(spread, math.dist((live[i]["cost"], live[i]["reward"]),
                                           (live[j]["cost"], live[j]["reward"])))
    return {"objectives": len(objectives), "routes": routes, "decision_spread": round(spread, 3)}


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
    # Fixed window: comparable across arena sizes, and the one the <0.30 target is calibrated against.
    calibrated = field_points(blocked, n, 6.0, CALIBRATION_HALF)
    out = {"centre_sees_share": round(visible_share(grid, gn, centre, calibrated), 3),
           "centre_sees_share_full": round(visible_share(grid, gn, centre, points), 3),
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
    out["decision"] = decision_report(layout, boxes, blocked, n, grid, gn, field, watchers)
    return out


def use_extent(layout):
    """Point the report's grid at THIS layout's arena. Module-level because every geometry helper below reads them;
    `analyze()` is the only caller and it sets them before touching anything else."""
    global HALF, DRIVABLE, FIELD_Z
    half = float(layout.get("half_size", 120.0))
    HALF = half + 40.0        # the bake margin, so the grid covers everything a navmesh could
    DRIVABLE = half - 4.0     # a hull's clearance inside the wall
    FIELD_Z = half * 0.7      # the contested field, as it has always been proportioned (84 of 120)


def analyze(layout):
    use_extent(layout)
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
    # S1/round 9: the tightest place on the route a whole army has to file through, against the roster's widest
    # hull. Both halves READ from their owners -- the corridor from the layout's own obstacles, the hull from
    # `game/units/units.gd` via `tools/units_catalog.py` -- so neither can go stale behind a comment.
    widths = corridor_widths(boxes, direct)
    if widths:
        tightest = min(widths, key=lambda w: w[2])
        hulls = units_catalog.load()
        widest_id = max(hulls, key=lambda u: hulls[u]["hull_size"][0])
        report["corridor"] = {
            "narrowest_m": tightest[2], "narrowest_at": [tightest[0], tightest[1]],
            "widest_hull": widest_id, "widest_hull_m": round(float(hulls[widest_id]["hull_size"][0]), 2),
            "hulls_that_fit": sum(1 for u in hulls if float(hulls[u]["hull_size"][0]) + 1.0 <= tightest[2]),
            "hulls": len(hulls),
        }
    to_centre = route(blocked, n, green_front, (0.0, 0.0))
    report["base_to_centre_m"] = round(length(to_centre), 1) if to_centre else None
    # Watchers: the enemy's covered positions, approximated by points 4 m outside hard cover on the north half.
    watchers = [(b.x, b.z - (b.d / 2 + 4.0)) for b in boxes if b.h >= EYE_HEIGHT and b.z < -10.0]
    watchers += front_row(layout, "rust")
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
    report["lane_table"] = lane_table(layout, boxes)
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
    short = []
    bar = lane_bar()
    for file in args.layouts:
        with open(file) as f:
            layout = json.load(f)
        report = analyze(layout)
        if args.plot:
            report["plot"] = plot(layout, report, args.plot)
        hulls = hull_lengths()
        if hulls:
            name = max(hulls, key=lambda k: hulls[k])
            report["hull_cover"] = {
                "longest_hull": name, "longest_hull_m": hulls[name],
                # A3 (round 9): kept, and kept LABELLED. `reach` is the superseded centre-point measure; the
                # game's cover query is `Arena.cover_fraction` and `make arena-cover` reports it.
                "definition": "centre-point (SUPERSEDED by A3: Arena.cover_fraction)",
                "reach": round(hull_cover_reach(layout, report["_boxes"], hulls[name]), 3),
                # The kit's longest prop is the cliff: cover is a step function of hull length, not a gradient.
                "longest_prop_m": round(max((max(b.w, b.d) for b in report["_boxes"]), default=0.0), 2)}
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
        for note in openness_notes(clean):
            print("WATCH %-10s %s" % (clean["name"], note))
        # R4: lanes are ASSERTED (the corridor WATCH above stays a watch line for the open field).
        asserted = clean["name"] not in bar["report_only"] and not layout.get("fixture", False)
        for lane in clean["lane_table"]["lanes"]:
            verdict = "ok" if lane["pass"] else ("LANE_FAIL" if asserted else "short (report only)")
            print("LANE %-10s %-24s narrowest %6.2f m physical, %6.2f m drivable (bar %.2f) at [%.0f, %.0f]  %s"
                  % (clean["name"], lane["name"], lane["narrowest_physical_m"], lane["narrowest_drivable_m"],
                     bar["drivable_bar_m"], lane["at"][0], lane["at"][1], verdict))
            if asserted and not lane["pass"]:
                short.append("%s / %s" % (clean["name"], lane["name"]))
        for corner in clean["lane_table"]["corners"]:
            verdict = "ok" if corner["pass"] else ("CORNER_FAIL" if asserted else "short (report only)")
            print("CORNER %-10s %s at [%.0f, %.0f]: turn %.0f deg, rig r_eff %.2f m (R_min %.1f), clearance %.2f m  %s"
                  % (clean["name"], " x ".join(corner["lanes"]), corner["where"][0], corner["where"][1],
                     corner["delta_deg"], corner["r_eff_m"], bar["rig_min_turn_m"], corner["clearance_m"], verdict))
            if asserted and not corner["pass"]:
                short.append("%s / corner %s" % (clean["name"], " x ".join(corner["lanes"])))
        d = a.get("decision", {})
        print("DECISION %-10s objectives=%d  spread=%.2f  %s"
              % (clean["name"], d.get("objectives", 0), d.get("decision_spread", 0.0),
                 ", ".join("%s: %s" % (r["objective"], r.get("quadrant", "unreachable"))
                           for r in d.get("routes", [])) or "-"))
        print("ARENA_REPORT " + json.dumps(clean))
    if args.json:
        os.makedirs(os.path.dirname(args.json) or ".", exist_ok=True)
        with open(args.json, "w") as f:
            json.dump(reports, f, indent=1)
    if short:
        print("arena_report: R4 FAILED -- %d asserted lane(s)/corner(s) short of the bar: %s" % (len(short), "; ".join(short)))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
