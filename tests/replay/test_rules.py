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


ALL_OFF = ["--lane-clear=off", "--group-veto=off", "--traffic-off=shortfwd", "--traffic-off=holdway"]
ROUND46 = ("crossing", "locks", "sumps", "parade")


class Rules(unittest.TestCase):
    def test_his_older_recordings_replay_without_round_46s_rules(self):
        for name in ("round45/playtest/2026-10-29T22-57-47-terminus.jsonl", "round44/playtest/2026-10-29T09-35-51-gorge.jsonl"):
            self.assertEqual(rules.decide(os.path.join(REPO, "references", name))[0], ALL_OFF, name)

    def test_his_round46_recordings_ran_every_rule_on(self):
        # Round 47 (N0): stamped lane_clear only, recorded after the other three reached main: no flag.
        folder = os.path.join(REPO, "references", "round46", "playtest")
        names = [n for n in sorted(os.listdir(folder)) if n.endswith(".jsonl")]
        self.assertEqual(len(names), 4)
        for name in names:
            self.assertEqual(rules.decide(os.path.join(folder, name))[0], [], name)

    def test_the_stamp_decides(self):
        on = {"lane_clear": True, "group_veto": True, "shortfwd": True, "holdway": True}
        self.assertEqual(rules.decide(recording({"rules": on}))[0], [])
        self.assertEqual(rules.decide(recording({"rules": dict(on, holdway=False)}))[0], ["--traffic-off=holdway"], "the web build")
        self.assertEqual(rules.decide(recording({"rules": {"lane_clear": False}}))[0], ALL_OFF, "undated: off")
        self.assertEqual(rules.decide(recording({"rules": {}}))[0], ALL_OFF, "a stamp older than the rules")

    def test_a_dated_recording_without_an_entry(self):
        before = recording({"path": "build/recordings/2026-10-30T07-00-00-gorge.jsonl", "rules": {"lane_clear": True}})
        self.assertEqual(rules.decide(before)[0], ["--traffic-off=shortfwd", "--traffic-off=holdway"])

    def test_his_own_flag_and_the_replays_flag_are_left_alone(self):
        self.assertEqual(rules.decide(recording({"flags": {"lane-clear": "off"}}))[0], ALL_OFF[1:])
        self.assertEqual(rules.decide(recording({"flags": {"traffic-off": "holdway,backout"}}))[0], ALL_OFF[:3])
        self.assertEqual(rules.decide(recording({}), " --lane-clear=on --traffic-on=shortfwd")[0],
                         ["--group-veto=off", "--traffic-off=holdway"])


if __name__ == "__main__":
    unittest.main()
