#!/usr/bin/env python3
"""aa.py: a replay is refused, two seed sets read as a swing, the same seeds under different code as paired divergence."""
import contextlib
import io
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
REF = os.path.join(ROOT, "_agents", "streams", "references")
sys.path.insert(0, HERE)
import aa  # noqa: E402


def run(*argv):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = aa.main(list(argv))
    return code, out.getvalue()


class AA(unittest.TestCase):
    def test_round_28_and_29_t0_are_the_same_run_and_are_refused(self):
        code, out = run(os.path.join(REF, "round28/traffic/t0-c6e32d03-gd-seeds123.jsonl"), os.path.join(REF, "round29/traffic/t0_3cd5596b_seeds123.jsonl"),
                        "--case", "terminus/cross", "--metrics", "fast,arrived,allin")
        self.assertEqual(code, 0)
        self.assertIn("REFUSED, the two files are the same run", out)

    def test_two_seed_sets_of_the_hold_on_arm_read_as_a_swing(self):
        code, out = run(os.path.join(REF, "round29/traffic/judged_hold_3a94f38d_seeds131415.jsonl"),
                        os.path.join(REF, "round29/traffic/t3_judged_base_d9b3339c_seeds222324.jsonl"), "--case", "terminus/head")
        self.assertIn("DIFFERENT SEED SETS (18 and 18 runs)", out)
        self.assertIn("fast     totals 379 v 322", out)
        self.assertIn("xfast    totals 91 v 54", out)

    def test_same_seeds_different_code_reads_paired_divergence(self):
        code, out = run(os.path.join(REF, "round29/traffic/t0_3cd5596b_seeds123.jsonl"),
                        os.path.join(REF, "round29/traffic/t3_tuning_base_fcddda26_seeds123.jsonl"), "--case", "terminus/head", "--metrics", "fast,arrived")
        self.assertIn("SAME SEEDS (18 runs), different code", out)
        self.assertIn("paired sd", out)


if __name__ == "__main__":
    unittest.main()
