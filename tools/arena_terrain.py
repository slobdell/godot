"""Water, pits and bridges for the Python arena tools (terrain stream, round 10).

`game/arena/arena_terrain.gd` builds terrain in the game; this is what `tools/arena_report.py` and
`tools/make_arenas.py` need to see the same ground: which cells a hull cannot drive (the carved footprint, its rim
and the bridge rails, grown by the bake radius, exactly as the navmesh is) and where the rims and rails stand.

**Before this, the report ignored `terrain` entirely**, so a river map's routes, `spread` and exposure would have
been measured as if the river were floor -- a confident, wrong number on exactly the maps the measurement exists
for.

It MIRRORS `rim_slabs()` and `rail_slabs()` in GDScript, which is the one thing this project writes lessons
against (Invariant 0), so the mirror is pinned rather than trusted: both implementations are tested against the SAME
golden file (`tests/fixtures/terrain_golden.json`; `tests/test_terrain_golden.gd` and `tools/test_arena_terrain.py`),
and every constant is READ from the GDScript source, never copied.
"""
from __future__ import annotations

import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import gdscript_source

TERRAIN_GD = gdscript_source.GAME / "arena" / "arena_terrain.gd"
RIM_HEIGHT = gdscript_source.const_float(TERRAIN_GD, "RIM_HEIGHT")
RIM_THICKNESS = gdscript_source.const_float(TERRAIN_GD, "RIM_THICKNESS")
RAIL_HEIGHT = gdscript_source.const_float(TERRAIN_GD, "RAIL_HEIGHT")
RAIL_THICKNESS = gdscript_source.const_float(TERRAIN_GD, "RAIL_THICKNESS")
EDGE_EPSILON = gdscript_source.const_float(TERRAIN_GD, "EDGE_EPSILON")
KINDS = gdscript_source.const(TERRAIN_GD, "KINDS")


def min_deck_m():
    """`ArenaTerrain.min_deck_m()`: the R4 lane bar's physical width (`arena_report.lane_bar()`, which reads the
    catalog and arena.tscn live, as `ArenaLanes.bar()` does) plus a rail each side. Imported lazily: arena_report
    imports this module."""
    import arena_report
    return arena_report.lane_bar()["physical_bar_m"] + 2.0 * RAIL_THICKNESS


def carves(kind):
    return bool(KINDS[kind]["carves"])


def is_deck(kind):
    return bool(KINDS[kind]["deck"])


def bounds(entry):
    """[min_x, min_z, max_x, max_z] of a terrain entry's rect [centre_x, centre_z, width, depth]."""
    x, z, w, d = (float(v) for v in entry["rect"])
    return [x - w / 2.0, z - d / 2.0, x + w / 2.0, z + d / 2.0]


def _spans(lo, hi, decks, along_x):
    blocked = []
    for d in decks:
        a, b = (d[0], d[2]) if along_x else (d[1], d[3])
        if b > lo and a < hi:
            blocked.append([max(a, lo), min(b, hi)])
    blocked.sort()
    out, cursor = [], lo
    for a, b in blocked:
        if a > cursor:
            out.append([cursor, a])
        cursor = max(cursor, b)
    if cursor < hi:
        out.append([cursor, hi])
    return out


def _crosses(lo, hi, line, low_side):
    if low_side:
        return lo <= line + EDGE_EPSILON and hi > line + EDGE_EPSILON
    return hi >= line - EDGE_EPSILON and lo < line - EDGE_EPSILON


def _beyond(lo, hi, line, low_side):
    probe = line - EDGE_EPSILON * 10.0 if low_side else line + EDGE_EPSILON * 10.0
    return lo < probe and hi > probe


def rim_slabs(entry, terrain):
    """Mirrors ArenaTerrain.rim_slabs: [[cx, cz, w, d], ...] around one carving footprint, cut where a deck crosses
    and where another carved footprint lies beyond the edge."""
    box = bounds(entry)
    decks = [bounds(o) for o in terrain if is_deck(o["kind"])]
    wet = [bounds(o) for o in terrain if carves(o["kind"]) and o != entry]
    out = []
    for side in (0, 1):
        line = box[1] if side == 0 else box[3]
        z = line - RIM_THICKNESS / 2.0 if side == 0 else line + RIM_THICKNESS / 2.0
        crossing = [d for d in decks if _crosses(d[1], d[3], line, side == 0)]
        crossing += [w for w in wet if _beyond(w[1], w[3], line, side == 0)]
        for a, b in _spans(box[0], box[2], crossing, True):
            out.append([(a + b) / 2.0, z, b - a, RIM_THICKNESS])
    for side in (0, 1):
        line = box[0] if side == 0 else box[2]
        x = line - RIM_THICKNESS / 2.0 if side == 0 else line + RIM_THICKNESS / 2.0
        crossing = [d for d in decks if _crosses(d[0], d[2], line, side == 0)]
        crossing += [w for w in wet if _beyond(w[0], w[2], line, side == 0)]
        for a, b in _spans(box[1], box[3], crossing, False):
            out.append([x, (a + b) / 2.0, RIM_THICKNESS, b - a])
    return out


def _wet_spans(lo, hi, holes, decks, across, along_x):
    wet = []
    for h in holes:
        a_lo, a_hi = (h[1], h[3]) if along_x else (h[0], h[2])
        if across <= a_lo or across >= a_hi:
            continue
        h_lo, h_hi = (h[0], h[2]) if along_x else (h[1], h[3])
        covering = [d for d in decks if ((d[1] < across < d[3]) if along_x else (d[0] < across < d[2]))]
        for a, b in _spans(max(h_lo, lo), min(h_hi, hi), covering, along_x):
            if b > a:
                wet.append([max(lo, a - RIM_THICKNESS), min(hi, b + RIM_THICKNESS)])
    wet.sort()
    merged = []
    for a, b in wet:
        if merged and a <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], b)
        else:
            merged.append([a, b])
    return merged


