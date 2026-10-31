#!/usr/bin/env python3
"""Spotter S6 on synthetic labels: when "dumb" follows one signal and the hand score is noise, the learned ranker must beat it
and lean on that signal. `make spotter-test`."""
import os
import random
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools", "spotter"))
import learn as L  # noqa: E402


class LearnTest(unittest.TestCase):
    def test_learns_the_signal_he_calls_dumb(self):
        rng = random.Random(1)
        rows = []
        for i in range(200):
            stuck = rng.random() * 4
            clip = {"surprise_max": {"noprog_s": stuck, "spread_m": rng.random() * 4}, "length_s": 5, "choice": "MOVE",
                    "score": rng.random(), "seed": i % 10}
            rows.append((clip, 1 if stuck + rng.gauss(0, 0.5) > 2 else 0))
        score, w = L.fit([L.vector(c) for c, _ in rows], [y for _, y in rows])
        ys = [y for _, y in rows]
        self.assertGreater(L.auc([score(L.vector(c)) for c, _ in rows], ys), 0.85)
        self.assertLess(abs(L.auc([c["score"] for c, _ in rows], ys) - 0.5), 0.15)
        self.assertEqual(max(range(len(w)), key=lambda j: abs(w[j])), L.NAMES.index("rare:noprog_s"))


if __name__ == "__main__":
    unittest.main()
