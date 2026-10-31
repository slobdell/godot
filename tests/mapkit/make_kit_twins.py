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


def parade_rail():
    """parade_rail: the Parade Ground with a monorail across it at z = 0 (his overpass pick C): pillars every 20 m from
    x = +-20 to +-100, each carrying 20 m of beam (`span`), so the floor lane (|x| < 15) runs under a 38 m gap and the
    pillars stand as posts in the bays. A car parked on the span at x = +-40. Self-mirrored row (x -> -x at z = 0)."""
    base = json.loads((ROOT / "arenas" / "parade.json").read_text())
    rail = []
    for x in (20.0, 40.0, 60.0, 80.0, 100.0):
        for sign, rot in ((1.0, 90.0), (-1.0, 270.0)):
            rail.append({"type": "monorail", "position": [sign * x, 0.0], "rotation_deg": rot})
            rail.append({"type": "monorail_deck", "position": [sign * x, 0.0], "rotation_deg": rot, "span": 20.0,
                         "car": x == 40.0})
    twin = dict(base)
    twin["name"] = "parade_rail"
    twin["title"] = "The Parade Ground (monorail)"
    twin["fixture"] = True
    twin["note"] = ("Mapkit P4 twin of the Parade Ground (tests/mapkit/make_kit_twins.py): a monorail across the middle, "
                    "pillars 20 m apart, the floor under a 38 m span. A candidate: judged against parade first. " + base.get("note", ""))
    twin["props"] = list(base["props"]) + rail
    twin.pop("show", None)
    (ROOT / "arenas" / "parade_rail.json").write_text(json.dumps(twin, indent=1) + "\n")
    return len(rail) // 2


def crossing_screens():
    """crossing_screens: the Crossing with sight screens (his pick C, steam; strips on the laptop): one across the middle of
    each bridge (a crew on the deck is unseen from the landing until it is through) and two along each side's near bank
    (cutting the long looks over the water, the 79 m median where the gangs fired 6 shots to the syndicate's 358). Screens are
    not obstacles: every lane and the bridges' widths are untouched. South half authored, the north its mirror."""
    base = json.loads((ROOT / "arenas" / "crossing.json").read_text())
    half = [(-92.0, 14.0, 0.0), (-60.0, 30.0, 0.0), (-30.0, 30.0, 0.0)]
    screens = [{"type": "sight_screen", "position": [x, z], "rotation_deg": r} for x, z, r in half]
    screens += [{"type": "sight_screen", "position": [-x, -z], "rotation_deg": (r + 180.0) % 360.0} for x, z, r in half]
    twin = dict(base)
    twin["name"] = "crossing_screens"
    twin["title"] = "The Crossing (sight screens)"
    twin["fixture"] = True
    twin["note"] = ("Mapkit P4 twin of the Crossing (tests/mapkit/make_kit_twins.py): sight screens across each bridge and along "
                    "each near bank. A candidate: judged against crossing first. " + base.get("note", ""))
    twin["props"] = list(base["props"]) + screens
    twin.pop("show", None)
    (ROOT / "arenas" / "crossing_screens.json").write_text(json.dumps(twin, indent=1) + "\n")
    return len(screens)


if __name__ == "__main__":
    print("wrote arenas/parade_traps.json: %d hogs" % parade_traps())
    print("wrote arenas/parade_rail.json: %d pillars" % parade_rail())
    print("wrote arenas/crossing_screens.json: %d screens" % crossing_screens())
