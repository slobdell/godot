#!/usr/bin/env python3
"""Round 18 (maps, M2): the qualities the lead named, as numbers per map, before he plays it.

His words (2026-10-04): *"the best maps will be ones where there is room for vehicles to maneuver, perhaps some
chokepoints in the map, and opportunities to really use formations like screens and ambushes ... a large open center
that allows us to use these big formations, but then create the necessary cover such that any team using a line
abreast formation could easily be ambushed from cover (i.e. a line abreast formation could get ambushed by another
formation that was orthogonal)"*.

Four measures, all static geometry (no Godot, no match), on the same ground `arena_report` sees (its occupancy grid:
every collider grown by the 2 m bake radius, terrain carved), plus the perimeter polygon, which the report's square
grid does not mask:

ROOM (a). The share of the drivable ground a LINE OF FOUR at its own spacing can drive through, and the same for a
  WEDGE OF FOUR. A cell counts when the free drivable span across the formation's frontage, through that cell, is at
  least the formation's frontage for one formation-depth of travel (in any of four headings: the two axes and the two
  diagonals). The frontages are READ from `TacticsFormation` (spacing, diagonal factor, corridor margin) and are
  hull-centre spans: the drivable grid is already inset by the bake radius, which is about half the widest hull.
  Approximation, stated: the runs at successive depths need not line up laterally (a staircase passes); the error is
  on the generous side by at most a few metres of offset per metre of depth, and the dealt maps' lanes are straight.
  Also: the WIDEST frontage the field allows anywhere (one spacing of travel), in metres and in vehicles abreast.

CHOKEPOINTS (b). On the routes a match uses (base to base; base to every objective), every stretch where the drivable
  width across the route is narrower than a line of four's frontage. A stretch no longer than CHOKE_MAX_M with wider
  ground at both ends is a CHOKEPOINT (a neck); a longer one is CORRIDOR. For each chokepoint: its width, where, and
  whether there is a way round -- the throat is sealed and the same trip re-routed -- with the detour as a ratio.
  Iterated (seal, re-route, look again) so a map's second and third necks are found.

AMBUSH (c). A line of four crosses the centre on each of four axes (base to base, the two diagonals, side to side).
  At each station of its crossing, the ambush ground is every drivable cell that (1) lies off the line's END: the
  bearing from the line's centre within FLANK_DEG of the line's own axis, so fire from there runs down the line
  (the ambusher's formation is at right angles to the line's advance); (2) is within posted weapon reach of the
  line's nearest hull (`build/arena-reach.json`, the catalog's covering range, as `arena_report`); (3) sees at least
  two of the line's hulls at eye level; and (4) is UNSEEN from every hull of the line at its start (START_M back
  along its advance). Cells merge into positions; each position's capacity is how many hulls stand in it HIDE_GAP_M
  apart. A station where the line cannot stand (a hull on a collider) scores nothing, which is what a corridor map is.

CENTRE (d). `centre_sees_share` and the existing report, for the record (the lead's round-9 cut followed it).

Usage: python3 tools/arena_room.py arenas/yard.json ... [--json out.json] [--plot DIR] [--no-report]
Prints one ROOM line per layout (and ROOM_CHOKE / ROOM_AMBUSH detail lines).
"""
from __future__ import annotations

import argparse
import heapq
import json
import math
import os
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import arena_report as ar  # noqa: E402
import arena_terrain  # noqa: E402
import gdscript_source  # noqa: E402

TACTICS_FORMATION = gdscript_source.GAME / "tactics" / "tactics_formation.gd"
SPACING = gdscript_source.const_float(TACTICS_FORMATION, "DEFAULT_SPACING")
DIAGONAL_SIDE = gdscript_source.const_float(TACTICS_FORMATION, "DIAGONAL_SIDE")
CORRIDOR_MARGIN = gdscript_source.const_float(TACTICS_FORMATION, "CORRIDOR_MARGIN_M")
SQUAD = 4
## A narrow stretch at most this long, with wider ground at both ends, is a neck; a longer one is a corridor. 30 m is
## a little over two hull lengths of the longest rig: a place a column files through, not a street it lives in.
CHOKE_MAX_M = 30.0
## A neck needs this much open ground (a line's frontage or wider) along the route on BOTH sides of it.
OPEN_EITHER_SIDE_M = 15.0
## How far either side of the route the width probe looks (a free span past this is "open").
WIDTH_REACH_M = 150.0
## Route samples for the width probe, metres apart.
WIDTH_STEP_M = 3.0
## Ground behind the spawn zones' forward edge is the base, not the map (read from the layout; 86 m on every map).
def base_edge(layout):
    zone = (layout.get("spawn_zones") or {}).get("green")
    if zone:
        return abs(float(zone["center"][1])) - float(zone["size"][1]) / 2.0
    return 86.0
