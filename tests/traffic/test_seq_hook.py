#!/usr/bin/env python3
"""seq_hook.py (round 31 I4): the running reading walks only the finished PREFIX of the grid, the lead's allowance
shifts a guard, a series reads CONTINUE until it is decided, and round 30's judged T3b rows read as filed."""
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
REF = os.path.join(ROOT, "_agents", "streams", "references", "round30", "traffic")
sys.path.insert(0, HERE)
import seq_hook  # noqa: E402


def row(seed, tick, clear, arrived=8, which="both"):
    return {"arena": "yard_open", "kind": "cross", "which": which, "seed": seed, "start_tick": tick, "crews": 8,
            "arrived": arrived, "cross_clear_s": clear, "end_s": 90.0, "contacts_fast": 0, "arrive_s": {"a": 10.0}}


def run(argv):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        seq_hook.main(argv)
    return out.getvalue()


class Hook(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = os.path.join(self.tmp.name, "base.jsonl")
        self.runs = os.path.join(self.tmp.name, "runs")
        os.mkdir(self.runs)
        with open(self.base, "w") as h:
            for s in (1, 2):
                for t in (1, 3, 6, 8, 11, 16):
                    h.write(json.dumps(row(s, t, 8.0)) + "\n")

    def tearDown(self):
        self.tmp.cleanup()

    def put(self, seed, tick, clear):
        with open(os.path.join(self.runs, "%d-%d.json" % (seed, tick)), "w") as h:
            h.write(json.dumps(row(seed, tick, clear)) + "\n")

    def test_a_row_finished_out_of_order_waits_for_its_turn(self):
        for t in (3, 6, 8, 11, 16):  # tick 1 of seed 1 not finished yet
            self.put(1, t, 10.8)
        out = run(["series", "--base", self.base, "--runs", self.runs, "--lines", "yard_open/cross=xclear:guard:abs=1.0"])
        self.assertIn("SEQ yard_open/cross 0/12", out)
        self.assertIn("SERIES CONTINUE", out)

    def test_the_allowance_turns_a_harm_into_a_pass(self):
        for s in (1, 2):
            for t in (1, 3, 6, 8, 11, 16):
                self.put(s, t, 10.8)  # +2.8 s every run, the T3b yard cost
        harm = run(["series", "--base", self.base, "--runs", self.runs, "--lines", "yard_open/cross=xclear:guard:abs=1.0"])
        self.assertIn("SERIES FAIL", harm)
        his = run(["series", "--base", self.base, "--runs", self.runs, "--lines",
                   "yard_open/cross=xclear:guard:abs=1.0:allow=3.0"])
        self.assertIn("SERIES PASS", his)

    def test_no_verdict_before_min_runs(self):
        for t in (1, 3, 6, 8, 11):
            self.put(1, t, 8.0)
        out = run(["series", "--base", self.base, "--runs", self.runs, "--lines", "yard_open/cross=xclear:guard:abs=1.0:allow=3.0"])
        self.assertIn("5/12", out)
        self.assertIn("SERIES CONTINUE", out)

    def test_round30_t3b_judged_rows(self):
        base = os.path.join(REF, "t3b_judged_base_cf124433_seeds313233.jsonl")
        arm = os.path.join(REF, "t3b_judged_arm_cf124433_seeds313233.jsonl")
        if not os.path.exists(arm):
            self.skipTest("round 30 references absent")
        with open(arm) as h:
            for i, line in enumerate(h):
                with open(os.path.join(self.runs, "r%03d.json" % i), "w") as o:
                    o.write(line)
        out = run(["series", "--base", base, "--runs", self.runs, "--lines",
                   "yard_open/cross=xclear:guard:abs=1.0:allow=3.0"])
        self.assertIn("SEQ yard_open/cross 18/18", out)
        self.assertIn("SERIES PASS", out)
        old = run(["series", "--base", base, "--runs", self.runs, "--lines", "yard_open/cross=xclear:guard:abs=0.84"])
        self.assertIn("SERIES FAIL", old)  # round 30's +10 % line (0.10 x the 8.4 s base) failed as filed


if __name__ == "__main__":
    unittest.main()
