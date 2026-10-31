#!/usr/bin/env python3
"""Spotter S1/S2 on a synthetic fight: a crew wedged for 10 s among crews driving normally must be the top moment, start when its
wedge began, and say why in words. `make spotter-test` (stdlib unittest, no Godot)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools", "spotter"))
import features as F  # noqa: E402
import rank as R  # noqa: E402

HEADER = {"t": "fight", "seed": 13121, "arena": "terminus"}


def crew_rows(name, seconds, wedged=()):
    rows = []
    to_go = 200.0
    for s in range(1, seconds + 1):
        stuck = s in wedged
        if not stuck:
            to_go -= 6.0
        rows.append({"t": "crew", "tick": s * 30, "s": s, "crew": name, "team": 0, "unit": "gang_tank", "squad": "Guns",
                     "x": 0.0, "z": float(s), "yaw": 0.0, "speed": 0.1 if stuck else 6.0, "move": "move_to", "to_go": to_go,
                     "gain_5": 0.0 if stuck else 30.0, "touch": stuck, "touch_cause": "wall" if stuck else "",
                     "range": 50.0, "near_enemy": -1.0, "shots": 0, "since_fire": 0, "hit_dmg": 0.0})
    return rows


class RankTest(unittest.TestCase):
    def setUp(self):
        rows = []
        for i in range(12):
            rows += crew_rows(f"Green_Guns_{i}", 60)
        rows += crew_rows("Green_Guns_Wedged", 60, wedged=range(20, 30))
        self.table = F.derive(HEADER, rows, "terminus-13121")

    def test_the_wedged_crew_is_the_top_moment(self):
        R.score_rows(self.table, R.build_tails(self.table))
        top = R.pick(R.moments(self.table), 5)
        self.assertTrue(top, "no moments")
        self.assertEqual(top[0]["crew"], "Green_Guns_Wedged")
        self.assertEqual(top[0]["start_s"], 20)  # the wedge began at 20 s, before it got rare
        self.assertEqual(top[0]["end_s"], 29)
        words = [r["words"] for r in top[0]["reasons"]]
        self.assertIn("pressed against a wall or prop", words)
        self.assertIn("no progress toward its goal", words)
        self.assertIn("SPOT_SEED=13121", R.repro(top[0]))

    def test_ordinary_driving_scores_nothing(self):
        normal = [r for r in self.table if r["crew"] != "Green_Guns_Wedged"]
        for key in F.SIGNALS:
            self.assertTrue(all(float(r[key]) == 0.0 for r in normal), key)

    def test_tail_surprise(self):
        tail = R.Tail([0.0] * 99 + [5.0])
        self.assertEqual(tail.surprise(0.0), 0.0)
        self.assertAlmostEqual(tail.surprise(5.0), 2.0)

    def test_a_signal_under_its_minimum_reads_zero(self):
        rows = crew_rows("Brush", 10, wedged=[5])  # one second against a wall is a brush
        table = F.derive(HEADER, rows, "f")
        self.assertTrue(all(r["wall_s"] == 0.0 for r in table))


if __name__ == "__main__":
    unittest.main()
