#!/usr/bin/env python3
"""series_verdict.py's own tests (round 33 overnight, planner item 1): the both-arms-seam mode. Round 33's P2 and P3 ran
the seam in BOTH arms (the switch under test was the queue or the keep, not the seam), so the round-31 guard "the BASE
arm's seam fired" refused and the Terminus line was read by hand. `seam=both` declares that, judges the arrivals as
usual, and reports the base arm's seam beside the candidate's. Run: make planner-pytest
"""
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import series_verdict  # noqa: E402

SEEDS = range(1, 7)   # the verdict never judges under 6 seeds


def write_run(directory, squad, seed, arrived, contacts, seam=None):
    lines = ['NAV_DRIVE_LEG {"arrived": %d, "units": 4, "seconds": 30.0}' % arrived,
             'NAV_DRIVE {"wall_contacts": {"contact_unit_ticks": %d}, "cusps": 0}' % contacts]
    if seam is not None:
        lines.append("PLANNER_SEAM_REPORT " + json.dumps(seam))
    with open(os.path.join(directory, "%s-%d.log" % (squad, seed)), "w") as f:
        f.write("\n".join(lines) + "\n")


def seam(requests, holds=(3, 5)):
    return {"requests": requests, "plans": requests, "driven": 1, "aborted": 0, "abandoned": 0, "rerequested": 0,
            "queue_waits": 0, "pending_ticks": sum(holds), "refused": {}, "holds": {"n": len(holds), "median": 4,
            "max": max(holds)}, "hold_ticks": list(holds)}


class SeriesVerdict(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = os.path.join(self.tmp.name, "base")
        self.cand = os.path.join(self.tmp.name, "candidate")
        os.makedirs(self.base)
        os.makedirs(self.cand)

    def tearDown(self):
        self.tmp.cleanup()

    def run_verdict(self, *extra):
        out = io.StringIO()
        with redirect_stdout(out):
            code = series_verdict.main(["base=" + self.base, "candidate=" + self.cand, *extra])
        return code, out.getvalue()

    def both_arms(self, base_requests=2):
        for seed in SEEDS:
            write_run(self.base, "rigs", seed, 3, 100, seam(base_requests))
            write_run(self.cand, "rigs", seed, 3, 90, seam(4))

    def test_the_default_still_refuses_a_base_whose_seam_fired(self):
        self.both_arms()
        code, out = self.run_verdict()
        self.assertEqual(code, 2)
        self.assertIn("REFUSED: the BASE arm's seam fired", out)

    def test_seam_both_judges_the_arrivals_and_reports_both_seams(self):
        self.both_arms()
        code, out = self.run_verdict("seam=both")
        self.assertEqual(code, 0, out)
        self.assertIn("PLANNER_SERIES_SQUAD rigs: n 6 | arrivals base 18 candidate 18", out)
        self.assertIn("-> PASS", out)
        base_total = [l for l in out.splitlines() if l.startswith("PLANNER_SERIES_SEAM_BASE_TOTAL ")]
        self.assertEqual(len(base_total), 1, out)
        self.assertEqual(json.loads(base_total[0].split(" ", 1)[1])["requests"], 12)
        cand_total = [l for l in out.splitlines() if l.startswith("PLANNER_SERIES_SEAM_TOTAL ")]
        self.assertEqual(json.loads(cand_total[0].split(" ", 1)[1])["requests"], 24)
        verdict = json.loads([l for l in out.splitlines() if l.startswith("PLANNER_SERIES ")][0].split(" ", 1)[1])
        self.assertEqual(verdict["seam_mode"], "both")
        self.assertEqual(verdict["base_seam"]["requests"], 12)

    def test_seam_both_refuses_when_the_base_seam_never_fired(self):
        # Declaring both arms on the seam when the base never asked it means the flags did not reach the base.
        self.both_arms(base_requests=0)
        code, out = self.run_verdict("seam=both")
        self.assertEqual(code, 2)
        self.assertIn("REFUSED: seam=both but the BASE arm's seam never fired", out)

    def test_a_miss_still_reads_miss_under_seam_both(self):
        for seed in SEEDS:
            write_run(self.base, "rigs", seed, 4, 100, seam(2))
            write_run(self.cand, "rigs", seed, 4 - (seed % 2) - 1, 90, seam(4))
        code, out = self.run_verdict("seam=both")
        self.assertEqual(code, 0, out)
        self.assertIn("-> MISS", out)


if __name__ == "__main__":
    unittest.main()
