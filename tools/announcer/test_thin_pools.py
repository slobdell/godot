"""thin_pools.py: an evening's cues grouped by the pool each line came from (round 16, booth B1)."""

import unittest

import thin_pools

LINES = [
    {"id": "caller.kill.a", "speaker": "caller", "act": "call", "tags": ["kill", "flurry"], "text": "A"},
    {"id": "caller.kill.b", "speaker": "caller", "act": "call", "tags": ["flurry", "kill"], "text": "B"},
    {"id": "caller.kill.c", "speaker": "caller", "act": "call", "tags": ["kill"], "text": "C"},
]


def cue(match, minute, line, tags):
    return {"match": match, "minute": minute, "length_min": 2.0, "speaker": "caller", "act": "call", "line": line,
            "line_tags": tags, "pool": {"fresh": 2, "effective": 1.5}}


class ThinPoolsTest(unittest.TestCase):
    def test_tag_order_does_not_split_a_pool(self):
        pools = thin_pools.library_pools(LINES)
        self.assertEqual(len(pools["caller call [flurry,kill]"]), 2)

    def test_repeat_inside_the_window_and_the_first_repeat(self):
        rows = [cue(0, 0.5, "caller.kill.a", ["kill", "flurry"]),
                cue(1, 1.0, "caller.kill.b", ["kill", "flurry"]),
                cue(2, 1.5, "caller.kill.a", ["kill", "flurry"]),
                cue(9, 0.1, "caller.kill.a", ["kill", "flurry"])]
        result = {r["pool"]: r for r in thin_pools.analyse(rows, LINES)}
        flurry = result["caller call [flurry,kill]"]
        self.assertEqual(flurry["lines"], 2)
        self.assertAlmostEqual(flurry["calls_per_match"], 0.4)
        # Match 2 repeats match 0 inside the window; match 9 is six matches after match 2, outside it.
        self.assertAlmostEqual(flurry["again5"], 0.25)
        self.assertEqual(flurry["first_repeat"], {"match": 3, "minutes": 5.5, "line": "caller.kill.a"})
        self.assertEqual(flurry["need5"], 2)

    def test_his_history_counts_distinct_lines_per_match(self):
        rows = [cue(0, 0.5, "caller.kill.c", ["kill"])]
        history = [["caller.kill.a", "caller.kill.b"], ["caller.kill.a"]]
        result = {r["pool"]: r for r in thin_pools.analyse(rows, LINES, history)}
        self.assertEqual(result["caller call [kill]"]["his_per_match"], None)
        self.assertEqual(result["caller call [kill]"]["his_heard"], 0)
        # The flurry pool was never called tonight, so it is not a row; his history alone does not invent one.
        self.assertNotIn("caller call [flurry,kill]", result)


if __name__ == "__main__":
    unittest.main()
