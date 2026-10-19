#!/usr/bin/env python3
"""table.py (CP-N) end to end: it renders into a copy of judging.md, writes the csv, is idempotent, and its headline
numbers hold (the rows that the round-30 bars will cite)."""
import csv
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import probes  # noqa: E402
import table  # noqa: E402


class Table(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = table.table_rows(ROOT)
        cls.by = {(r["probe"], r["metric"]): r for r in cls.rows}

    def test_every_spec_has_a_row(self):
        self.assertEqual(len(self.rows), len(probes.build(ROOT)))
        self.assertGreaterEqual(sum(1 for r in self.rows if r.get("n_needed")), 40)

    def test_terminus_head_between_squad_line_needs_about_three_times_todays_n(self):
        r = self.by[("traffic-series terminus/head", "xfast")]
        self.assertTrue(14 <= r["sd_run"] <= 19, r["sd_run"])
        self.assertTrue(45 <= r["n_needed"] <= 70, r["n_needed"])
        self.assertTrue(0.35 <= r["mde_today_share"] <= 0.55, r["mde_today_share"])
        self.assertGreaterEqual(len(r["pairs"].split(";")), 4)

    def test_crews_guard_is_inside_the_noise_everywhere_squads_meet(self):
        for case in ("terminus/head", "terminus/cross", "yard_open/cross"):
            r = self.by[("traffic-series " + case, "arrived")]
            self.assertGreater(r["guard_today"], 2.0, case)  # the noise-sized guard is wider than "- 2"
            self.assertGreater(r["n_needed"], 100, case)

    def test_hull_rest_guard_row_pools_the_m1_m1b_and_round_33_class_tables(self):
        r = self.by[("hull-rest probe (a task)", "crews still moving at 75 s, wheeled turret")]
        # M1 alone read 1.46 (round 29's table), M1 + M1b 1.63 (round 30's); round 33's five tables (CP-F 1 both paths,
        # CP-F 3 at n 32, CP-Q and P3 on gangs at n 12) bring it to 1.50
        self.assertAlmostEqual(r["sd_run"], 1.50, delta=0.05)
        self.assertTrue(350 <= r["n_needed"] <= 470, r["n_needed"])
        self.assertEqual(r["n_today"], 32)
        self.assertAlmostEqual(r["guard_today"], 14.0, delta=0.5)
        self.assertIn("M1b 55622870", r["pairs"])
        self.assertIn("CP-F 3 22e9cab4e", r["pairs"])

    def test_round_30_pairs_are_pooled(self):
        rigs = self.by[("Terminus census, rigs (a seed)", "arrived (of 16)")]
        self.assertEqual(rigs["n_today"], 13)
        # M4, M1b, M2b, kturnarc, and round 33's two planner series (printed se); M4b run 2's rigs are byte-identical and out
        self.assertEqual(len(rigs["pairs"].split(";")), 6)
        self.assertNotIn("M4b run 2", rigs["pairs"])
        mixed = self.by[("Terminus census, mixed (a seed)", "arrived (of 24)")]
        self.assertEqual(len(mixed["pairs"].split(";")), 5)
        kills = self.by[("manoeuvre-fights (180 s)", "kills")]
        self.assertEqual(len(kills["pairs"].split(";")), 4)
        self.assertAlmostEqual(kills["sd_run"], 5.93, delta=0.05)  # se 21.5, 33.6 (n 24), CP-F's 25.6 (n 21) and 31.4 (n 23)
        art = self.by[("traffic-census (3 arenas x seeds)", "artillery shots")]
        self.assertGreater(art["sd_run"], 30.0)  # T1c-b's one Parade run: the T1b-style caveat
        clock = self.by[("traffic-series yard_open/cross", "xclear (crossing clock, s)")]
        self.assertAlmostEqual(clock["sd_run"], 0.92, delta=0.02)
        self.assertAlmostEqual(clock["se_today"], 0.217, delta=0.005)  # T3b quoted se 0.22
        sumps = self.by[("Sumps cell (seeds x 6 ticks, a run)", "all-within-8 m s (never = 90 s)")]
        self.assertAlmostEqual(sumps["base_run"], 37.53, delta=0.05)  # the base median B5c-v4 quoted as 37.5
        self.assertIn("sd_run", sumps)
        xfast = self.by[("traffic-series terminus/head", "xfast")]
        self.assertNotIn("T3b", xfast["pairs"])  # the turns rule fired in 2 of 18 head-on runs: untouched, not pooled

    def test_round_33_pairs_are_pooled(self):
        mixed = self.by[("Terminus census, mixed (a seed)", "arrived (of 24)")]
        self.assertNotIn("P3 v2", mixed["pairs"])  # the seam never fired for the mixed squad: se 0, an equality check
        aa = self.by[("hull-rest gangs A/A (a run, fifo v fifo)", "crews still moving at 75 s, wheeled turret")]
        self.assertAlmostEqual(aa["sd_run"], 1.81, delta=0.02)  # the null's own noise is no smaller than the pooled pairs'
        kills = self.by[("far census (terminus / locks / random fights)", "kills (L3)")]
        self.assertEqual(len(kills["pairs"].split(";")), 3)  # item 4's two pairs differ in < a third of their fights
        self.assertNotIn("item 4", kills["pairs"])
        self.assertAlmostEqual(kills["sd_run"], 5.96, delta=0.05)
        loops = self.by[("far census (terminus / locks / random fights)", "parked far loops (L1)")]
        self.assertEqual(len(loops["pairs"].split(";")), 5)
        shots = self.by[("orbit cells (scout duel, player post, a seed)", "shots")]
        self.assertEqual(len(shots["pairs"].split(";")), 3)

    def test_terminus_contact_ticks_cannot_carry_a_ten_percent_line(self):
        r = self.by[("Terminus census, rigs (a seed)", "wall contact-ticks")]
        self.assertGreater(r["n_needed"], 500)
        a = self.by[("Terminus census, rigs (a seed)", "arrived (of 16)")]
        self.assertTrue(8 <= a["n_needed"] <= 20, a["n_needed"])

    def test_untouched_or_unsized_rows_say_owed_or_point_to_counts(self):
        r = self.by[("bridge-pooled (18 cells) / his bridge 108", "cells passed")]
        self.assertNotIn("sd_run", r)
        self.assertIn("not a sample", r["aa"])

    def test_renders_idempotently_into_a_doc_copy_and_writes_the_csv(self):
        tmp = tempfile.mkdtemp()
        doc = os.path.join(tmp, "judging.md")
        shutil.copy(os.path.join(ROOT, "_agents", "judging.md"), doc)
        csv_path = os.path.join(tmp, "table.csv")
        out = subprocess.run([sys.executable, os.path.join(HERE, "table.py"), "--root", ROOT, "--doc", doc, "--csv", csv_path],
                             capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
        with open(doc) as handle:
            text = handle.read()
        self.assertEqual(text.count("<!-- judge:table:begin -->"), 1)
        self.assertIn("| traffic-series terminus/head | xfast |", text)
        self.assertIn("18/18 v 0/18", text)
        self.assertIn("12/12 v 1/12 (B5c-v4 yard r30", text)
        self.assertIn("hold ON (4 seed sets)", text)
        self.assertIn("the clicked pair at `55622870`", text)
        with open(csv_path) as handle:
            back = list(csv.DictReader(handle))
        self.assertEqual(len(back), len(self.rows))
        self.assertEqual(list(back[0].keys()), table.COLUMNS)
        with open(os.path.join(ROOT, "_agents", "judging.md")) as handle:
            self.assertEqual(handle.read(), text)  # the committed doc IS the rendered doc


if __name__ == "__main__":
    unittest.main()
