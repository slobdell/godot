#!/usr/bin/env python3
"""jam_ab.py (round 34, T6's bar): the paired lines read as filed."""
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import jam_ab  # noqa: E402


def death(cause, hit_in_jam=False, hits=0):
    return "JAM_DEATH " + json.dumps({"unit": "u", "team": 0, "hull": "ifv", "s": 10.0, "cause": cause, "hit_in_jam": hit_in_jam, "hits_10s": hits})


def census(on, kills=10, shots=100, hits=50, loops=2):
    return "JAM_CENSUS " + json.dumps({"underfire_on": on, "teams": {"0": {"kills": kills, "shots": shots, "hits": hits, "deaths": 1}},
                                      "route_arms": {"underfire_refusals": 3 if on else 0, "turns": {"counters": {"h1b": {"loops": loops}}}}})


def write(folder, name, lines):
    with open(os.path.join(folder, name), "w") as f:
        f.write("\n".join(lines) + "\n")


class Lines(unittest.TestCase):
    def test_gain_and_guards(self):
        with tempfile.TemporaryDirectory() as base, tempfile.TemporaryDirectory() as arm:
            for i in range(6):
                # base: 4 jam-under-fire deaths a fight; arm: 1. Open deaths equal, stuck equal, far loops equal.
                write(base, "locks-%d.log" % i, [death("jam:yielding", True)] * 4 + [death("open:driving")] * 3 + [death("stuck:wedged")] + [census(False)])
                write(arm, "locks-%d.log" % i, [death("jam:yielding", True)] + [death("open:driving")] * 3 + [death("stuck:wedged")]
                      + ["STANDOFF " + json.dumps({"pair": ["a", "b"], "lasted_s": 3.0}), "ABORT " + json.dumps({"unit": "a", "contacts_3s": 0})] + [census(True)])
            r = jam_ab.read_dirs(base, arm)
            self.assertEqual(r["n"], 6)
            g = jam_ab.paired(r["rows"]["base"]["jam_uf"], r["rows"]["arm"]["jam_uf"])
            self.assertEqual((g["base"], g["arm"], g["drop"]), (24, 6, 18))
            self.assertEqual(g["se"], 0.0)  # identical drops: the paired sd is zero
            self.assertEqual(sum(r["rows"]["arm"]["standoffs"]), 6)
            self.assertEqual(jam_ab.far_loops(json.loads(census(True)[11:])), 2)
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                jam_ab.main([base, arm])
            text = out.getvalue()
            self.assertIn("G jam-under-fire deaths (deciding gain)", text)
            self.assertIn("T6 PASS", text)
            self.assertNotIn("WARNING", text)

    def test_a_rise_fails_the_gain(self):
        with tempfile.TemporaryDirectory() as base, tempfile.TemporaryDirectory() as arm:
            for i in range(4):
                write(base, "terminus-%d.log" % i, [death("jam:friend", False, 2)] * (1 + i % 2) + [census(False)])
                write(arm, "terminus-%d.log" % i, [death("jam:friend", False, 2)] * (2 + i % 2) + [census(True)])
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                jam_ab.main([base, arm])
            self.assertIn("T6 FAIL", out.getvalue())


if __name__ == "__main__":
    unittest.main()
