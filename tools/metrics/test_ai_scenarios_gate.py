"""Known-answer tests for `ai_scenarios_gate.sh`, the ai-scenarios count gate.

They exist because **this gate has already been wrong once**. Its first baseline (`1cb2fda9`, builder0) was
recorded while `scenario_dodge_rate` happened to pass -- a scenario whose own header says it has been
KNOWN-FAILING since CP4 and whose measured pass rate is about one run in fifty. The gate would therefore have
failed `main` at random, for a behaviour everyone already knew was missing.

A baseline records whatever was true the instant it was taken, including luck. What the gate does with that
line is pure text comparison, so it can be driven here by fixture logs in milliseconds -- which is exactly
what buried it in a make recipe prevented, since running it needed Godot and a full scenario run.
"""

import subprocess
import tempfile
import unittest
from pathlib import Path

GATE = Path(__file__).resolve().parent / "ai_scenarios_gate.sh"


def summary(passed, failed, pending, unexpected, body=""):
    return (
        f"{body}\nscenarios: {passed} passed, {failed} failed, "
        f"{pending} pending, {unexpected} unexpectedly passing\n"
    )


def baseline(counts, machine="builder0", commit="1cb2fda9"):
    return f"# ai-scenarios counts\n# machine: {machine}\n# commit:  {commit}\n{counts}\n"


class GateCase(unittest.TestCase):
    def run_gate(self, log_text, baseline_text, mode="check"):
        with tempfile.TemporaryDirectory() as d:
            log = Path(d) / "ai-scenarios.log"
            base = Path(d) / "baseline.txt"
            log.write_text(log_text)
            base.write_text(baseline_text)
            proc = subprocess.run(
                ["bash", str(GATE), mode, str(log), str(base)],
                capture_output=True, text=True,
            )
            return proc.returncode, proc.stdout + proc.stderr


class TestTheGatedCounts(GateCase):
    def test_identical_counts_pass(self):
        rc, out = self.run_gate(summary(42, 2, 3, 0), baseline("42,2,3,0"))
        self.assertEqual(rc, 0, out)
        self.assertIn("unchanged", out)

    def test_a_new_failure_fails_the_gate(self):
        """The whole point (lesson 159): a script error moves `failed` and must be caught."""
        rc, out = self.run_gate(summary(41, 3, 3, 0), baseline("42,2,3,0"))
        self.assertEqual(rc, 1, out)
        self.assertIn("non-pending counts CHANGED", out)

    def test_a_new_pass_also_fails_the_gate(self):
        """Counts, not outcomes: a scenario appearing or being fixed is a change worth recording."""
        rc, out = self.run_gate(summary(43, 1, 3, 0), baseline("42,2,3,0"))
        self.assertEqual(rc, 1, out)

    def test_the_failure_names_the_baselines_commit_and_machine(self):
        """A count that disagrees is useless without knowing what it was taken on (CLAUDE.md rule 4)."""
        rc, out = self.run_gate(
            summary(41, 3, 3, 0), baseline("42,2,3,0", machine="builder0", commit="1cb2fda9")
        )
        self.assertEqual(rc, 1, out)
        self.assertIn("1cb2fda9", out)
        self.assertIn("builder0", out)

    def test_the_failure_lists_which_scenarios_failed(self):
        body = "  FAIL  scenario_suppression::test_holding_the_aim_point (0.7s)"
        rc, out = self.run_gate(summary(41, 3, 3, 0, body), baseline("42,2,3,0"))
        self.assertEqual(rc, 1, out)
        self.assertIn("scenario_suppression", out)


class TestPendingIsReportedNeverGated(GateCase):
    """The defect this gate shipped with: a known-failing scenario's 2% pass became the expectation."""

    def test_a_pending_scenario_passing_by_luck_does_not_fail_the_gate(self):
        # dodge_rate flips from PENDING-failing to unexpectedly-passing: 3,0 -> 2,1.
        rc, out = self.run_gate(summary(42, 2, 2, 1), baseline("42,2,3,0"))
        self.assertEqual(rc, 0, out)

    def test_but_it_is_not_silent(self):
        """Not gated is not the same as not reported: a pending behaviour that works is news."""
        rc, out = self.run_gate(summary(42, 2, 2, 1), baseline("42,2,3,0"))
        self.assertIn("3,0 -> 2,1", out)
        self.assertIn("PROMOTED", out)

    def test_the_note_names_the_scenario_that_started_passing(self):
        body = "  UNEXPECTED PASS  scenario_dodge_rate::test_who_dodges_and_how_often_they_try (38.7s)"
        rc, out = self.run_gate(summary(42, 2, 2, 1, body), baseline("42,2,3,0"))
        self.assertEqual(rc, 0, out)
        self.assertIn("scenario_dodge_rate", out)

    def test_a_pending_scenario_going_back_to_failing_does_not_fail_the_gate_either(self):
        rc, out = self.run_gate(summary(42, 2, 3, 0), baseline("42,2,2,1"))
        self.assertEqual(rc, 0, out)
        self.assertIn("2,1 -> 3,0", out)

    def test_a_real_regression_still_fails_while_pending_churns(self):
        """Both at once: the pending flip must not mask the failure beside it."""
        rc, out = self.run_gate(summary(41, 3, 2, 1), baseline("42,2,3,0"))
        self.assertEqual(rc, 1, out)
        self.assertIn("non-pending counts CHANGED", out)