def rail_slabs(deck_entry, terrain):
    """Mirrors ArenaTerrain.rail_slabs: the rails standing on one deck along every side that borders water."""
    deck = bounds(deck_entry)
    holes = [bounds(o) for o in terrain if carves(o["kind"])]
    others = [bounds(o) for o in terrain if is_deck(o["kind"]) and o is not deck_entry and o != deck_entry]
    out = []
    for side in (0, 1):
        x_edge = deck[0] - EDGE_EPSILON * 10.0 if side == 0 else deck[2] + EDGE_EPSILON * 10.0
        x = deck[0] + RAIL_THICKNESS / 2.0 if side == 0 else deck[2] - RAIL_THICKNESS / 2.0
        for a, b in _wet_spans(deck[1], deck[3], holes, others, x_edge, False):
            out.append([x, (a + b) / 2.0, RAIL_THICKNESS, b - a])
    for side in (0, 1):
        z_edge = deck[1] - EDGE_EPSILON * 10.0 if side == 0 else deck[3] + EDGE_EPSILON * 10.0
        z = deck[1] + RAIL_THICKNESS / 2.0 if side == 0 else deck[3] - RAIL_THICKNESS / 2.0
        for a, b in _wet_spans(deck[0], deck[2], holes, others, z_edge, True):
            out.append([(a + b) / 2.0, z, b - a, RAIL_THICKNESS])
    return out


def walls(terrain):
    """Every rim and rail box of a layout's terrain, as [cx, cz, w, d]: what a hull stops against."""
    out = []
    for entry in terrain:
        if carves(entry["kind"]):
            out += rim_slabs(entry, terrain)
        elif is_deck(entry["kind"]):
            out += rail_slabs(entry, terrain)
    return out


def _rect_distance(rect, x, z):
    cx, cz, w, d = rect
    ox = max(abs(x - cx) - w / 2.0, 0.0)
    oz = max(abs(z - cz) - d / 2.0, 0.0)
    return math.hypot(ox, oz)


def _on_deck(decks, x, z):
    return any(d[0] < x < d[2] and d[1] < z < d[3] for d in decks)


def in_water(terrain, x, z):
    """True where the ground is carved and no deck restores it: a point a hull can never stand on."""
    decks = [bounds(o) for o in terrain if is_deck(o["kind"])]
    for entry in terrain:
        if not carves(entry["kind"]):
            continue
        b = bounds(entry)
        if b[0] < x < b[2] and b[1] < z < b[3] and not _on_deck(decks, x, z):
            return True
    return False


def carve(blocked, n, layout, half, grid, radius):
    """Mark `blocked` (the report's occupancy grid, n x n cells of `grid` m over +-`half`) the way the navmesh bake
    does: every cell within `radius` of carved ground (not decked), of a rim, or of a rail. Returns the count added.

    Carved ground is exact per cell centre (a cell is wet or not) and the inflation is measured to the nearest wet
    cell or wall box, so the result is the navmesh's erosion to within one grid cell."""
    terrain = layout.get("terrain") or []
    if not terrain:
        return 0
    decks = [bounds(o) for o in terrain if is_deck(o["kind"])]
    boxes = walls(terrain)
    holes = [bounds(o) for o in terrain if carves(o["kind"])]
    added = 0
    reach = int(math.ceil(radius / grid)) + 1

    def centre(g):
        return g * grid - half + grid / 2.0

    # 1. Wet cells, and the band `radius` around them.
    wet = set()
    for h in holes:
        for gx in range(max(0, int((h[0] + half) / grid)), min(n, int((h[2] + half) / grid) + 1)):
            for gz in range(max(0, int((h[1] + half) / grid)), min(n, int((h[3] + half) / grid) + 1)):
                x, z = centre(gx), centre(gz)
                if h[0] < x < h[2] and h[1] < z < h[3] and not _on_deck(decks, x, z):
                    wet.add((gx, gz))
    r2 = (radius / grid) ** 2
    for gx, gz in wet:
        # Only a wet cell on the boundary can be the nearest one to a dry cell; interior cells add nothing new.
        if all((gx + dx, gz + dz) in wet for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            idx = gz * n + gx
            if not blocked[idx]:
                blocked[idx] = 1
                added += 1
            continue
        for dx in range(-reach, reach + 1):
            for dz in range(-reach, reach + 1):
                if dx * dx + dz * dz >= r2 and (dx, dz) != (0, 0):
                    continue
                x, z = gx + dx, gz + dz
                if 0 <= x < n and 0 <= z < n and not blocked[z * n + x]:
                    blocked[z * n + x] = 1
                    added += 1
    # 2. Rims and rails, grown by the radius like any wall.
    for box in boxes:
        cx, cz, w, d = box
        for gx in range(max(0, int((cx - w / 2 - radius + half) / grid) - 1), min(n, int((cx + w / 2 + radius + half) / grid) + 2)):
            for gz in range(max(0, int((cz - d / 2 - radius + half) / grid) - 1), min(n, int((cz + d / 2 + radius + half) / grid) + 2)):
                if blocked[gz * n + gx]:
                    continue
                if _rect_distance(box, centre(gx), centre(gz)) < radius:
                    blocked[gz * n + gx] = 1
                    added += 1
    return added
