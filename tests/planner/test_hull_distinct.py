#!/usr/bin/env python3
"""The distinct-pairs rule (round 33 overnight, as for CP-F's R33.23): hull-rest barely varies with the seed (manoeuvre
found seeds 40 = 43 and 44 = 45 row for row), so a judged verdict counts a (base, candidate) pair once however many seeds
repeat it, and reports how many distinct pairs each cell has. Shared by hull_aa.py --distinct, face_keep_table.py
--distinct and kept_share.py --distinct. Run: make planner-pytest
"""
import contextlib
import io
import json
import os
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hull_distinct  # noqa: E402
import face_keep_table  # noqa: E402
import face_pairs  # noqa: E402
import kept_share  # noqa: E402


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



def write_run(root, arm, seed, screen, report):
    run = pathlib.Path(root, arm, "gangs", "faced_move-%s" % seed)
    run.mkdir(parents=True, exist_ok=True)
    (run / "screen.json").write_text(json.dumps(screen))
    (run / "run.log").write_text("noise\nPLANNER_SEAM_REPORT " + json.dumps(report) + "\n")


class RunIdentity(unittest.TestCase):
    """Round 34 (P4 (a)): every tool keeps the same pairs, keyed on the whole run, not on its own rows."""

    def layout(self):
        root = tempfile.mkdtemp()
        report = {"asks_by_kind": {"face": 2}, "abandoned_by_kind": {"face": 0}, "face_far": [1.0], "face_kept_served": 1,
                  "face_kept_fallbacks": 0, "face_episodes": []}
        for mode in ("drawn", "clicked"):
            # seeds 1 and 2: the same face counters, different hulls (screen.json): two distinct runs
            write_run(root, "base_" + mode, 1, [{"scenario": "faced_move", "x": 1}], report)
            write_run(root, "new_" + mode, 1, [{"scenario": "faced_move", "x": 1}], report)
            write_run(root, "base_" + mode, 2, [{"scenario": "faced_move", "x": 2}], report)
            write_run(root, "new_" + mode, 2, [{"scenario": "faced_move", "x": 2}], report)
            # seed 3 repeats seed 1 byte for byte: counted once
            write_run(root, "base_" + mode, 3, [{"scenario": "faced_move", "x": 1}], report)
            write_run(root, "new_" + mode, 3, [{"scenario": "faced_move", "x": 1}], report)
        return root

    def test_a_run_repeated_byte_for_byte_counts_once_and_matching_counters_alone_do_not(self):
        root = self.layout()
        keys = [("gangs", "faced_move", s) for s in ("1", "2", "3")]
        kept, cells = hull_distinct.distinct_runs(root, keys, lambda _k: ("base_drawn", "new_drawn"))
        self.assertEqual(kept, [("gangs", "faced_move", "1"), ("gangs", "faced_move", "2")])
        self.assertEqual(cells[("gangs", "faced_move")], (2, 3))

    def test_every_tool_reports_the_same_distinct_count(self):
        root = self.layout()
        counts = {}
        for name, run in (("face_keep_table", lambda: (setattr(sys, "argv", ["x", root, "--distinct"]), face_keep_table.main())),
                          ("face_pairs", lambda: face_pairs.main([root, "--distinct"])),
                          ("kept_share", lambda: kept_share.main(["x", root, "--distinct"]))):
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                run()
            counts[name] = sorted(line.split("|")[1].strip() for line in out.getvalue().splitlines() if "_DISTINCT " in line)
        self.assertEqual(counts["face_keep_table"], ["distinct pairs 2 of 3"] * 2, counts)
        self.assertEqual(counts["face_pairs"], counts["face_keep_table"])
        self.assertEqual(counts["kept_share"], counts["face_keep_table"])


if __name__ == "__main__":
    unittest.main()
