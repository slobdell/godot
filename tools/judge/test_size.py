#!/usr/bin/env python3
"""size.py: the worked examples in _agents/judging.md come back out of the files they cite."""
import contextlib
import io
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
REF = os.path.join(ROOT, "_agents", "streams", "references")
sys.path.insert(0, HERE)
import size  # noqa: E402


def run(*argv):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = size.main(list(argv))
    return code, out.getvalue()


class Size(unittest.TestCase):
    def test_m1_guard_worked_example(self):
        code, out = run("--class-table", os.path.join(REF, "round29/manoeuvre/m1_judged.txt"), "--task", "faced_attack_move", "--guard", "5")
        self.assertEqual(code, 0)
        self.assertIn("se of the sum 10.3", out)
        self.assertIn("point guard '<= base + 5': FAIL", out)
        self.assertIn("a null fails it 31 %", out)
        self.assertIn("= +17.0: PASS", out)
        self.assertIn("n that decides it 529", out)

    def test_t3_all_in_worked_example(self):
        code, out = run("--base", os.path.join(REF, "round29/traffic/t3_judged_base_d9b3339c_seeds222324.jsonl"),
                        "--arm", os.path.join(REF, "round29/traffic/t3_judged_arm_d9b3339c_seeds222324.jsonl"),
                        "--case", "terminus/cross", "--metric", "allin", "--stat", "median", "--guard-share", "0.2")
        self.assertEqual(code, 0)
        self.assertIn("medians 39.4 -> 48.3", out)
        self.assertIn("point guard '<= base + 7.88': FAIL", out)
        self.assertIn("YES, a null fails this guard 9 %", out)
        self.assertIn("(+9.86): PASS", out)

    def test_t3_crews_and_pooled_gain(self):
        base = os.path.join(REF, "round29/traffic/t3_judged_base_d9b3339c_seeds222324.jsonl")
        arm = os.path.join(REF, "round29/traffic/t3_judged_arm_d9b3339c_seeds222324.jsonl")
        code, out = run("--base", base, "--arm", arm, "--case", "yard_open/cross", "--metric", "arrived", "--guard", "2")
        self.assertIn("total 171.00 -> 167.00", out)
        self.assertIn("a null fails this guard 26 %", out)
        code, out = run("--base", base, "--arm", arm, "--case", "terminus/cross,yard_open/cross", "--metric", "xfast", "--gain-share", "0.25")
        self.assertIn("total 206.00 -> 95.00", out)
        self.assertIn("inside the noise? x = 51.50 v 1.645 se = 23.87: no", out)
        self.assertIn("one-sided: 18", out)

    def test_counts_thresholds_cells(self):
        _c, out = run("--count", "12/12", "5/12")
        self.assertIn("p 0.0023", out)
        self.assertIn("power: 9", out)
        _c, out = run("--count", "12/12", "10/12")
        self.assertIn("NOT decided", out)
        _c, out = run("--threshold", "10/18", "12")
        self.assertIn("p 0.50 -> 0.12", out)
        _c, out = run("--cells", "11", "0")
        self.assertIn("p 0.0010: decided", out)

    def test_table_row_and_bare_sd(self):
        code, out = run("--probe", "traffic-series terminus/head", "--metric", "xfast", "--effect-share", "0.25")
        self.assertEqual(code, 0)
        self.assertIn("one-sided: 57", out)
        self.assertIn("MDE 9.785", out)
        code, out = run("--sd", "4", "--effect", "1", "--n", "25")
        self.assertIn("one-sided: 99", out)

    def test_no_arguments_is_an_error(self):
        code, _out = run()
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
