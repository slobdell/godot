#!/usr/bin/env python3
"""Spotter S1 (round 48): labels.py splits his own taps from assumed labels (C48.4), gives precision by rank band, and the
controls' base rate. `make spotter-test` (stdlib unittest, no Godot)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools", "spotter"))
import labels as L  # noqa: E402


def clip(i, rank, control=False, signals=()):
    return {"id": f"c{i}", "order": i, "rank": rank, "control": control, "crew": f"Crew_{i}", "arena": "crossing",
            "seed": 13121, "signals": list(signals), "repro": f"make spotter-clip X={i}"}


def label(i, verdict, assumed=False):
    d = {"clip": f"c{i}", "verdict": verdict, "by": "assumed" if assumed else "u_him"}
    if assumed:
        d["assumed"] = True
    return d


class LabelsTest(unittest.TestCase):
    def setUp(self):
        self.clips = [clip(1, 31), clip(2, 45), clip(3, 60), clip(4, 80), clip(5, 99), clip(6, 120, control=True),
                      clip(7, 130, control=True), clip(8, 140, control=True)]
        self.labels = [label(1, "dumb"), label(2, "fine"), label(3, "dumb", assumed=True), label(4, "dumb"),
                       label(6, "fine"), label(7, "dumb"), label(8, "unsure")]

    def test_his_taps_exclude_assumed(self):
        s = L.summarize(self.clips, self.labels, bands=((31, 50), (51, 75), (76, 100)))
        self.assertEqual(s["his"]["flagged"], {"dumb": 2, "fine": 1, "unsure": 0, "untapped": 2})
        self.assertEqual(s["assumed"], 1)
        self.assertEqual(s["all"]["flagged"]["dumb"], 3)

    def test_bands_read_his_taps_only(self):
        s = L.summarize(self.clips, self.labels, bands=((31, 50), (51, 75), (76, 100)))
        bands = {b["band"]: b for b in s["his"]["bands"]}
        self.assertEqual((bands["31-50"]["dumb"], bands["31-50"]["decided"]), (1, 2))
        self.assertEqual(bands["51-75"]["decided"], 0)  # rank 60 is assumed, not his
        self.assertEqual((bands["76-100"]["dumb"], bands["76-100"]["decided"]), (1, 1))

    def test_controls_are_the_base_rate(self):
        s = L.summarize(self.clips, self.labels, bands=((31, 50),))
        self.assertEqual(s["his"]["controls"], {"dumb": 1, "fine": 1, "unsure": 1, "untapped": 0})
        self.assertAlmostEqual(s["his"]["base_rate"], 0.5)

    def test_no_control_taps_means_no_base_rate(self):
        s = L.summarize(self.clips, [l for l in self.labels if l["clip"] not in ("c6", "c7", "c8")], bands=((31, 50),))
        self.assertIsNone(s["his"]["base_rate"])


if __name__ == "__main__":
    unittest.main()
