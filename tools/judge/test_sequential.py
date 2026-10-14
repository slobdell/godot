#!/usr/bin/env python3
"""sequential.py: the SPRT walk on synthetic rows (a clear gain stops early and passes; a null gain line fails; a harm
fails a guard) and the round-28/29 series' stop rows quoted in _agents/judging.md (S4)."""
import contextlib
import io
import math
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
REF = os.path.join(ROOT, "_agents", "streams", "references")
sys.path.insert(0, HERE)
import sequential  # noqa: E402

A, B = math.log(0.8 / 0.05), math.log(0.2 / 0.95)


class Synthetic(unittest.TestCase):
    def test_a_clear_gain_passes_early_and_a_null_fails(self):
        ln = sequential.Line("fast:gain:0.5", sd=4.0, base_run=10.0)  # effect 5 a run
        gain = [-6.0, -4.0, -7.0, -5.0, -6.0, -5.0, -4.0, -6.0, -5.0, -5.0, -6.0, -4.0]
        decision, stop, _path, trunc = ln.judge(gain, A, B, 6)
        self.assertEqual((decision, trunc), ("PASS", False))
        self.assertLess(stop, 12)
        null = [1.0, -1.0, 2.0, -2.0, 0.5, -0.5, 1.5, -1.5, 0.0, 1.0, -1.0, 0.0]
        decision, stop, _path, trunc = ln.judge(null, A, B, 6)
        self.assertEqual(decision, "FAIL")

    def test_a_guard_fails_on_harm_and_passes_on_nothing(self):
        ln = sequential.Line("arrived:guard:0.1", sd=1.0, base_run=10.0)  # harm = a FALL of 1 a run
        harm = [-1.0, -2.0, -1.0, -1.0, -2.0, -1.0, -1.0, -1.0]
        self.assertEqual(ln.judge(harm, A, B, 2)[0], "FAIL")
        nothing = [0.0] * 8
        decision, stop, _p, trunc = ln.judge(nothing, A, B, 2)
        self.assertEqual(decision, "PASS")
        self.assertLess(stop, 8)  # evidence of no harm accrues and crosses B before the grid ends

    def test_truncation_decides_by_the_fixed_test_not_the_sign(self):
        ln = sequential.Line("fast:gain:0.5", sd=10.0, base_run=10.0)  # effect 5 against sd 10: nothing decides in 6 runs
        tiny = [-0.5, -0.4, -0.6, -0.5, -0.4, -0.5]
        decision, stop, _p, trunc = ln.judge(tiny, A, B, 6)
        self.assertTrue(trunc)
        self.assertEqual(decision, "FAIL")  # a -0.5 mean on se 4.1 is not distinguishable from nothing

    def test_rate_line_is_a_bernoulli_sprt(self):
        ln = sequential.Line("onside35:rate:0.67:0.05", sd=0.0, base_run=0.0)
        self.assertEqual(ln.judge([1, 1, 1, 1, 1, 1], A, B, 6)[0], "PASS")
        self.assertEqual(ln.judge([0, 0, 0, 0, 0, 0], A, B, 6)[0], "FAIL")

    def test_series_fails_at_the_first_failing_line(self):
        g = sequential.Line("fast:gain:0.5", sd=4.0, base_run=10.0)
        gd = sequential.Line("arrived:guard:0.1", sd=1.0, base_run=10.0)
        d = {g.name: [-6.0] * 12, gd.name: [-2.0] * 12}
        decision, stop, _per = sequential.series_verdict([g, gd], d, A, B, 6)
        self.assertEqual(decision, "FAIL")
        self.assertEqual(stop, 6)


def run(*argv):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        sequential.main(list(argv))
    return out.getvalue()


