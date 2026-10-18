#!/usr/bin/env python3
"""The distinct-pairs rule (round 33 overnight, as for CP-F's R33.23): hull-rest barely varies with the seed (manoeuvre
found seeds 40 = 43 and 44 = 45 row for row), so a judged verdict counts a (base, candidate) pair once however many seeds
repeat it, and reports how many distinct pairs each cell has. Shared by hull_aa.py --distinct, face_keep_table.py
--distinct and kept_share.py --distinct. Run: make planner-pytest
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hull_distinct  # noqa: E402


def rec(moving, rest, settle=75.0):
    return {"classes": {"ALL": {"moving": moving, "rest": list(rest)}}, "settle": settle, "asks": 1, "abandoned": 0}


class Distinct(unittest.TestCase):
    def test_identical_pairs_in_one_cell_count_once(self):
        base = {("drawn", "f", "t", "1"): rec(1, [10]), ("drawn", "f", "t", "2"): rec(1, [10]),
                ("drawn", "f", "t", "3"): rec(2, [12])}
        new = {("drawn", "f", "t", "1"): rec(0, [9]), ("drawn", "f", "t", "2"): rec(0, [9]),
               ("drawn", "f", "t", "3"): rec(0, [9])}
        keys, cells = hull_distinct.distinct_keys(base, new, sorted(base))
        self.assertEqual(keys, [("drawn", "f", "t", "1"), ("drawn", "f", "t", "3")])
        self.assertEqual(cells[("drawn", "f", "t")], (2, 3))

    def test_a_pair_repeated_in_another_cell_is_still_counted(self):
        base = {("drawn", "f", "a", "1"): rec(1, [10]), ("drawn", "f", "b", "1"): rec(1, [10])}
        new = {("drawn", "f", "a", "1"): rec(0, [9]), ("drawn", "f", "b", "1"): rec(0, [9])}
        keys, _ = hull_distinct.distinct_keys(base, new, sorted(base))
        self.assertEqual(len(keys), 2)

    def test_the_same_base_with_a_different_candidate_is_distinct(self):
        base = {("clicked", "f", "t", "1"): rec(1, [10]), ("clicked", "f", "t", "2"): rec(1, [10])}
        new = {("clicked", "f", "t", "1"): rec(0, [9]), ("clicked", "f", "t", "2"): rec(1, [9])}
        keys, cells = hull_distinct.distinct_keys(base, new, sorted(base))
        self.assertEqual(len(keys), 2)
        self.assertEqual(cells[("clicked", "f", "t")], (2, 2))


if __name__ == "__main__":
    unittest.main()