class TestAbsenceIsNotAMeasurement(GateCase):
    """A crashed run must never read as `nothing changed` -- the recurring defect of this round."""

    def test_no_summary_line_fails(self):
        rc, out = self.run_gate("Godot crashed\nSEGV\n", baseline("42,2,3,0"))
        self.assertEqual(rc, 1, out)
        self.assertIn("no summary line", out)

    def test_no_summary_line_shows_the_tail_of_the_log(self):
        rc, out = self.run_gate("Godot crashed\nthe last thing it said\n", baseline("42,2,3,0"))
        self.assertIn("the last thing it said", out)

    def test_an_empty_log_fails_rather_than_passing_vacuously(self):
        rc, out = self.run_gate("", baseline("42,2,3,0"))
        self.assertEqual(rc, 1, out)

    def test_an_empty_baseline_fails_and_says_how_to_record_one(self):
        rc, out = self.run_gate(summary(42, 2, 3, 0), "# only comments\n")
        self.assertEqual(rc, 1, out)
        self.assertIn("ai-scenarios-record", out)

    def test_the_last_summary_line_wins(self):
        """A re-run appends; the gate must read the run it just did, not the first one in the file."""
        two = summary(1, 1, 1, 1) + summary(42, 2, 3, 0)
        rc, out = self.run_gate(two, baseline("42,2,3,0"))
        self.assertEqual(rc, 0, out)


class TestRecordNeedsAReason(GateCase):
    """`45,0,2,0` was a 2% coin and the file did not say what had been true when it was taken."""

    def _record(self, reason=None, out_name="out.txt"):
        import os as _os
        with tempfile.TemporaryDirectory() as d:
            log = Path(d) / "log"
            out_file = Path(d) / out_name
            log.write_text(summary(43, 1, 3, 0))
            env = dict(_os.environ)
            env.pop("AI_SCENARIOS_REASON", None)
            if reason is not None:
                env["AI_SCENARIOS_REASON"] = reason
            proc = subprocess.run(["bash", str(GATE), "record", str(log), str(out_file)],
                                  capture_output=True, text=True, env=env)
            return proc, out_file.read_text() if out_file.exists() else None

    def test_no_reason_is_refused(self):
        proc, written = self._record()
        self.assertEqual(proc.returncode, 2, proc.stdout + proc.stderr)
        self.assertIn("no reason", proc.stdout + proc.stderr)

    def test_a_refused_record_writes_nothing(self):
        """`{ ... } > file` truncates before the first echo, so the check has to come earlier."""
        proc, written = self._record()
        self.assertIsNone(written, "a refused record must not leave a file behind")

    def test_the_refusal_shows_the_counts_it_would_have_written(self):
        proc, _ = self._record()
        self.assertIn("43,1,3,0", proc.stdout + proc.stderr)

    def test_a_reason_is_written_into_the_file(self):
        proc, written = self._record(reason="suppression bar became a separation (combat 364d77f2)")
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertIn("# reason:  suppression bar became a separation (combat 364d77f2)", written)

    def test_the_recorded_file_is_still_accepted_by_check(self):
        import os as _os
        with tempfile.TemporaryDirectory() as d:
            log = Path(d) / "log"
            out_file = Path(d) / "out.txt"
            log.write_text(summary(43, 1, 3, 0))
            env = dict(_os.environ, AI_SCENARIOS_REASON="because")
            subprocess.run(["bash", str(GATE), "record", str(log), str(out_file)],
                           capture_output=True, text=True, env=env, check=True)
            proc = subprocess.run(["bash", str(GATE), "check", str(log), str(out_file)],
                                  capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)


class TestRecord(GateCase):
    def test_record_writes_the_counts_and_the_provenance(self):
        with tempfile.TemporaryDirectory() as d:
            log = Path(d) / "log"
            out_file = Path(d) / "out.txt"
            log.write_text(summary(42, 2, 3, 0))
            import os as _os
            proc = subprocess.run(
                ["bash", str(GATE), "record", str(log), str(out_file), "deadbeef"],
                capture_output=True, text=True, env=dict(_os.environ, AI_SCENARIOS_REASON="a reason"),
            )
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            written = out_file.read_text()
            self.assertIn("42,2,3,0", written)
            self.assertIn("deadbeef", written)
            self.assertIn("# machine:", written)
            self.assertIn("ONLY THE FIRST TWO ARE GATED", written)

    def test_a_recorded_baseline_is_accepted_by_check(self):
        """Round-trip: record then check must agree, or the gate fights its own recorder."""
        with tempfile.TemporaryDirectory() as d:
            log = Path(d) / "log"
            out_file = Path(d) / "out.txt"
            log.write_text(summary(42, 2, 3, 0))
            import os as _os
            subprocess.run(["bash", str(GATE), "record", str(log), str(out_file)],
                           capture_output=True, text=True, check=True,
                           env=dict(_os.environ, AI_SCENARIOS_REASON="a reason"))
            proc = subprocess.run(["bash", str(GATE), "check", str(log), str(out_file)],
                                  capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

    def test_record_refuses_a_log_with_no_summary(self):
        with tempfile.TemporaryDirectory() as d:
            log = Path(d) / "log"
            out_file = Path(d) / "out.txt"
            log.write_text("crashed\n")
            import os as _os
            proc = subprocess.run(["bash", str(GATE), "record", str(log), str(out_file)],
                                  capture_output=True, text=True,
                                  env=dict(_os.environ, AI_SCENARIOS_REASON="a reason"))
            self.assertEqual(proc.returncode, 1)
            self.assertFalse(out_file.exists(), "a refused record must not write a file")


class TestUsage(unittest.TestCase):
    def test_missing_arguments_are_refused_not_guessed(self):
        proc = subprocess.run(["bash", str(GATE)], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 2)

    def test_the_script_is_executable_and_parses(self):
        proc = subprocess.run(["bash", "-n", str(GATE)], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)


if __name__ == "__main__":
    unittest.main()
