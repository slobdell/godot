#!/usr/bin/env python3
"""inventory.py end to end on the repo's own references: it runs, writes both files, and reproduces the verdict
scripts' numbers for the lines whose rows are kept (the quoted totals must come back out of the rows)."""
import csv
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import inventory  # noqa: E402
import lines  # noqa: E402


class Inventory(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.table = inventory.build(ROOT)
        cls.by_line = {(r["round"], r["item"], r["line"]): r for r in cls.table}

    def test_every_line_has_a_row_and_a_source(self):
        self.assertEqual(len(self.table), len(lines.LINES))
        for r in self.table:
            self.assertTrue(r["source"], r["line"])
            self.assertIn(r["verdict"].split()[0], ("PASS", "FAIL", "KEPT", "REPORTED", "VOID"), r["verdict"])

    def test_cp_t_between_squad_line_reproduces_the_verdict_and_its_noise(self):
        r = self.by_line[(29, "CP-T", "Terminus head-on between-squad fast down >= 25 %")]
        self.assertIn("rows: 475 -> 91", r["reproduced"])
        self.assertEqual(r["line_inside_noise"], "Y")  # 25 % of 475 = 119 < 1.645 * 76.7
        self.assertAlmostEqual(float(r["noise_se"]), 18.09 * 18 ** 0.5, delta=0.5)
        self.assertGreater(float(r["verdict_margin_se"]), 3.0)  # the -81 % cleared the line by > 3 se

    def test_t3_all_in_median_line_is_inside_the_noise_and_failed_by_a_fifth_of_an_se(self):
        r = self.by_line[(29, "T3", "Terminus crossing all-in median <= base + 20 %")]
        self.assertIn("median 39.4 -> 48.3", r["reproduced"])
        self.assertEqual(r["line_inside_noise"], "Y")
        self.assertLess(abs(float(r["verdict_margin_se"])), 0.5)

    def test_untouched_cases_read_as_identical_arms(self):
        r = self.by_line[(29, "CP-T", "other three cases: fast and all-in within 2 se, crews >= base - 2")]
        self.assertTrue(r["noise_how"].startswith("identical arms"))
        self.assertEqual(r["line_inside_noise"], "n/a")

    def test_m1_guard_lines_are_all_inside_the_noise(self):
        guards = [r for r in self.table if r["round"] == 29 and r["item"] == "M1" and "still moving at 75 s" in r["line"]]
        self.assertEqual(len(guards), 6)
        self.assertTrue(all(r["line_inside_noise"] == "Y" for r in guards))
        attack = [r for r in guards if r["line"].startswith("faced_attack_move")][0]
        self.assertAlmostEqual(float(attack["noise_se"]), (2.8 ** 2 + 4.4 ** 2 + 8.9 ** 2) ** 0.5, places=1)

    def test_count_lines_carry_exact_p_and_the_n_that_decides(self):
        b1 = self.by_line[(29, "B1", "median shooter bearing <= 35 deg in >= 16/18 runs")]
        self.assertLess(float(b1["exact_p"]), 1e-6)
        self.assertEqual(b1["n_decides"], "3")
        yard = self.by_line[(29, "B5c", "yard crossing last-crew-in median on <= off - 5 s")]
        self.assertLess(float(yard["exact_p"]), 0.01)
        self.assertEqual(yard["n_decides"], "9")
        s4 = self.by_line[(27, "S4", "gang_scout his case: contact runs -> 0 of 18 (partial >= -50 %)")]
        self.assertLess(float(s4["exact_p"]), 0.001)  # the one-sided p follows the observed direction (fewer contacts)

    def test_b3_census_line_reproduces_the_quoted_per_seed_numbers(self):
        r = self.by_line[(28, "B3 CPU screens", "enemy hull contacts under an ordered MOVE down >= 50 % (all units)")]
        self.assertIn("rows: 111 -> 28", r["reproduced"])  # 9.25 and 2.33 a seed over 12 seeds
        self.assertAlmostEqual(float(r["noise_se"]), 2.71 * 12, delta=0.2)  # the quoted se 2.71 is of the per-seed mean
        self.assertEqual(r["line_inside_noise"], "N")

    def test_writes_csv_and_markdown(self):
        tmp = tempfile.mkdtemp()
        csv_path, md_path = os.path.join(tmp, "inv.csv"), os.path.join(tmp, "inv.md")
        inventory.write_csv(self.table, csv_path)
        inventory.write_md(self.table, md_path, "inv.csv")
        with open(csv_path) as handle:
            rows_back = list(csv.DictReader(handle))
        self.assertEqual(len(rows_back), len(self.table))
        self.assertEqual(list(rows_back[0].keys()), inventory.COLUMNS)
        with open(md_path) as handle:
            text = handle.read()
        self.assertIn("## Pass lines inside the noise", text)
        self.assertIn("| 29 | manoeuvre | M1 | faced_attack_move", text)


if __name__ == "__main__":
    unittest.main()
