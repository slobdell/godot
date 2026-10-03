"""The container census (yard, round 17, Y1) on made-up layouts: what counts as square, and that it fails when asked."""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import container_census as cc


def box(rot, stack=1, kind="container_20"):
    return {"type": kind, "position": [0.0, 0.0], "rotation_deg": rot, "stack": stack}


class OffSquare(unittest.TestCase):
    def test_multiples_of_ninety_are_square(self):
        for rot in (0, 90, 180, 270, 360, -90):
            self.assertAlmostEqual(cc.off_square(rot), 0.0)

    def test_the_distance_is_to_the_nearest_right_angle(self):
        self.assertAlmostEqual(cc.off_square(3.0), 3.0)
        self.assertAlmostEqual(cc.off_square(87.5), 2.5)
        self.assertAlmostEqual(cc.off_square(183.0), 3.0)
        self.assertAlmostEqual(cc.off_square(45.0), 45.0)


class Census(unittest.TestCase):
    def test_counts_square_stacks_and_levels(self):
        layout = {"name": "t", "props": [box(0, 2), box(90.3), box(2.0, 3, "container_40"), box(30),
                                         {"type": "wreck", "position": [1, 1], "rotation_deg": 0}]}
        r = cc.census(layout, 0.5)
        self.assertEqual(r["containers"], 4)
        self.assertEqual(r["square"], 2)
        self.assertEqual(r["stacked"], 2)
        self.assertEqual(r["drawn"], 7)
        self.assertEqual(r["off_hist"], {"<=0.5": 2, "<=2": 1, "<=45": 1})

    def test_it_fails_a_dealt_map_that_is_too_square(self):
        with tempfile.TemporaryDirectory() as d:
            # "yard" is in Arena.ROTATION; the name, not the file, is what the scope reads.
            path = os.path.join(d, "yard.json")
            with open(path, "w") as f:
                json.dump({"name": "yard", "props": [box(0), box(0), box(3)]}, f)
            self.assertEqual(cc.main([path, "--max-square-share", "0.5"]), 1)
            self.assertEqual(cc.main([path, "--max-square-share", "0.7"]), 0)
            # A fixture is outside the rotation scope however square it is.
            with open(path, "w") as f:
                json.dump({"name": "maze_like", "fixture": True, "props": [box(0)]}, f)
            self.assertEqual(cc.main([path, "--max-square-share", "0.0"]), 0)
            self.assertEqual(cc.main([path, "--max-square-share", "0.0", "--scope", "all"]), 1)


if __name__ == "__main__":
    unittest.main()
