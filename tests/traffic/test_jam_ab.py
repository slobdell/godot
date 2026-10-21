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
            self.assertIn("T6/T7 PASS", text)
            self.assertNotIn("WARNING", text)

    def test_a_rise_fails_the_gain(self):
        with tempfile.TemporaryDirectory() as base, tempfile.TemporaryDirectory() as arm:
            for i in range(4):
                write(base, "terminus-%d.log" % i, [death("jam:friend", False, 2)] * (1 + i % 2) + [census(False)])
                write(arm, "terminus-%d.log" % i, [death("jam:friend", False, 2)] * (2 + i % 2) + [census(True)])
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                jam_ab.main([base, arm])
            self.assertIn("T6/T7 FAIL", out.getvalue())


def census_t8(on, held=0, released=0, holds=10, deaths=(3, 3), contacts=50):
    """T8's census (R35.7): the held deaths, the hold's report (Traffic.report) and each team's deaths."""
    return "JAM_CENSUS " + json.dumps({"holdfire_on": on, "held_deaths": held, "friendly_contacts": contacts,
                                      "teams": {"0": {"kills": 3, "shots": 100, "hits": 50, "deaths": deaths[0]},
                                                "1": {"kills": 3, "shots": 100, "hits": 50, "deaths": deaths[1]}},
                                      "traffic": {"tr_holds": holds, "tr_hold_ticks": 300, "tr_released_fire": released},
                                      "route_arms": {"turns": {"counters": {"h1b": {"loops": 1}}}}})


class T8Lines(unittest.TestCase):
    def run_t8(self, base_rows, arm_rows):
        with tempfile.TemporaryDirectory() as base, tempfile.TemporaryDirectory() as arm:
            for i, (b, a) in enumerate(zip(base_rows, arm_rows)):
                write(base, "locks-%d.log" % (1800 + i), b)
                write(arm, "locks-%d.log" % (1800 + i), a)
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                jam_ab.main([base, arm, "--bar", "t8"])
            return out.getvalue()

    def test_held_deaths_fall_and_every_guard_holds(self):
        stuck = [death("stuck:wedged")] * 2
        text = self.run_t8([stuck + [census_t8(False, held=3 + i % 2)] for i in range(6)],
                           [stuck + [census_t8(True, held=1, released=2)] for i in range(6)])
        self.assertIn("0 released_fire (counter first): base 0 arm 12: PASS", text)
        self.assertIn("G held deaths (deciding gain)", text)
        self.assertIn("8 the hold still taken, tr_holds", text)
        self.assertIn("9 all deaths, team 0 (guard)", text)
        self.assertIn("9 all deaths, team 1 (guard)", text)
        self.assertIn("R hold seconds (crew-seconds held)", text)
        self.assertIn("T8 PASS", text)
        self.assertNotIn("WARNING", text)

    def test_no_release_fails_before_any_guard(self):
        text = self.run_t8([[census_t8(False, held=3)]] * 4, [[census_t8(True, held=1)]] * 4)
        self.assertIn("0 released_fire (counter first): base 0 arm 0: FAIL", text)
        self.assertIn("T8 FAIL", text)

    def test_deaths_moved_to_one_team_fail_the_team_guard(self):
        text = self.run_t8([[census_t8(False, held=3 + i % 2, deaths=(3, 3))] for i in range(6)],
                           [[census_t8(True, held=1, released=1, deaths=(5 + i % 2, 3))] for i in range(6)])
        self.assertRegex(text, r"9 all deaths, team 0 \(guard\).*FAIL")
        self.assertIn("T8 FAIL", text)

    def test_the_hold_switched_off_by_the_back_door_fails(self):
        text = self.run_t8([[census_t8(False, held=3 + i % 2, holds=10)] for i in range(6)],
                           [[census_t8(True, held=1, released=1, holds=4)] for i in range(6)])
        self.assertRegex(text, r"8 the hold still taken.*FAIL")

    def test_arms_named_by_holdfire(self):
        text = self.run_t8([[census_t8(True, held=3)]] * 2, [[census_t8(True, held=1, released=1)]] * 2)
        self.assertIn("WARNING", text)


if __name__ == "__main__":
    unittest.main()
