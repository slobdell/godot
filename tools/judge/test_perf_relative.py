#!/usr/bin/env python3
"""perf_relative.py: perf-judge's two lines read side by side (known answers)."""
import contextlib
import io
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import perf_relative  # noqa: E402

B0 = 'cpu="13th Gen Intel(R) Core(TM) i5-1345U"'
B2 = 'cpu="AMD EPYC 7B12"'


def line(attempt, host, absolute, relative, per_ref, cpu, trial=""):
    return ("PERF_JUDGE_RELATIVE attempt=%d host=%s absolute=%s relative=%s per_ref_ms=%s line=25840 ai_usec_per_tick=9000 "
            "ratio=1.01x %s%s\n" % (attempt, host, absolute, relative, per_ref, cpu, trial))


class PerfRelative(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        for folder, text in {
            "godot-a": line(1, "builder0", "PASS", "PASS", 12000, B0),
            "godot-b": line(1, "builder0", "REFUSED", "PASS", 13000, B0) + line(2, "builder0", "PASS", "FAIL", 26000, B0),
            "trial": line(1, "builder2", "FAIL", "PASS", 7000, B2, " trial=1") + line(2, "builder2", "FAIL", "PASS", 7400, B2, " trial=1")
                     + "PERF_JUDGE attempt=1 state=FAIL (not a relative line)\n",
        }.items():
            os.makedirs(os.path.join(self.tmp, folder))
            with open(os.path.join(self.tmp, folder, "perf-judge.txt"), "w") as f:
                f.write(text)

    def test_groups_agreement_and_spread(self):
        report = perf_relative.summarize(perf_relative.read([self.tmp]))
        self.assertEqual([g["host"] for g in report], ["builder0", "builder2"])
        b0, b2 = report
        self.assertEqual(b0["cpu"], "13th Gen Intel(R) Core(TM) i5-1345U")
        self.assertEqual((b0["attempts"], b0["both_judged"], b0["agree"]), (3, 2, 1))
        self.assertEqual(b0["disagree"], ["godot-b:2"])
        self.assertEqual(b0["absolute"], {"PASS": 2, "REFUSED": 1})
        self.assertEqual((b0["per_ref_median"], b0["per_ref_min"], b0["per_ref_max"]), (13000, 12000, 26000))
        self.assertEqual((b2["attempts"], b2["both_judged"], b2["agree"], b2["per_ref_median"]), (2, 2, 0, 7400))

    def test_render_and_unknown_numbers(self):
        rec = perf_relative.parse('PERF_JUDGE_RELATIVE attempt=1 host=x absolute=CRASHED relative=NO_RESULT per_ref_ms=? line=25840 cpu="a b"')
        self.assertIsNone(rec["per_ref_ms"])
        self.assertEqual(rec["cpu"], "a b")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            perf_relative.main([self.tmp])
        self.assertIn("both judged 2, agree 1; DISAGREE godot-b:2", out.getvalue())
        self.assertIn("usec per reference ms: median 7400 (min 7000, max 7400) v the line 25840", out.getvalue())


if __name__ == "__main__":
    unittest.main()
