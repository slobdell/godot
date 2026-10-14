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

    def test_hull_rest_guard_row_matches_the_m1_class_table(self):
        r = self.by[("hull-rest probe (a task)", "crews still moving at 75 s, wheeled turret")]
        self.assertAlmostEqual(r["sd_run"], 1.46, delta=0.05)
        self.assertTrue(300 <= r["n_needed"] <= 450, r["n_needed"])
        self.assertAlmostEqual(r["guard_today"], 12.5, delta=0.5)

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
        with open(csv_path) as handle:
            back = list(csv.DictReader(handle))
        self.assertEqual(len(back), len(self.rows))
        self.assertEqual(list(back[0].keys()), table.COLUMNS)
        with open(os.path.join(ROOT, "_agents", "judging.md")) as handle:
            self.assertEqual(handle.read(), text)  # the committed doc IS the rendered doc


if __name__ == "__main__":
    unittest.main()