## Ambush: the cone off each end of the line, the line's start, the stations it is measured at, the lattice of
## candidate ambusher cells, and how far apart two hulls hide.
FLANK_DEG = 30.0
START_M = 50.0
STATIONS_M = (-24.0, -12.0, 0.0, 12.0, 24.0)
AMBUSH_STEP_M = 2.0
HIDE_GAP_M = 8.0
## Heading of advance in degrees from +z toward +x: base to base, the diagonals, side to side.
AXES = {"base_to_base": 0.0, "diagonal_ne": 45.0, "side_to_side": 90.0, "diagonal_nw": 135.0}


def offset(formation, i, s=SPACING):
    """`TacticsFormation.offset` for the two shapes measured here (Vector2(across, along)); read from its source."""
    side = -1.0 if i % 2 == 1 else 1.0
    rank = float((i + 1) // 2)
    if i == 0:
        return (0.0, 0.0)
    if formation == "line":
        return (side * rank * s, 0.0)
    if formation == "wedge":
        return (side * rank * s * DIAGONAL_SIDE, rank * s)
    raise ValueError(formation)


def footprint(formation, count=SQUAD):
    """(frontage, depth): the hull-centre span across, plus the corridor margin each side; and the span along."""
    pts = [offset(formation, i) for i in range(count)]
    across = max(p[0] for p in pts) - min(p[0] for p in pts)
    along = max(p[1] for p in pts) - min(p[1] for p in pts)
    return across + 2.0 * CORRIDOR_MARGIN, along


LINE_FRONTAGE, _LINE_DEPTH = footprint("line")
WEDGE_FRONTAGE, WEDGE_DEPTH = footprint("wedge")
## How far a formation must be able to ADVANCE through the ground for it to count as room: three spacings, a line's own
## frontage. One spacing was tried first and read the yard as 38 % room: a line standing lengthwise in a 28 m lane and
## shuffling 12 m sideways across it, which is not manoeuvre (calibration on the dealt maps, round 18).
TRAVEL_M = 3.0 * SPACING
LINE_DEPTH = TRAVEL_M


# ---- The ground --------------------------------------------------------------------------------------------------

def ground(layout):
    """(boxes, blocked, n): arena_report's occupancy and terrain carve, plus the perimeter polygon inset by the bake
    radius (the report's grid only clamps a square; a hexagon's corners are outside the wall)."""
    ar.use_extent(layout)
    boxes = ar.boxes_of(layout)
    blocked, n = ar.occupancy(boxes)
    arena_terrain.carve(blocked, n, layout, ar.HALF, ar.GRID, ar.AGENT_RADIUS)
    poly = ar.perimeter_polygon(layout)
    edges = []
    for i in range(len(poly)):
        ax, az = poly[i]
        bx, bz = poly[(i + 1) % len(poly)]
        mx, mz = (ax + bx) / 2.0, (az + bz) / 2.0
        a = math.hypot(mx, mz)
        edges.append((mx / a, mz / a, a - ar.AGENT_RADIUS))
    for gz in range(n):
        z = gz * ar.GRID - ar.HALF + ar.GRID / 2
        row = gz * n
        for gx in range(n):
            if blocked[row + gx]:
                continue
            x = gx * ar.GRID - ar.HALF + ar.GRID / 2
            for nx, nz, lim in edges:
                if nx * x + nz * z > lim:
                    blocked[row + gx] = 1
                    break
    return boxes, blocked, n


def cell_of(x, z, n):
    return int((x + ar.HALF) / ar.GRID), int((z + ar.HALF) / ar.GRID)


def free_at(blocked, n, x, z):
    gx, gz = cell_of(x, z, n)
    return 0 <= gx < n and 0 <= gz < n and not blocked[gz * n + gx]


def centre_of(gx, gz):
    return gx * ar.GRID - ar.HALF + ar.GRID / 2, gz * ar.GRID - ar.HALF + ar.GRID / 2


# ---- (a) Room --------------------------------------------------------------------------------------------------------

## (dx, dz) directions on the grid; a diagonal step is sqrt(2) cells long.
DIRS = ((1, 0), (0, 1), (1, 1), (1, -1))


def _lines(n, d):
    """Every grid line along direction d, as lists of (gx, gz) in order."""
    dx, dz = d
    starts = []
    if d == (1, 0):
        starts = [(0, gz) for gz in range(n)]
    elif d == (0, 1):
        starts = [(gx, 0) for gx in range(n)]
    elif d == (1, 1):
        starts = [(0, gz) for gz in range(n)] + [(gx, 0) for gx in range(1, n)]
    else:  # (1, -1)
        starts = [(0, gz) for gz in range(n)] + [(gx, n - 1) for gx in range(1, n)]
    out = []
    for sx, sz in starts:
        line = []
        x, z = sx, sz
        while 0 <= x < n and 0 <= z < n:
            line.append((x, z))
            x, z = x + dx, z + dz
        out.append(line)
    return out


def spans(blocked, n, d):
    """Per cell: the length (m) of the free run along d that contains it (0 where blocked)."""
    step = ar.GRID * (math.sqrt(2.0) if d[0] and d[1] else 1.0)
    out = [0.0] * (n * n)
    for line in _lines(n, d):
        run = []
        for cell in line + [None]:
            if cell is not None and not blocked[cell[1] * n + cell[0]]:
                run.append(cell[1] * n + cell[0])
                continue
            if run:
                length = len(run) * step
                for idx in run:
                    out[idx] = length
                run = []
    return out


def _perp(d):
    """The grid direction at right angles to d, as one of DIRS (`_lines` walks only those four: a (-1, 0) here was
    once walked as a diagonal, and every line advancing along x went unmeasured)."""
    return {(1, 0): (0, 1), (0, 1): (1, 0), (1, 1): (1, -1), (1, -1): (1, 1)}[d]


def windowed_min(values, n, along, depth_m):
    """Per cell: the minimum of `values` over a window of depth_m centred on it, along direction `along`."""
    step = ar.GRID * (math.sqrt(2.0) if along[0] and along[1] else 1.0)
    k = max(0, int(round(depth_m / step / 2.0)))
    out = [0.0] * (n * n)
    for line in _lines(n, along):
        idxs = [gz * n + gx for gx, gz in line]
        vals = [values[i] for i in idxs]
        m = len(vals)
        # A monotone deque over a window [i-k, i+k].
        dq = []
        head = 0
        right = -1
        for i in range(m):
            while right < min(m - 1, i + k):
                right += 1
                while len(dq) > head and vals[dq[-1]] >= vals[right]:
                    dq.pop()
                dq.append(right)
            while dq[head] < i - k:
                head += 1
            # Past either end of the grid line the window is cut short; the grid's edge is far outside the wall.
            out[idxs[i]] = vals[dq[head]]
    return out


def room(blocked, n, layout):
    edge = base_edge(layout)
    span = {d: spans(blocked, n, d) for d in DIRS}
    line_ok = bytearray(n * n)
    wedge_ok = bytearray(n * n)
    widest = 0.0
    widest_at = None
    for d in DIRS:
        along = _perp(d)
        lmin = windowed_min(span[d], n, along, LINE_DEPTH)
        wmin = windowed_min(span[d], n, along, max(WEDGE_DEPTH, TRAVEL_M))
        for idx in range(n * n):
            if lmin[idx] >= LINE_FRONTAGE:
                line_ok[idx] = 1
            if wmin[idx] >= WEDGE_FRONTAGE:
                wedge_ok[idx] = 1
            if lmin[idx] > widest:
                gz, gx = divmod(idx, n)
                x, z = centre_of(gx, gz)
                if abs(z) <= edge:
                    widest, widest_at = lmin[idx], (round(x, 1), round(z, 1))
    drivable = field = line_all = wedge_all = line_field = wedge_field = 0
    for idx in range(n * n):
        if blocked[idx]:
            continue
        drivable += 1
        gz, gx = divmod(idx, n)
        in_field = abs(centre_of(gx, gz)[1]) <= edge
        field += in_field
        line_all += line_ok[idx]
        wedge_all += wedge_ok[idx]
        line_field += line_ok[idx] and in_field
        wedge_field += wedge_ok[idx] and in_field
    abreast = 1 + max(0, int((widest - 2.0 * CORRIDOR_MARGIN) // SPACING)) if widest > 0 else 0
    return {
        "line_frontage_m": round(LINE_FRONTAGE, 1), "wedge_frontage_m": round(WEDGE_FRONTAGE, 1),
        "line_share": round(line_field / max(1, field), 3), "wedge_share": round(wedge_field / max(1, field), 3),
        "line_share_all": round(line_all / max(1, drivable), 3), "wedge_share_all": round(wedge_all / max(1, drivable), 3),
        "widest_frontage_m": round(widest, 1), "widest_at": widest_at, "abreast_at_spacing": abreast,
        "drivable_m2": drivable, "field_m2": field,
    }, line_ok


# ---- (b) Chokepoints -------------------------------------------------------------------------------------------------

def width_across(blocked, n, x, z, ux, uz):
    """Free drivable span (m) through (x, z) along +-(ux, uz)."""
    total = 0.0
    for sign in (1.0, -1.0):
        t = 0.0
        while t < WIDTH_REACH_M:
            if not free_at(blocked, n, x + sign * ux * (t + 0.5), z + sign * uz * (t + 0.5)):
                break
            t += 0.5
        total += t
    return total


def _route(blocked, n, a, b):
    path = ar.route(blocked, n, a, b)
    return path


def _resample(path, step):
    out = [path[0]]
    acc = 0.0
    for i in range(1, len(path)):
        acc += math.dist(path[i - 1], path[i])
        if acc >= step:
            out.append(path[i])
            acc = 0.0
    if out[-1] != path[-1]:
        out.append(path[-1])
    return out


def narrow_stretches(blocked, n, path, edge):
    """[(kind, width_m, at, length_m, direction)] along a route: chokepoints and corridors."""
    pts = _resample(path, WIDTH_STEP_M)
    widths = []
    for i, (x, z) in enumerate(pts):
        a, b = pts[max(0, i - 2)], pts[min(len(pts) - 1, i + 2)]
        dx, dz = b[0] - a[0], b[1] - a[1]
        norm = math.hypot(dx, dz) or 1.0
        ux, uz = -dz / norm, dx / norm
        widths.append((width_across(blocked, n, x, z, ux, uz), (dx / norm, dz / norm)))
    out = []
    i = 0
    while i < len(pts):
        if abs(pts[i][1]) > edge or widths[i][0] >= LINE_FRONTAGE:
            i += 1
            continue
        j = i
        while j + 1 < len(pts) and abs(pts[j + 1][1]) <= edge and widths[j + 1][0] < LINE_FRONTAGE:
            j += 1
        length = (j - i + 1) * WIDTH_STEP_M
        k = min(range(i, j + 1), key=lambda q: widths[q][0])
        # A neck has OPEN ground on both sides of it (OPEN_EITHER_SIDE_M of the route at a line's frontage or wider);
        # a short narrow bit between two narrow bits is part of a corridor system, which is what a lane map is.
        k_open = int(round(OPEN_EITHER_SIDE_M / WIDTH_STEP_M))
        before = [q for q in range(i - k_open, i) if 0 <= q]
        after = [q for q in range(j + 1, j + 1 + k_open) if q < len(pts)]
        open_before = len(before) == k_open and all(widths[q][0] >= LINE_FRONTAGE for q in before)
        open_after = len(after) == k_open and all(widths[q][0] >= LINE_FRONTAGE for q in after)
        kind = "choke" if length <= CHOKE_MAX_M and open_before and open_after else "corridor"
        out.append({"kind": kind, "width_m": round(widths[k][0], 1), "at": (round(pts[k][0], 1), round(pts[k][1], 1)),
                    "length_m": round(length, 1), "dir": widths[k][1]})
        i = j + 1
    return out


def seal(blocked, n, at, direction):
    """A copy of `blocked` with the throat at `at` sealed: the cross-section line across `direction`, 3 cells thick."""
    sealed = bytearray(blocked)
    dx, dz = direction
    ux, uz = -dz, dx
    for along in (-1.0, 0.0, 1.0):
        cx, cz = at[0] + dx * along, at[1] + dz * along
        for sign in (1.0, -1.0):
            t = 0.0
            while t < WIDTH_REACH_M:
                x, z = cx + sign * ux * t, cz + sign * uz * t
                gx, gz = cell_of(x, z, n)
                if not (0 <= gx < n and 0 <= gz < n) or blocked[gz * n + gx]:
                    break
                sealed[gz * n + gx] = 1
                # Diagonal leaks: seal the 4-neighbours too.
                for ox, oz in ((1, 0), (0, 1)):
                    if 0 <= gx + ox < n and 0 <= gz + oz < n:
                        sealed[(gz + oz) * n + gx + ox] = 1
                t += 0.5
    return sealed


def lane_path(blocked, n, lane):
    """A declared lane driven through its own points (green's end first), as one grid path."""
    pts = [tuple(p) for p in lane["points"]]
    path = []
    for a, b in zip(pts, pts[1:]):
        leg = ar.route(blocked, n, a, b)
        if not leg:
            return None
        path += leg if not path else leg[1:]
    return path


def chokepoints(blocked, n, layout, trips):
    edge = base_edge(layout)
    found = []
    corridor_m = 0.0
    route_m = 0.0
    for label, a, b, *via in trips:
        path = lane_path(blocked, n, via[0]) if via else _route(blocked, n, a, b)
        if not path:
            continue
        base_len = ar.length(path)
        stretches = narrow_stretches(blocked, n, path, edge)
        route_m += sum(WIDTH_STEP_M for p in _resample(path, WIDTH_STEP_M) if abs(p[1]) <= edge)
        corridor_m += sum(s["length_m"] for s in stretches if s["kind"] == "corridor")
        # Iterate: seal each neck found, re-route, look again (two deep), so a second neck behind the first shows.
        current = blocked
        queue = [s for s in stretches if s["kind"] == "choke"]
        depth = 0
        while queue and depth < 2:
            depth += 1
            nxt = []
            for s in queue:
                if any(math.dist(s["at"], f["at"]) < 12.0 for f in found):
                    continue
                sealed = seal(current, n, s["at"], s["dir"])
                alt = _route(sealed, n, a, b)
                entry = {"trip": label, "width_m": s["width_m"], "at": s["at"], "length_m": s["length_m"],
                         "way_round": alt is not None,
                         "detour": round(ar.length(alt) / max(1.0, base_len), 2) if alt else None}
                found.append(entry)
                if alt:
                    nxt += [t for t in narrow_stretches(sealed, n, alt, edge) if t["kind"] == "choke"]
                    current = sealed
            queue = nxt
    return found, (round(corridor_m / route_m, 3) if route_m else None)


def trips_of(layout, blocked, n):
    """The trips a match makes: green's front-centre spawn to rust's, and to every objective (the mirror makes rust's
    the same trips rotated)."""
    green = tuple(ar.front_row(layout, "green")[len(ar.front_row(layout, "green")) // 2])
    rust = tuple(ar.front_row(layout, "rust")[len(ar.front_row(layout, "rust")) // 2])
    out = [("base to base", green, rust)]
    for obj in ar.objectives_of(layout):
        if math.hypot(*obj["at"]) > 1.0:
            out.append(("base to %s" % obj["name"], green, obj["at"]))
    # The ways a map DECLARES, driven as declared: a neck on a way round is not on any shortest trip, and the way
    # round is exactly where a map puts its necks.
    for lane in layout.get("lanes", []):
        pts = lane["points"]
        out.append(("lane %s" % lane["name"], tuple(pts[0]), tuple(pts[-1]), lane))
    return out


# ---- (c) Ambush ------------------------------------------------------------------------------------------------------

def line_members(cx, cz, ux, uz):
    xs = [offset("line", i)[0] for i in range(SQUAD)]
    mid = (max(xs) + min(xs)) / 2.0
    return [(cx + (x - mid) * ux, cz + (x - mid) * uz) for x in xs]


def capacity(cells):
    """How many hulls stand in these cells HIDE_GAP_M apart (greedy, in a fixed order)."""
    picked = []
    for c in sorted(cells):
        if all(math.dist(c, p) >= HIDE_GAP_M for p in picked):
            picked.append(c)
    return len(picked)


def clusters(cells):
    pool = set(cells)
    out = []
    while pool:
        seed = min(pool)
        pool.discard(seed)
        group, stack = [seed], [seed]
        while stack:
            x, z = stack.pop()
            for ox in (-AMBUSH_STEP_M, 0.0, AMBUSH_STEP_M):
                for oz in (-AMBUSH_STEP_M, 0.0, AMBUSH_STEP_M):
                    q = (x + ox, z + oz)
                    if q in pool:
                        pool.discard(q)
                        group.append(q)
                        stack.append(q)
        out.append(group)
    return out


def ambush(blocked, n, boxes, reach):
    grid, gn = ar.sight_grid(boxes)
    cos_flank = math.cos(math.radians(FLANK_DEG))
    result = {}
    for axis, heading in AXES.items():
        h = math.radians(heading)
        hx, hz = math.sin(h), math.cos(h)        # advance
        ux, uz = hz, -hx                          # the line's own axis
        # Every hull of the line at its start is an EYE, drivable or not: the first version kept only drivable ones,
        # and on the Gorge, whose start stands over a band of pits, no eye was left and every cell read "unseen".
        start = line_members(-hx * START_M, -hz * START_M, ux, uz)
        stations = 0
        cells = set()
        for s in STATIONS_M:
            cx, cz = hx * s, hz * s
            members = line_members(cx, cz, ux, uz)
            # The line must be able to STAND here and ADVANCE its travel (TRAVEL_M, as room): a line cannot advance
            # sideways through a container wall, and a station it cannot leave is not a crossing. With one spacing
            # of travel the yard's 26 m centre lane passed side to side: a line standing lengthwise in it.
            if not all(free_at(blocked, n, px + hx * t, pz + hz * t) for px, pz in members
                       for t in range(0, int(TRAVEL_M) + 1)):
                continue
            stations += 1
            lo = -(reach + 40.0)
            steps = int(2 * (reach + 40.0) / AMBUSH_STEP_M)
            for i in range(steps + 1):
                for j in range(steps + 1):
                    ax_, az_ = cx + lo + i * AMBUSH_STEP_M, cz + lo + j * AMBUSH_STEP_M
                    ax_, az_ = round(ax_ / AMBUSH_STEP_M) * AMBUSH_STEP_M, round(az_ / AMBUSH_STEP_M) * AMBUSH_STEP_M
                    vx, vz = ax_ - cx, az_ - cz
                    dist = math.hypot(vx, vz)
                    if dist < 1.0 or abs(vx * ux + vz * uz) / dist < cos_flank:
                        continue
                    if min(math.dist((ax_, az_), m) for m in members) > reach:
                        continue
                    if (ax_, az_) in cells or not free_at(blocked, n, ax_, az_):
                        continue
                    seen = sum(1 for m in members if ar.sees(grid, gn, ax_, az_, m[0], m[1]))
                    if seen < 2:
                        continue
                    if any(ar.sees(grid, gn, p[0], p[1], ax_, az_) for p in start):
                        continue
                    cells.add((ax_, az_))
        groups = clusters(cells)
        caps = sorted((capacity(g) for g in groups), reverse=True)
        result[axis] = {"stations": stations, "positions": sum(1 for c in caps if c >= 1), "hulls": sum(caps),
                        "best": caps[0] if caps else 0, "cells": len(cells),
                        "_positions": [(capacity(g), (round(sum(p[0] for p in g) / len(g), 1),
                                                      round(sum(p[1] for p in g) / len(g), 1))) for g in groups]}
    return result


# ---- Everything for one layout ---------------------------------------------------------------------------------------

def measure(layout, with_report=True):
    boxes, blocked, n = ground(layout)
    out = {"name": layout["name"], "candidate": layout["name"] in ar.candidates()}
    out["room"], line_ok = room(blocked, n, layout)
    found, corridor_share = chokepoints(blocked, n, layout, trips_of(layout, blocked, n))
    out["chokepoints"] = found
    out["corridor_share"] = corridor_share
    reach = ar.load_reach().get("posted", ar.WATCHER_REACH_M["posted"])
    out["ambush_reach_m"] = reach
    out["ambush"] = ambush(blocked, n, boxes, reach)
    if with_report:
        # (d) For the record: the report's own numbers (it re-derives its grid; the call is self-contained).
        ar.WATCHER_REACH_M.update(ar.load_reach())
        rep = ar.analyze(layout)
        out["centre_sees_share"] = rep["ambush"]["centre_sees_share"]
        out["longest_sightline_m"] = rep["longest_sightline_m"]
        out["mean_view_m"] = rep["mean_view_m"]
        out["decision_spread"] = rep["ambush"].get("decision", {}).get("decision_spread")
    out["_ground"] = (blocked, n, line_ok)
    return out


def summary_line(m):
    r = m["room"]
    chokes = m["chokepoints"]
    round_ = [c for c in chokes if c["way_round"]]
    a = m["ambush"]
    return ("ROOM %-14s line4=%.2f wedge4=%.2f widest=%5.1fm (%d abreast) | chokes=%d (way round %d, detour %s) "
            "corridor=%s | ambush hulls: b2b=%d diag=%d/%d side=%d | centre_sees=%s"
            % (m["name"], r["line_share"], r["wedge_share"], r["widest_frontage_m"], r["abreast_at_spacing"],
               len(chokes), len(round_), ",".join("%.2f" % c["detour"] for c in round_) or "-",
               "%.2f" % m["corridor_share"] if m["corridor_share"] is not None else "-",
               a["base_to_base"]["hulls"], a["diagonal_ne"]["hulls"], a["diagonal_nw"]["hulls"], a["side_to_side"]["hulls"],
               "%.2f" % m["centre_sees_share"] if "centre_sees_share" in m else "-"))


def plot(layout, m, out_dir):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    blocked, n, line_ok = m["_ground"]
    half = float(layout.get("half_size", 120.0))
    img = []
    for gz in range(n):
        row = []
        for gx in range(n):
            idx = gz * n + gx
            row.append(0.0 if blocked[idx] else (2.0 if line_ok[idx] else 1.0))
        img.append(row)
    fig, ax = plt.subplots(figsize=(7, 7), dpi=110)
    from matplotlib.colors import ListedColormap
    ax.imshow(img, origin="lower", extent=(-ar.HALF, ar.HALF, -ar.HALF, ar.HALF),
              cmap=ListedColormap(["#20232a", "#5b6170", "#9fd39a"]), vmin=0, vmax=2, interpolation="nearest")
    for b in ar.boxes_of(layout):
        xs, zs = zip(*(b.corners() + [b.corners()[0]]))
        ax.fill(xs, zs, color="#e08a3c" if b.h >= ar.EYE_HEIGHT else "#c9b458", lw=0)
    for c in m["chokepoints"]:
        ax.plot(*c["at"], marker="o", ms=11, mfc="none", mec="#ff4d6d" if not c["way_round"] else "#ffd166", mew=2)
    colours = {"base_to_base": "#4cc9f0", "diagonal_ne": "#b388ff", "diagonal_nw": "#b388ff", "side_to_side": "#f72585"}
    for axis, a in m["ambush"].items():
        for cap, (x, z) in a["_positions"]:
            if cap:
                ax.plot(x, z, marker="^", ms=4 + 2 * cap, color=colours[axis], alpha=0.85)
    for obj in layout.get("objectives", []):
        ax.plot(*obj["position"], marker="*", ms=14, color="#ffffff")
    ax.set_xlim(-half - 5, half + 5)
    ax.set_ylim(half + 5, -half - 5)  # north (rust) at the top, as the tactical map draws it
    ax.set_title("%s: green = a line of four fits; o = chokepoint; ^ = flank-ambush ground" % layout["name"], fontsize=8)
    ax.set_aspect("equal")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "room-%s.png" % layout["name"])
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)
    return path


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("layouts", nargs="+")
    p.add_argument("--json")
    p.add_argument("--plot")
    p.add_argument("--no-report", action="store_true", help="skip (d): the arena report's centre and sightline numbers")
    args = p.parse_args(argv)
    rows = []
    for path in args.layouts:
        with open(path) as f:
            layout = json.load(f)
        m = measure(layout, with_report=not args.no_report)
        if args.plot:
            m["plot"] = plot(layout, m, args.plot)
        print(summary_line(m), flush=True)
        for c in m["chokepoints"]:
            print("ROOM_CHOKE %-14s %-28s %5.1f m wide at (%6.1f, %6.1f), %4.1f m long, way round: %s"
                  % (m["name"], c["trip"], c["width_m"], c["at"][0], c["at"][1], c["length_m"],
                     "x%.2f" % c["detour"] if c["way_round"] else "NONE"))
        for axis, a in m["ambush"].items():
            print("ROOM_AMBUSH %-14s %-13s stations %d/%d, positions %d, hulls hidden %d, best position %d"
                  % (m["name"], axis, a["stations"], len(STATIONS_M), a["positions"], a["hulls"], a["best"]))
        rows.append({k: v for k, v in m.items() if not k.startswith("_")})
        for a in rows[-1]["ambush"].values():
            a.pop("_positions", None)
    if args.json:
        os.makedirs(os.path.dirname(args.json) or ".", exist_ok=True)
        with open(args.json, "w") as f:
            json.dump(rows, f, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
