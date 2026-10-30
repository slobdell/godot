#!/usr/bin/env python3
"""Known answers for tests/replay/playtest_report.py's selection section (round 47 N3: orders' `inp` rows, C47.4)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import playtest_report as pr  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SUMPS = os.path.join(REPO, "references", "round46", "playtest", "2026-10-30T15-53-39-sumps.jsonl")

BRAVO = ["Green_Bravo_%d" % i for i in range(1, 6)]
CHARLIE = ["Green_Charlie_%d" % i for i in range(1, 6)]


def sel(frame, tick, units, squads=None):
    return {"t": "sel", "frame": frame, "tick": tick, "units": units, "squads": squads or [""], "inspected": ""}


def inp(frame, k, act, before, after):
    return {"t": "inp", "f": frame, "k": k, "act": act, "sel_before": before, "sel_after": after}


class Selections(unittest.TestCase):
    def test_each_change_names_the_input_that_made_it(self):
        rows = [{"t": "match", "tick_rate": 30}, sel(601, 0, BRAVO), inp(601, "2", "select_group", [], BRAVO),
                inp(618, "mouse_left", "box_select", BRAVO, CHARLIE), sel(618, 0, CHARLIE)]
        changes = pr.selection_changes(rows)
        self.assertEqual([c["by"] for c in changes], ["2 select_group", "mouse_left box_select"])
        self.assertEqual(changes[1]["before"], BRAVO)

    def test_a_change_with_no_input_row_is_the_games(self):
        rows = [{"t": "match", "tick_rate": 30}, inp(601, "2", "select_group", [], BRAVO), sel(601, 0, BRAVO),
                sel(618, 0, CHARLIE)]
        changes = pr.selection_changes(rows)
        self.assertEqual(changes[1]["by"], pr.NO_INPUT)
        self.assertTrue(pr.has_inp(rows))

    def test_an_order_input_is_not_a_selection_change(self):
        rows = [{"t": "match", "tick_rate": 30}, inp(601, "2", "select_group", [], BRAVO), sel(601, 0, BRAVO),
                inp(700, "mouse_right", "move", BRAVO, BRAVO)]
        self.assertEqual(len(pr.selection_changes(rows)), 1)
        self.assertEqual([r["act"] for r in pr.order_inputs(rows)], ["move"])

    def test_the_summary_counts_the_games_changes(self):
        rows = [{"t": "match", "tick_rate": 30}, inp(601, "2", "select_group", [], BRAVO), sel(601, 30, BRAVO),
                sel(618, 60, CHARLIE)]
        text = "\n".join(pr.summary(rows, "x.jsonl", None, "x.txt"))
        self.assertIn("selection: 2 changes, 1 by no key or click (first at 2.0 s: Charlie:5)", text)

    def test_before_round_47_says_so(self):
        rows = [{"t": "match", "tick_rate": 30}, sel(601, 0, BRAVO), sel(618, 0, CHARLIE)]
        self.assertFalse(pr.has_inp(rows))
        self.assertEqual(pr.selection_changes(rows)[1]["by"], pr.NO_ROWS)
        text = "\n".join(pr.section_selection(rows))
        self.assertIn("before round 47", text)

    def test_his_sumps_frames_601_618(self):
        rows = pr.rows_of(SUMPS)
        changes = [c for c in pr.selection_changes(rows) if c["frame"] in (601, 618)]
        self.assertEqual([c["squads_words"] for c in changes], ["Bravo:5", "Charlie:5"])
        text = "\n".join(pr.section_selection(rows))
        self.assertIn("frame 618", text)


if __name__ == "__main__":
    unittest.main()