class References(unittest.TestCase):
    def test_cp_t_terminus_head_passes_at_run_13(self):
        out = run("--base", os.path.join(REF, "round29/traffic/judged_base_3a94f38d_seeds131415.jsonl"),
                  "--arm", os.path.join(REF, "round29/traffic/judged_hold_3a94f38d_seeds131415.jsonl"), "--case", "terminus/head",
                  "--lines", "xfast:gain:0.25", "arrived:guard:0.05", "allin:guard:0.20", "--quiet")
        self.assertIn("SERIES PASS at run 13 of 18 (early)", out)
        self.assertIn("row  8 (seed 14 tick 3): xfast:gain:0.25 PASS", out)

    def test_cp_t_untouched_case_stops_after_one_seed_with_the_counter(self):
        out = run("--base", os.path.join(REF, "round29/traffic/judged_base_3a94f38d_seeds131415.jsonl"),
                  "--arm", os.path.join(REF, "round29/traffic/judged_hold_3a94f38d_seeds131415.jsonl"), "--case", "yard_open/cross",
                  "--lines", "fast:guard:0.2", "arrived:guard:0.05", "allin:guard:0.20", "--counter", "tr_verdicts", "--quiet")
        self.assertIn("SERIES PASS at run 6 of 18 (early) (UNTOUCHED", out)
        out = run("--base", os.path.join(REF, "round29/traffic/judged_base_3a94f38d_seeds131415.jsonl"),
                  "--arm", os.path.join(REF, "round29/traffic/judged_hold_3a94f38d_seeds131415.jsonl"), "--case", "terminus/cross",
                  "--lines", "fast:guard:0.2", "arrived:guard:0.05", "allin:guard:0.20", "--quiet")
        self.assertIn("at run 18 of 18 (the full grid)", out)  # without the counter the guards run the grid out

    def test_t3_pooled_gain_passes_at_run_8_and_t1v3_crossing_fails_at_6(self):
        out = run("--base", os.path.join(REF, "round29/traffic/t3_judged_base_d9b3339c_seeds222324.jsonl"),
                  "--arm", os.path.join(REF, "round29/traffic/t3_judged_arm_d9b3339c_seeds222324.jsonl"), "--case", "terminus/cross,yard_open/cross",
                  "--probe", "traffic-series crossings pooled", "--lines", "xfast:gain:0.25", "--quiet")
        self.assertIn("SERIES PASS at run 8 of 36 (early)", out)
        out = run("--base", os.path.join(REF, "round28/traffic/judged-jbase-672eb785-seeds456.jsonl"),
                  "--arm", os.path.join(REF, "round28/traffic/judged-jv3-672eb785-seeds456.jsonl"), "--case", "terminus/cross",
                  "--lines", "fast:gain:0.25", "arrived:guard:0.05", "allin:guard:0.20", "--quiet")
        self.assertIn("SERIES FAIL at run 6 of 18 (early)", out)

    def test_m4_terminus_rigs_fails_at_run_4(self):
        out = run("--terminus", os.path.join(REF, "round29/manoeuvre/m4_judged.txt"), "--squad", "rigs",
                  "--lines", "arrived:guard:0.10", "contacts:gain:0.25", "--min-runs", "2", "--quiet")
        self.assertIn("SERIES FAIL at run 4 of 6 (early)", out)

    def test_simulation_holds_alpha_on_the_cp_t_gain_line(self):
        out = run("--base", os.path.join(REF, "round29/traffic/judged_base_3a94f38d_seeds131415.jsonl"),
                  "--arm", os.path.join(REF, "round29/traffic/judged_hold_3a94f38d_seeds131415.jsonl"), "--case", "terminus/head",
                  "--lines", "xfast:gain:0.25", "--quiet", "--simulate", "600")
        line = [l for l in out.splitlines() if l.startswith("SIM xfast")][0]
        null_pass = float(line.split("null PASSES ")[1].split(" %")[0])
        self.assertLess(null_pass, 12.0, line)
        self.assertIn("observed rows: PASS 100 %", line)


if __name__ == "__main__":
    unittest.main()
