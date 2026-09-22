"""tools/arena_terrain.py: the Python half of the water/pit/bridge mirror (terrain stream, round 10).

Run: `make terrain-pytest` (also picked up by `make arena-pytest`, which globs test_arena*.py).
`--write-golden` regenerates tests/fixtures/terrain_golden.json from THIS implementation; do it only on purpose,
because the GDScript side (tests/test_terrain_golden.gd) is held to the same file.
"""
import json
import pathlib
import sys
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import arena_terrain as T
import arena_report

GOLDEN = HERE.parent / "tests" / "fixtures" / "terrain_golden.json"
RIVER = {"kind": "water", "name": "river", "rect": [0.0, 40.0, 320.0, 24.0]}
RIVER_FAR = {"kind": "water", "name": "river (far)", "rect": [0.0, -40.0, 320.0, 24.0]}
BRIDGE = {"kind": "bridge", "name": "bridge", "rect": [50.0, 40.0, 14.0, 30.0]}
BRIDGE_FAR = {"kind": "bridge", "name": "bridge (far)", "rect": [-50.0, -40.0, 14.0, 30.0]}
GOLDEN_TERRAIN = [RIVER, RIVER_FAR, BRIDGE, BRIDGE_FAR,
                  {"kind": "pit", "name": "pit", "rect": [-60.0, 5.0, 20.0, 16.0]},
                  {"kind": "pit", "name": "pit (far)", "rect": [60.0, -5.0, 20.0, 16.0]},
                  {"kind": "bridge", "name": "catwalk", "rect": [-60.0, 5.0, 12.0, 30.0]},
                  {"kind": "bridge", "name": "catwalk (far)", "rect": [60.0, -5.0, 12.0, 30.0]},
                  # A dog-leg: two rectangles of one body of water, meeting in an L. No rim may stand at the join.
                  {"kind": "water", "name": "leg a", "rect": [100.0, 100.0, 40.0, 10.0]},
                  {"kind": "water", "name": "leg b", "rect": [115.0, 115.0, 10.0, 40.0]}]


def golden_from_python():
    out = {"note": "Golden rims and rails. BOTH ArenaTerrain (tests/test_terrain_golden.gd) and tools/arena_terrain.py "
                   "(tools/test_arena_terrain.py) must reproduce these. Regenerate only on purpose: "
                   "python3 tools/test_arena_terrain.py --write-golden",
           "terrain": GOLDEN_TERRAIN, "rims": {}, "rails": {}}
    for e in GOLDEN_TERRAIN:
        if T.carves(e["kind"]):
            out["rims"][e["name"]] = [[round(v, 4) for v in r] for r in T.rim_slabs(e, GOLDEN_TERRAIN)]
        if T.is_deck(e["kind"]):
            out["rails"][e["name"]] = [[round(v, 4) for v in r] for r in T.rail_slabs(e, GOLDEN_TERRAIN)]
    return out


def _grid(layout):
    arena_report.use_extent(layout)
    blocked, n = arena_report.occupancy([])
    T.carve(blocked, n, layout, arena_report.HALF, arena_report.GRID, arena_report.AGENT_RADIUS)
    return blocked, n


def _free(blocked, n, x, z):
    h = arena_report.HALF
    return not blocked[int((z + h) / arena_report.GRID) * n + int((x + h) / arena_report.GRID)]


