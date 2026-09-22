"""The pool report's arithmetic: the C9 formula, the targets, and which lines count towards which pool."""

import math
import unittest

import pool_report


def line(id_, speaker, act, tags, text="words here"):
    return {"id": id_, "speaker": speaker, "act": act, "tags": tags, "text": text}


BEATS = {"moments": {
    "kill": {"cooldown_s": 0, "beats": [{"steps": [{"speaker": "caller", "act": "call"},
                                                   {"speaker": "color", "act": ["analysis", "roast"]}]}]},
    "lull": {"cooldown_s": 4, "beats": [{"steps": [{"speaker": "pa", "act": "notice"}]}]},
}}


class PoolReportTest(unittest.TestCase):
    def test_n_c_matches_the_formula(self):
        # 2 per minute, a 30 s cooldown, a 2-minute horizon, R = 0.05.
        expected = math.ceil(2 * 0.5) + math.ceil(2 * 2 / -math.log(0.95))
        self.assertEqual(pool_report.n_c(2.0, 0.5, 2.0), expected)
        self.assertEqual(pool_report.n_c(0.0, 0.5, 2.0), 0, "a moment that never fires needs nothing")

    def test_target_floor_cap_and_deep_growth(self):
        self.assertEqual(pool_report.target("caller", 3, 5), 12, "the brief's floor wins over a small N_c")
        self.assertEqual(pool_report.target("caller", 3, 500), 40, "N_c is capped")
        self.assertEqual(pool_report.target("pa", 3, 500), 24, "the PA's cap is lower")
        self.assertEqual(pool_report.target("color", 20, 0), 25, "a deep pool grows by a quarter")
        self.assertEqual(pool_report.target("color", 20, 0, used=False), 12, "not when nobody hears it")

    def test_static_pools_follow_kind_tags_and_beat_acts(self):
        lines = [line("a", "caller", "call", ["kill"]), line("b", "caller", "call", ["kill", "first_blood"]),
                 line("c", "color", "roast", ["kill"]), line("d", "pa", "notice", ["kill"]),
                 line("e", "pa", "notice", ["lull"]), line("f", "caller", "interrupt", ["any"])]
        pools = pool_report.static_pools(lines, BEATS)
        self.assertEqual([l["id"] for l in pools[("caller", "kill")]], ["a", "b"])
        self.assertEqual([l["id"] for l in pools[("color", "kill")]], ["c"])
        self.assertNotIn(("pa", "kill"), pools, "no kill beat asks the PA for anything")
        self.assertEqual([l["id"] for l in pools[("pa", "lull")]], ["e"])

    def test_distinct_2(self):
        self.assertEqual(pool_report.distinct_2(["one two three", "four five six"]), 1.0)
        self.assertLess(pool_report.distinct_2(["and he is down", "and he is out"]), 0.7)

    def test_build_reads_cues_and_starvation(self):
        lines = [line("a", "caller", "call", ["kill"]), line("b", "caller", "call", ["kill"])]
        run = {"events": [{"t": 0.0}, {"t": 60.0, "duration_seconds": 60.0}],
               "cues": [{"speaker": "caller", "moment": "kill", "line_id": "a",
                         "pool": {"pool": 2, "fresh": 2, "effective": 2.0}}],
               "decisions": [{"t": 5.0, "text": "skip kill (green tank): no unused caller line for call"}]}
        report = pool_report.build({"lines": lines}, BEATS, [run])
        row = next(r for r in report["rows"] if (r["speaker"], r["moment"]) == ("caller", "kill"))
        self.assertEqual(row["uses"], 1)
        self.assertAlmostEqual(row["rate_per_min"], 1.0)
        self.assertEqual(row["starved"], 1)
        self.assertEqual(row["lines"], 2)
        # One call a minute over the caller's 2-minute horizon: N_c = ⌈2 / −ln 0.95⌉ = 39, two lines in hand.
        self.assertEqual(row["n_c"], 39)
        self.assertEqual(row["deficit"], 37)


if __name__ == "__main__":
    unittest.main()
