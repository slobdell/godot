#!/usr/bin/env python3
"""face_pairs.py's own tests (R33.26: P3's (2c) paired BY FACE). Run: make planner-pytest"""
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import face_pairs  # noqa: E402


def ep(name, home, served=False, plan_far=0.0, hull_far=0.0, kept=False, abandoned=0, refused=None):
    return {"name": name, "home": list(home), "asked": 10, "asks": 1, "served": served, "kept": kept,
            "plan_far": plan_far, "refused": refused or {}, "abandoned": abandoned, "hull_far": hull_far, "ticks": 300,
            "closed_by": "order"}


def write(root, arm, task, seed, episodes):
    d = os.path.join(root, arm, "gangs", "%s-%d" % (task, seed))
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "run.log"), "w") as f:
        f.write("PLANNER_SEAM_REPORT " + json.dumps({"face_episodes": episodes}) + "\n")


class Pairing(unittest.TestCase):
    def test_episodes_pair_by_crew_and_home(self):
        base = [ep("A", (0, 0), served=True, plan_far=3.0), ep("B", (10, 0), abandoned=1, hull_far=2.0),
                ep("C", (20, 0), served=True, plan_far=4.0)]
        cand = [ep("A", (0.4, 0.2), served=True, plan_far=2.0), ep("B", (10, 0), served=True, plan_far=5.0, hull_far=5.5),
                ep("C", (20, 0), refused={"GOAL_BLOCKED": 1}, hull_far=1.0), ep("D", (30, 0), served=True, plan_far=1.0)]
        classes = face_pairs.classify(base, cand)
        self.assertEqual([(b["name"], c["name"]) for b, c in classes["both"]], [("A", "A")])
        self.assertEqual([(b["name"], c["name"]) for b, c in classes["candidate_only"]], [("B", "B")])
        self.assertEqual([(b["name"], c["name"]) for b, c in classes["base_only"]], [("C", "C")])
        self.assertEqual([e["name"] for e in classes["unmatched_candidate"]], ["D"])
        self.assertEqual(classes["unmatched_base"], [])

    def test_the_same_crew_at_two_homes_pairs_in_order(self):
        base = [ep("A", (0, 0), served=True, plan_far=1.0), ep("A", (5, 5), served=True, plan_far=2.0)]
        cand = [ep("A", (0, 0), served=True, plan_far=1.5), ep("A", (5, 5), served=True, plan_far=2.5)]
        both = face_pairs.classify(base, cand)["both"]
        self.assertEqual([(b["plan_far"], c["plan_far"]) for b, c in both], [(1.0, 1.5), (2.0, 2.5)])


class Verdict(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def run_tool(self, *extra):
        out = io.StringIO()
        with redirect_stdout(out):
            code = face_pairs.main([self.root, *extra])
        return code, out.getvalue()

    def fill(self, cand_far_both, cand_hull_only):
        for seed in range(1, 9):
            for mode in ("drawn", "clicked"):
                write(self.root, "base_" + mode, "faced_move", seed,
                      [ep("A", (0, 0), served=True, plan_far=1.0, hull_far=3.0 + seed * 0.1),
                       ep("B", (9, 0), abandoned=1, hull_far=4.0 + seed * 0.1)])
                write(self.root, "new_" + mode, "faced_move", seed,
                      [ep("A", (0, 0), served=True, plan_far=1.0, hull_far=cand_far_both + seed * 0.1),
                       ep("B", (9, 0), served=True, kept=True, plan_far=cand_hull_only, hull_far=cand_hull_only + seed * 0.1)])

    def test_no_worse_passes(self):
        self.fill(3.0, 3.0)
        code, out = self.run_tool()
        self.assertEqual(code, 0, out)
        self.assertIn("FACE_PAIRS_BOTH clicked | faces 8", out)
        self.assertIn("FACE_PAIRS_CAND_ONLY clicked | faces 8", out)
        self.assertNotIn("FAIL", out)
        self.assertIn("FACE_PAIRS line (2c): ALL PASS", out)

    def test_a_hull_farther_on_faces_both_planned_fails(self):
        self.fill(9.0, 3.0)
        _, out = self.run_tool()
        both = [l for l in out.splitlines() if l.startswith("FACE_PAIRS_BOTH drawn")][0]
        self.assertTrue(both.endswith("FAIL"), both)
        self.assertIn("FACE_PAIRS line (2c): NOT ALL PASS", out)

    def test_farther_than_the_bases_hull_on_its_own_faces_fails(self):
        self.fill(3.0, 12.0)
        _, out = self.run_tool()
        only = [l for l in out.splitlines() if l.startswith("FACE_PAIRS_CAND_ONLY clicked")][0]
        self.assertTrue(only.endswith("FAIL"), only)

    def test_distinct_reads_a_repeated_pair_once(self):
        self.fill(3.0, 3.0)
        for mode in ("drawn", "clicked"):   # seed 9 repeats seed 1 row for row
            for arm in ("base_", "new_"):
                src = os.path.join(self.root, arm + mode, "gangs", "faced_move-1", "run.log")
                d = os.path.join(self.root, arm + mode, "gangs", "faced_move-9")
                os.makedirs(d)
                with open(src) as f, open(os.path.join(d, "run.log"), "w") as g:
                    g.write(f.read())
        _, out = self.run_tool("--distinct")
        self.assertIn("FACE_PAIRS_DISTINCT clicked | distinct pairs 8 of 9", out)
        self.assertIn("FACE_PAIRS_BOTH clicked | faces 8", out)


if __name__ == "__main__":
    unittest.main()
