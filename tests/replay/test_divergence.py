#!/usr/bin/env python3
"""Known answers for tests/replay/divergence.py's end-of-match rule (round 46)."""
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import divergence  # noqa: E402


def rec(rows):
    handle = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False)
    for r in rows:
        handle.write(json.dumps(r) + "\n")
    handle.close()
    return handle.name


def match(end_tick, hash_, drift_after):
    rows = [{"t": "match", "tick_rate": 30, "units": [{"name": "Green_A_1", "team": 0}]}]
    for s in range(1, 6):
        x = 0.0 if s <= drift_after else 10.0 * s
        rows.append({"t": "census", "tick": 30 * s, "units": [{"n": "Green_A_1", "pos": [x, 0.0]}]})
        if end_tick is not None and 30 * s == end_tick:
            rows.append({"t": "end", "tick": end_tick, "result": {"state_hash": hash_}})
    return rows


def run(his, rep):
    out = io.StringIO()
    with redirect_stdout(out):
        code = divergence.main([rec(his), rec(rep), "--seconds=5", "--crews=all"])
    return code, out.getvalue()


class End(unittest.TestCase):
    def test_after_his_match_ended_nothing_is_judged(self):
        code, out = run(match(90, "h", 5), match(90, "h", 3))  # the replay drifts after the end at 3 s
        self.assertEqual(code, 0, out)
        self.assertIn("END his=90 replay=90 state_hash=same", out)

    def test_a_different_end_fails(self):
        self.assertEqual(run(match(90, "h", 5), match(90, "x", 5))[0], 1)
        self.assertEqual(run(match(90, "h", 5), match(120, "h", 5))[0], 1)

    def test_no_end_row_judges_every_second_as_before(self):
        self.assertEqual(run(match(None, None, 5), match(None, None, 3))[0], 1)


if __name__ == "__main__":
    unittest.main()
