#!/usr/bin/env python3
"""R4 (round 10): the report's lane table (`make arena-pytest`). The authority is `ArenaLanes` and
`tests/test_arena_lanes.gd` in `make check`; these pin the Python copy of the algorithm to the same answers, so the
page and `make arena-report` cannot drift from the assertion."""
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import arena_report as ar
import units_catalog

ARENAS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "arenas")


def street(*props):
    """A 20 m street (x in -10..10) between two long walls, with a lane down its middle."""
    return {"name": "probe", "half_size": 120.0, "props": list(props),
            "obstacles": [{"type": "wall", "position": [x, 0.0], "size": [40.0, 10.0, 200.0], "rotation_deg": 0.0}
                          for x in (-30.0, 30.0)],
            "lanes": [{"name": "street", "points": [[0.0, 60.0], [0.0, -60.0]], "width": 18.0}]}


class LaneTable(unittest.TestCase):
    def table(self, layout):
        return ar.lane_table(layout, ar.boxes_of(layout))

    def test_the_bar_is_read_from_the_catalog_and_the_bake(self):
        bar = ar.lane_bar()
        hulls = units_catalog.load()
        widest = max(float(p["hull_size"][0]) for p in hulls.values())
        self.assertAlmostEqual(bar["widest_hull_m"], widest)
        self.assertAlmostEqual(bar["drivable_bar_m"], 2 * widest)
        self.assertAlmostEqual(bar["bake_radius_m"], 2.0, msg="arena.tscn's agent_radius")
        self.assertEqual(bar["rig"], "gang_tank")
        self.assertIn("yard", bar["report_only"], "the report-only list is ArenaLanes.REPORT_ONLY, parsed")

    def test_positive_controls(self):
        """The same four cases as the GDScript test: an empty street, a container at the kerb, one across, a barricade."""
        self.assertAlmostEqual(self.table(street())["lanes"][0]["narrowest_physical_m"], 20.0, places=2)
        kerb = self.table(street({"type": "container_40", "position": [-8.78, 5.0], "rotation_deg": 90.0}))["lanes"][0]
        self.assertAlmostEqual(kerb["narrowest_physical_m"], 17.56, places=2)
        self.assertTrue(kerb["pass"])
        across = self.table(street({"type": "container_40", "position": [0.0, 5.0], "rotation_deg": 0.0}))["lanes"][0]
        self.assertFalse(across["pass"])
        low = self.table(street({"type": "barricade", "position": [0.0, 5.0], "rotation_deg": 0.0}))["lanes"][0]
        self.assertFalse(low["pass"], "a barricade stops a hull: the lane table counts low colliders")

    def test_the_terminus_matches_the_game(self):
        """The GDScript's numbers for the Terminus (ArenaLanes.describe, printed by tests/test_arena_lanes.gd at the
        commit that moved the furniture). If the layout changes, re-read them from the check log."""
        with open(os.path.join(ARENAS, "terminus.json")) as f:
            layout = json.load(f)
        ar.use_extent(layout)
        table = self.table(layout)
        got = {l["name"]: l["narrowest_physical_m"] for l in table["lanes"]}
        self.assertEqual(got, {"the avenue": 17.56, "west street": 16.4, "east street": 16.4, "the ring road": 22.0,
                               "the ring road (far)": 22.0, "plaza crossing west": 22.0, "plaza crossing east": 22.0})
        self.assertTrue(all(c["pass"] for c in table["corners"]), table["corners"])
        self.assertEqual(len(table["corners"]), 17, "4 bends and 13 junctions")


if __name__ == "__main__":
    unittest.main()


class DecisionRoutes(unittest.TestCase):
    """Round 10 (terrain's finding): `decision_report` routed the ENEMY through green's exposure field. On a
    point-symmetric map the enemy's covered route to an objective IS green's covered route to its twin, so the two
    lengths must agree exactly; the bug made them disagree whenever cover was lopsided along the way."""

    def test_the_enemy_routes_with_its_own_field(self):
        for name in ("yard", "terminus"):
            with open(os.path.join(ARENAS, name + ".json")) as f:
                layout = json.load(f)
            report = ar.analyze(layout)
            routes = {r["objective"]: r for r in report["ambush"]["decision"]["routes"]}
            pairs = [(k, k + " (far)") for k in routes if k + " (far)" in routes]
            self.assertTrue(pairs, "%s has a mirrored objective pair" % name)
            for home, away in pairs:
                self.assertAlmostEqual(routes[home]["enemy_length_m"], routes[away]["length_m"], places=1,
                                       msg="%s: rust's trip to %s is green's trip to %s" % (name, home, away))

    def test_the_centre_eye_leaves_a_block(self):
        """A 40 m block on the centre: the eye must end up outside it, not inside with a 0.00 view."""
        layout = {"name": "probe", "half_size": 120.0, "obstacles": [
            {"type": "block", "position": [0.0, 0.0], "size": [40.0, 24.0, 40.0], "rotation_deg": 0.0}], "props": []}
        ar.use_extent(layout)
        boxes = ar.boxes_of(layout)
        blocked, n = ar.occupancy(boxes)
        eye = ar.standing_point(blocked, n, (0.0, 0.0))
        self.assertGreater(boxes[0].distance(*eye), 0.0, "the eye at %s is outside the block" % (eye,))
