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
            # NULL: a precondition the bar named was not met (T1c-b2, lesson 300); NOT READABLE: R32.7's defective reader
            self.assertIn(r["verdict"].split()[0], ("PASS", "FAIL", "KEPT", "REPORTED", "VOID", "NULL", "NOT"), r["verdict"])

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

    def test_rounds_31_to_34_are_in_and_their_kept_rows_reproduce_the_quotes(self):
        """C35.9: the owed rounds; where the rows are on main the readers give back the streams' own numbers."""
        self.assertEqual({r["round"] for r in self.table} & {31, 32, 33, 34}, {31, 32, 33, 34})
        r = self.by_line[(31, "M1b(2) attempt 2", "(g) Terminus mixed arrivals not down beyond 1.645 se")]
        self.assertIn("rows: 293 -> 285", r["reproduced"])  # the bar's "293 -> 285 of 312, diff -8, se 4.55"
        self.assertAlmostEqual(float(r["noise_se"]), 4.55, delta=0.01)
        self.assertLess(float(r["verdict_margin_se"]), 0.0)  # FAILED, by a tenth of an se
        r = self.by_line[(31, "B3b-2b", "(1) his bridge, the full 108: on 108/108")]
        self.assertIn("rows: 106/108 -> 108/108", r["reproduced"])
        r = self.by_line[(31, "B3b-2b", "(3) arrive series: every crew within 8 m on >= control - 1 AND discordant against <= 1")]
        self.assertAlmostEqual(float(r["exact_p"]), 0.065, delta=0.001)  # the stream's "McNemar p 0.065"
        r = self.by_line[(31, "B5c-v5", "(3) Sumps all-within-8 m median on <= off")]
        self.assertIn("median 24.9 -> 24.8", r["reproduced"])

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

    def test_round_30_lines_reproduce_the_bars_block(self):
        clock = self.by_line[(30, "T3b", "yard crossing clock: mean paired cross_clear_s <= 0.10 x base median + 1.645 se (judged se)")]
        self.assertEqual(clock["verdict"], "FAIL")
        self.assertAlmostEqual(float(clock["noise_se"]), 0.22, places=2)
        self.assertAlmostEqual(float(clock["line_x"]), 1.18, places=2)  # 0.10 x 8.2 + 1.645 x 0.22: the verdict's limit
        self.assertEqual(clock["line_inside_noise"], "N")
        self.assertLess(float(clock["verdict_margin_se"]), -7.0)
        art = self.by_line[(30, "T1c-b", "artillery shots not down > 21.6 (row 82; one Parade run 171 -> 26 carried it)")]
        self.assertIn("rows: 318 -> 163", art["reproduced"])
        self.assertEqual(art["line_inside_noise"], "Y")  # the judged se is ~144: row 82's 21.6 was under-sized
        creep = self.by_line[(30, "M2b", "(a) open+static creep episodes down >= 50 % (census 14-19 + sim 9-11, paired per run)")]
        self.assertIn("rows: 53 -> 37", creep["reproduced"])
        self.assertAlmostEqual(float(creep["noise_se"]), 9.76, places=1)
        rigs = self.by_line[(30, "M2b", "(c) Terminus rigs arrivals not down beyond 1.645 se (the SPRT at the full grid read PASS; truncation decides by the fixed test)")]
        self.assertEqual(rigs["verdict"], "FAIL")
        self.assertAlmostEqual(float(rigs["noise_se"]), 4.97, places=2)
        pinned = self.by_line[(30, "M4b run 2", "(b2) pinned crew-seconds DOWN beyond 2 se (paired, n = 144)")]
        self.assertIn("2596 -> 658", pinned["reproduced"])
        self.assertGreater(float(pinned["verdict_margin_se"]), 2.5)
        identical = self.by_line[(30, "M4b run 2", "(b1) Terminus rigs arrivals not down beyond 1.645 se")]
        self.assertTrue(identical["noise_how"].startswith("identical arms"))
        guard = self.by_line[(30, "M1b", "faced_right: crews still moving at 75 s (all classes, drawn) <= base + 2 se (M1_CLASS's se)")]
        self.assertAlmostEqual(float(guard["noise_se"]), (2.8 ** 2 + 6.5 ** 2) ** 0.5, places=1)
        self.assertEqual(guard["line_inside_noise"], "N")  # a + 2 se line is sized by construction
        one_se = self.by_line[(30, "M1b", "(d) Terminus rigs arrivals not down beyond 1 se (sequential.py arrived:guard:0.10: SERIES PASS at run 10 of 13)")]
        self.assertEqual(one_se["line_inside_noise"], "Y")  # a 1 se line: a null fails it 16 % of the time
        yard = self.by_line[(30, "B5c-v4", "yard crossing: every crew in, on v off (the deciding line)")]
        self.assertLess(float(yard["exact_p"]), 1e-4)
        sumps = self.by_line[(30, "B5c-v4", "Sumps cell: all-within-8 m median on <= off (never = 90 s)")]
        self.assertIn("median 37.5 -> 24.5", sumps["reproduced"])
        arrive = self.by_line[(30, "B5c-v4", "arrive series: all-within-8 m median no slower than +2 % (over the cells complete in both arms)")]
        self.assertIn("median 29.6 -> 24.5 (n 91)", arrive["reproduced"])
        bridge = self.by_line[(30, "B3b", "his bridge 108/108 (the full 108, deterministic; control = main's rules reported)")]
        self.assertEqual(bridge["reproduced"], "rows: 106/108 -> 107/108")
        self.assertEqual(bridge["exact_p"], "1.0000")

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
