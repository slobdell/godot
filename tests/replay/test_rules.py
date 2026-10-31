#!/usr/bin/env python3
"""Known answers for tests/replay/rules.py (R46.11)."""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rules  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))


def recording(header):
    handle = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False)
    handle.write(json.dumps(dict({"t": "match"}, **header)) + "\n")
    handle.close()
    return handle.name


class Rules(unittest.TestCase):
    def test_his_two_recordings_replay_without_the_lane_rule(self):
        for name in ("round45/playtest/2026-10-29T22-57-47-terminus.jsonl", "round44/playtest/2026-10-29T09-35-51-gorge.jsonl"):
            self.assertEqual(rules.decide(os.path.join(REPO, "references", name))[0], ["--lane-clear=off", "--army-cap=count"], name)

    def test_his_round46_recordings_replay_with_the_count_trim(self):
        # R47.22: played with lane_clear ON and the laptop's 20-a-side trim (no army_money stamp).
        name = "round46/playtest/2026-10-30T15-41-59-crossing.jsonl"
        self.assertEqual(rules.decide(os.path.join(REPO, "references", name))[0], ["--army-cap=count"], name)

    def test_the_stamp_decides(self):
        self.assertEqual(rules.decide(recording({"rules": {"lane_clear": True, "army_money": True}}))[0], [])
        self.assertEqual(rules.decide(recording({"rules": {"lane_clear": False, "army_money": True}}))[0], ["--lane-clear=off"])
        self.assertEqual(rules.decide(recording({"rules": {"lane_clear": True, "army_money": False}}))[0], ["--army-cap=count"])
        self.assertEqual(rules.decide(recording({"rules": {}}))[0], ["--lane-clear=off", "--army-cap=count"], "a stamp older than the rules")

    def test_his_own_flag_and_the_replays_flag_are_left_alone(self):
        self.assertEqual(rules.decide(recording({"flags": {"lane-clear": "off", "army-cap": "count"}}))[0], [])
        self.assertEqual(rules.decide(recording({}), " --lane-clear=on --army-cap=money")[0], [])


if __name__ == "__main__":
    unittest.main()