class MirrorMatchesTheGolden(unittest.TestCase):
    def test_rims_and_rails_match_the_file_godot_is_held_to(self):
        golden = json.loads(GOLDEN.read_text())
        mine = golden_from_python()
        self.assertEqual(golden["terrain"], mine["terrain"], "the golden's input terrain is the one tested here")
        for part in ("rims", "rails"):
            for name, boxes in golden[part].items():
                self.assertEqual(len(boxes), len(mine[part][name]), "%s %s: box count" % (part, name))
                for a, b in zip(sorted(boxes), sorted(mine[part][name])):
                    for u, v in zip(a, b):
                        self.assertAlmostEqual(u, v, places=3, msg="%s %s: %s vs %s" % (part, name, a, b))

    def test_no_rim_stands_where_two_footprints_of_one_river_meet(self):
        """Round 7 stood a rim at every join of a river built from several rectangles. No wall box may cover water,
        on the golden terrain or on any shipped terrain map; and the outer bank is still sealed."""
        import glob
        layouts = [GOLDEN_TERRAIN] + [json.load(open(p)).get("terrain", []) for p in sorted(glob.glob(str(HERE.parent / "arenas" / "*.json")))]
        for terrain in layouts:
            for cx, cz, w, d in T.walls(terrain):
                for fx in (-0.4, 0.0, 0.4):
                    for fz in (-0.4, 0.0, 0.4):
                        x, z = cx + fx * w, cz + fz * d
                        if any(T.is_deck(t["kind"]) for t in terrain if T.bounds(t)[0] < x < T.bounds(t)[2] and T.bounds(t)[1] < z < T.bounds(t)[3]):
                            continue  # a rail stands on its deck, over the water by construction
                        self.assertFalse(T.in_water(terrain, x, z), "a wall box at %s stands in water" % [cx, cz, w, d])
        legs = [t for t in GOLDEN_TERRAIN if t["name"].startswith("leg")]
        self.assertTrue(any(abs(b[1] - 94.4) < 0.01 for b in T.walls(legs)), "leg a keeps its north rim")

    def test_constants_are_read_not_copied(self):
        self.assertGreater(T.RIM_HEIGHT, 0.5)
        self.assertLess(T.RAIL_HEIGHT, 1.3, "rails stay below the eye line")
        bar = arena_report.lane_bar()
        self.assertAlmostEqual(T.min_deck_m(), 2 * bar["widest_hull_m"] + 2 * bar["bake_radius_m"] + 2 * T.RAIL_THICKNESS)


class TheReportSeesWater(unittest.TestCase):
    """The report measured every river map as if the river were floor until round 10. These fail on that code."""

    def layout(self, terrain):
        return {"name": "t", "half_size": 120.0, "terrain": terrain,
                "spawns": {"green": [[0.0, 90.0]], "rust": [[0.0, -90.0]]}}

    def test_a_river_with_no_bridge_cannot_be_crossed(self):
        blocked, n = _grid(self.layout([RIVER, RIVER_FAR]))
        self.assertIsNone(arena_report.route(blocked, n, (0.0, 70.0), (0.0, 0.0)))

    def test_a_bridge_carries_the_route_and_the_route_uses_it(self):
        blocked, n = _grid(self.layout([RIVER, RIVER_FAR, BRIDGE, BRIDGE_FAR]))
        path = arena_report.route(blocked, n, (0.0, 70.0), (0.0, 0.0))
        self.assertIsNotNone(path, "a bridge makes the crossing")
        on_deck = [p for p in path if 28.0 < p[1] < 52.0]
        self.assertTrue(on_deck and all(43.0 < p[0] < 57.0 for p in on_deck), "and every wet-latitude step is on the deck")

    def test_the_mesh_keeps_the_bake_radius_off_rims_and_rails(self):
        blocked, n = _grid(self.layout([RIVER, RIVER_FAR, BRIDGE, BRIDGE_FAR]))
        outer_face = 40.0 + 12.0 + T.RIM_THICKNESS
        self.assertFalse(_free(blocked, n, -100.0, outer_face + 1.0), "1 m off the rim is inside the bake radius")
        self.assertTrue(_free(blocked, n, -100.0, outer_face + 3.0), "3 m off it is floor")
        # On the deck: 14 m wide, rails 0.5 m, radius 2 m -> free for 9 m in the middle.
        self.assertTrue(_free(blocked, n, 50.5, 40.0), "the deck's middle is drivable")
        self.assertFalse(_free(blocked, n, 44.5, 40.0), "the deck next to a rail is not")

    def test_the_report_itself_routes_over_the_bridge(self):
        """The hook in arena_report.analyze(), not only the helper: with it removed, the base-to-base route walks
        straight through the river at x = 0."""
        report = arena_report.analyze(self.layout([RIVER, RIVER_FAR, BRIDGE, BRIDGE_FAR]) | {"props": [], "obstacles": []})
        path = report["_paths"]["direct"]
        wet = [p for p in path if 28.0 < p[1] < 52.0]
        self.assertTrue(wet and all(43.0 < p[0] < 57.0 for p in wet), "the direct route crosses on the deck")

    def test_a_layout_without_terrain_is_untouched(self):
        layout = self.layout([])
        arena_report.use_extent(layout)
        blocked, n = arena_report.occupancy([])
        before = bytes(blocked)
        self.assertEqual(T.carve(blocked, n, layout, arena_report.HALF, arena_report.GRID, arena_report.AGENT_RADIUS), 0)
        self.assertEqual(before, bytes(blocked))


if __name__ == "__main__":
    if "--write-golden" in sys.argv:
        GOLDEN.write_text(json.dumps(golden_from_python(), indent=1) + "\n")
        print("wrote", GOLDEN)
    else:
        unittest.main()
