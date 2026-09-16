"""The variance gate reads the CLI's report and fails on the right numbers."""
from __future__ import annotations

import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path

import check_variance


def report(**values) -> Path:
    numbers = {"in_match_repeats": 0, "opener_repeat_rate": 0.0, "welcome_repeat_rate": 0.0, "carryover_rate": 0.0}
    numbers.update(values)
    path = Path(tempfile.mkdtemp()) / "variance.txt"
    path.write_text("VARIANCE 50 matches per fixture\nfixture ...\nVARIANCE_RESULT %s\n" % json.dumps(numbers))
    return path


def run(path: Path, *args: str) -> int:
    with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
        return check_variance.main([str(path), *args])


class CheckVarianceTest(unittest.TestCase):
    def test_a_quiet_report_passes(self) -> None:
        self.assertEqual(run(report(opener_repeat_rate=0.08, carryover_rate=0.2)), 0)

    def test_a_line_said_twice_in_one_match_always_fails(self) -> None:
        self.assertEqual(run(report(in_match_repeats=1)), 1)

    def test_openers_repeating_too_often_fail(self) -> None:
        self.assertEqual(run(report(opener_repeat_rate=0.11)), 1)
        self.assertEqual(run(report(opener_repeat_rate=0.11), "--max-opener", "0.2"), 0)

    def test_the_pa_repeating_her_welcome_fails(self) -> None:
        """What the lead actually noticed: the same opening announcement across matches."""
        self.assertEqual(run(report(welcome_repeat_rate=0.4)), 1)

    def test_carryover_from_the_previous_match_fails(self) -> None:
        self.assertEqual(run(report(carryover_rate=0.55)), 1)

    def test_a_report_without_the_marker_is_an_error(self) -> None:
        path = Path(tempfile.mkdtemp()) / "empty.txt"
        path.write_text("Godot Engine v4.7.2\n")
        with self.assertRaises(SystemExit):
            run(path)


if __name__ == "__main__":
    unittest.main()
