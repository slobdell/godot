#!/usr/bin/env python3
"""Round 15 (squad P1): known answers for doctrine_series.py (the gangs' verdicts over seeds)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import doctrine_series  # noqa: E402


def row(arm, seed, pack, enemy, verdict="time", drills=None):
    return {"arm": arm, "opponent": "chasers", "arena": "yard", "seed": seed, "survival": pack, "enemy_survival": enemy,
            "survival_26s": pack, "enemy_survival_26s": enemy, "verdict": verdict,
            "verdict_s": 30.0 if verdict != "time" else None, "shots": {"pack": 10, "enemy": 5},
            "drills": drills or {}}


class Summary(unittest.TestCase):
    def test_pairs_by_seed_and_counts_discordant_seeds(self):
        rows = [row("shipped", s, 0.5, 0.5) for s in (1, 2, 3)]
        rows += [row("nobait", 1, 0.6, 0.2, "pack"), row("nobait", 2, 0.6, 0.4), row("nobait", 3, 0.4, 0.9, "enemy")]
        cells = doctrine_series.summarise(rows)
        self.assertEqual(len(cells), 1)
        vs = cells[0]["arms"]["nobait"]["vs_shipped"]
        self.assertEqual((vs["pairs"], vs["enemy_lower"], vs["enemy_higher"]), (3, 2, 1))
        self.assertEqual((vs["pack_higher"], vs["pack_lower"]), (2, 1))
        arm = cells[0]["arms"]["nobait"]
        self.assertEqual((arm["won"], arm["lost"], arm["time"]), (1, 1, 1))

    def test_an_arm_whose_drill_never_ran_says_so(self):
        rows = [row("shipped", 1, 0.5, 0.5), row("encircle", 1, 0.5, 0.5, drills={"react_to_contact": {"starts": 1}})]
        arm = doctrine_series.summarise(rows)[0]["arms"]["encircle"]
        self.assertEqual(arm["encircle_ran"], 0)
        self.assertEqual(arm["vs_shipped"]["identical"], 1)

    def test_sign_test(self):
        self.assertEqual(doctrine_series.sign_p(0, 0), 1.0)
        self.assertAlmostEqual(doctrine_series.sign_p(8, 0), 2 / 256)
        self.assertEqual(doctrine_series.sign_p(4, 4), 1.0)


if __name__ == "__main__":
    unittest.main()
