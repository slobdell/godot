#!/usr/bin/env python3
"""Mapkit P4 (round 47): the map-kit TWINS -- a shipped map plus the lead's picked pieces, as a CANDIDATE (`Arena.CANDIDATES`:
playable by name with `make skirmish ARENA=<twin>`, never dealt) so the pieces are judged against the map without them
(_agents/arenas.md *How we test that a map delivers*: arena-report before/after, the paired series) before any shipped map
changes. Run: python3 tests/mapkit/make_kit_twins.py (after `make arenas`, which rewrites the originals).

parade_traps: the Parade Ground with two hedgehog breakwaters per side in front of each base (z = +-45..+-48, x = +-20..+-50,
south half authored, the north its 180-degree mirror). Hogs 3.0 m apart in two staggered rows: closer than a hull plus the
bake radius, so each breakwater is a wall to hulls and the navmesh but not to rounds or eyes (`low`). The floor (|x| < 20)
and the bays stay open: an advance from the base funnels to the floor or out to the bays instead of spreading across.
Off every declared lane (tests/test_arena_lanes.gd asserts candidates)."""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]


def hog_rows(x0, x1, z, step=3.0):
    """Two staggered rows of hogs from x0 to x1 at z and z + 3."""
    out = []
    x = x0
    while x <= x1 + 1e-6:
        out.append((x, z, 0.0))
        out.append((x + step / 2.0, z + 3.0, 45.0))
        x += step
    return out


def mirrored(points):
    return [(x, z, r) for x, z, r in points] + [(-x, -z, (r + 180.0) % 360.0) for x, z, r in points]


def parade_traps():
    base = json.loads((ROOT / "arenas" / "parade.json").read_text())
    half = hog_rows(-50.0, -21.5, 45.0) + hog_rows(20.0, 48.5, 45.0)
    props = list(base["props"]) + [{"type": "tank_trap", "position": [round(x, 2), round(z, 2)], "rotation_deg": r}
                                   for x, z, r in mirrored(half)]
    twin = dict(base)
    twin["name"] = "parade_traps"
    twin["title"] = "The Parade Ground (tank traps)"
    twin["fixture"] = True
    twin["note"] = ("Mapkit P4 twin of the Parade Ground (tests/mapkit/make_kit_twins.py): two hedgehog breakwaters in front "
                    "of each base, the floor and the bays open. A candidate: judged against parade before any shipped map "
                    "changes. " + base.get("note", ""))
    twin["props"] = props
    twin.pop("show", None)
    (ROOT / "arenas" / "parade_traps.json").write_text(json.dumps(twin, indent=1) + "\n")
    return len(props) - len(base["props"])


if __name__ == "__main__":
    print("wrote arenas/parade_traps.json: %d hogs" % parade_traps())
