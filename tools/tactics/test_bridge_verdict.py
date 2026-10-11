"""Known answers for his bridge drill's verdict (bridge_verdict.py), including the ruling's mutation: a crew stalled
3 s or more and then killed must FAIL the run."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import bridge_verdict  # noqa: E402


def row(crossed=4, rim_crews=0, dead=()):
    return {"crews": 4, "crossed": crossed, "rim_crews": rim_crews, "dead": list(dead), "side": "green",
            "start_tick": "1", "seed": 1}


def death(stuck_s, crossed=False):
    return {"name": "Green_S_2", "died_s": 30.0, "killer": "Rust_G_1", "crossed": crossed, "stuck_s": stuck_s,
            "speeds": [6.0, 5.5, 0.2]}


class BridgeVerdict(unittest.TestCase):
    def test_all_across_passes(self):
        self.assertTrue(bridge_verdict.verdict(row())[0])

    def test_one_short_with_nobody_dead_fails(self):
        self.assertFalse(bridge_verdict.verdict(row(crossed=3))[0])

    def test_a_crew_killed_while_driving_is_excused(self):
        passed, _, excused = bridge_verdict.verdict(row(crossed=3, dead=[death(0.4)]))
        self.assertTrue(passed)
        self.assertEqual(len(excused), 1)
        self.assertIn("Rust_G_1", excused[0])

    def test_a_crew_stalled_then_killed_fails(self):
        # The ruling's mutation: pinned in a queue for 3 s or more, then shot, is a crossing failure.
        passed, reasons, excused = bridge_verdict.verdict(row(crossed=3, dead=[death(3.0)]))
        self.assertFalse(passed)
        self.assertEqual(excused, [])
        self.assertTrue(any("died stuck" in r for r in reasons))

    def test_a_crew_killed_after_crossing_needs_no_excuse(self):
        passed, _, excused = bridge_verdict.verdict(row(crossed=4, dead=[death(5.0, crossed=True)]))
        self.assertTrue(passed)
        self.assertEqual(excused, [])

    def test_rim_crews_fail_whatever_else(self):
        self.assertFalse(bridge_verdict.verdict(row(rim_crews=1))[0])

    def test_missing_fails(self):
        self.assertFalse(bridge_verdict.verdict({"missing": True})[0])


if __name__ == "__main__":
    unittest.main()
