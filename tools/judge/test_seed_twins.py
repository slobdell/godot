#!/usr/bin/env python3
"""seed_twins (R34.15): the random-arena twin of a fixed-arena fight is dropped, nothing else is."""
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import seed_twins  # noqa: E402


class SeedTwins(unittest.TestCase):
    def test_traffics_count_on_the_real_table(self):
        dealt, rot = seed_twins.load()
        self.assertIn("locks", rot)
        twins = [s for s in range(1200, 1248) if dealt[s] in ("locks", "terminus")]
        self.assertEqual(len(twins), 14)  # traffic's finding: 14 of 48 random seeds dealt the Locks or the Terminus

    def test_only_a_random_row_whose_dealt_map_is_in_the_series_on_that_seed_goes(self):
        dealt = {1: "locks", 2: "pit", 3: "terminus"}
        rows = [{"arena": "locks", "seed": 1}, {"arena": "random", "seed": 1},  # twin of the Locks 1: dropped
                {"arena": "terminus", "seed": 2}, {"arena": "random", "seed": 2},  # dealt the Pit: kept
                {"arena": "random", "seed": 3},  # dealt the Terminus, but the Terminus 3 is not in the series: kept
                {"arena": "random", "seed": 99}]  # outside the table: kept
        kept, dropped = seed_twins.drop_twins(rows, dealt)
        self.assertEqual(dropped, [{"arena": "random", "seed": 1}])
        self.assertEqual(len(kept), 5)

    def test_a_table_for_another_rotation_is_refused(self):
        path = os.path.join(tempfile.mkdtemp(), "t.txt")
        with open(path, "w") as handle:
            handle.write('# Arena.ROTATION ["yard", "pit"]\nRANDOM_ARENA 1 pit\n')
        with self.assertRaises(ValueError):
            seed_twins.load(path, rotation=["yard", "pit", "locks"])


if __name__ == "__main__":
    unittest.main()
