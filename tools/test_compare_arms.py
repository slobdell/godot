#!/usr/bin/env python3
"""Tests for tools/compare_arms.py (`make match-pytest`, part of `make faction-matrix` work).

These exist for the reason arena's report tests exist: the thing under test is an INSTRUMENT, and an instrument's
bugs arrive disguised as results. Every refusal below is a comparison this project has actually made or was one
command away from making -- a filtered arm against a full one, a laptop arm against a builder0 one, and a control
that differed from its treatment only in the name of its file.

The last case is the one worth the file. Two runs with identical arms produce a clean, plausible null: the answer
you were hoping for, reached by the treatment never happening. Nobody finds that by reading the output.
"""
import copy
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compare_arms

BASE = {
    "run": {"commit": "2cf61f57", "machine": "builder0", "dirty": False},
    "args": {"arena": "boulevard", "budget": 5200, "seeds": 5, "time_limit": 150,
             "factions": "gangs,condemned,law,syndicate", "no_faction_directives": False, "json": "a.json"},
    "rows": [{"faction": "gangs", "versus": "law", "win_rate": 0.8, "matches": 10},
             {"faction": "gangs", "versus": "syndicate", "win_rate": 0.6, "matches": 10},
             {"faction": "law", "versus": "syndicate", "win_rate": 0.5, "matches": 10}],
    "failures": [],
}


def arm(**over):
    data = copy.deepcopy(BASE)
    for key, value in over.items():
        (data["run"] if key in ("commit", "machine", "dirty") else data["args"])[key] = value
    return data


class WinRates(unittest.TestCase):
    def test_a_faction_is_counted_from_both_sides_of_every_pairing(self):
        # gangs won 8 of 10 against law and 6 of 10 against the syndicate: 14 of 20. law appears only as the
        # LOSING side of its pairing with the gangs and as the first side against the syndicate: 2 + 5 of 20.
        totals = compare_arms.win_rates(BASE)
        self.assertEqual(totals["gangs"], (14.0, 20))
        self.assertEqual(totals["law"], (7.0, 20))
        self.assertEqual(totals["syndicate"], (9.0, 20))


class Refusals(unittest.TestCase):
    def check(self, treatment, control, paths=("t.json", "c.json")):
        return compare_arms.refusals(treatment, control, paths)

    def test_a_real_comparison_is_allowed(self):
        self.assertEqual(self.check(arm(), arm(no_faction_directives=True)), [])

    def test_identical_arms_are_one_arm_run_twice(self):
        problems = self.check(arm(), arm())
        self.assertTrue(any("IDENTICAL ARMS" in p for p in problems), problems)

    def test_a_different_machine_is_a_different_game(self):
        problems = self.check(arm(), arm(no_faction_directives=True, machine="flightdeck"))
        self.assertTrue(any("run.machine" in p for p in problems), problems)

    def test_a_different_commit_is_a_different_game(self):
        problems = self.check(arm(), arm(no_faction_directives=True, commit="deadbeef"))
        self.assertTrue(any("run.commit" in p for p in problems), problems)

    def test_a_different_map_is_a_different_question(self):
        problems = self.check(arm(), arm(no_faction_directives=True, arena="yard"))
        self.assertTrue(any("args.arena" in p for p in problems), problems)

    def test_a_different_sample_size_is_a_different_question(self):
        problems = self.check(arm(), arm(no_faction_directives=True, seeds=3))
        self.assertTrue(any("args.seeds" in p for p in problems), problems)

    def test_a_dirty_tree_cannot_identify_what_ran(self):
        problems = self.check(arm(), arm(no_faction_directives=True, dirty=True))
        self.assertTrue(any("DIRTY" in p for p in problems), problems)

    def test_the_same_file_twice_is_a_zero_that_reads_as_no_effect(self):
        problems = self.check(arm(), arm(no_faction_directives=True), ("same.json", "same.json"))
        self.assertEqual(len(problems), 1, "it short-circuits: nothing else is worth saying")
        self.assertIn("same file twice", problems[0])

    def test_the_output_path_is_allowed_to_differ(self):
        # `json` is the one args field that is SUPPOSED to differ between two arms. Requiring it to match would
        # refuse every correct comparison -- a guard that fires on the good case is worse than no guard, because
        # it teaches its user to ignore it.
        self.assertEqual(self.check(arm(json="x.json"), arm(no_faction_directives=True, json="y.json")), [])


class BuildIsTheArm(unittest.TestCase):
    """Sizing a vehicle cannot be put behind a runner flag, so without this the tool refuses the one comparison it
    exists to make. Declaring it must SWAP which guard applies, never remove one."""

    def check(self, treatment, control, declared):
        return compare_arms.refusals(treatment, control, ("t.json", "c.json"), declared)

    def test_a_declared_build_arm_allows_the_commits_to_differ(self):
        self.assertEqual(self.check(arm(commit="aaaa1111"), arm(commit="bbbb2222"), "gang_tank 5.6 m -> 14 m"), [])

    def test_and_then_REQUIRES_them_to_differ(self):
        # The teeth. If the build is the arm and both runs are the same build, it is one arm run twice -- the
        # clean-null failure, wearing the costume of a legitimate code-level treatment.
        problems = self.check(arm(), arm(), "gang_tank 5.6 m -> 14 m")
        self.assertTrue(any("one arm run twice" in p for p in problems), problems)

    def test_an_undeclared_commit_difference_is_still_refused(self):
        problems = self.check(arm(commit="aaaa1111"), arm(commit="bbbb2222"), "")
        self.assertTrue(any("run.commit differs" in p for p in problems), problems)
        self.assertTrue(any("--build-is-the-arm" in p for p in problems), "and it says how to declare it")

    def test_declaring_it_does_not_excuse_a_different_machine(self):
        problems = self.check(arm(commit="aaaa1111"), arm(commit="bbbb2222", machine="flightdeck"),
                              "gang_tank 5.6 m -> 14 m")
        self.assertTrue(any("run.machine" in p for p in problems), problems)

    def test_declaring_it_does_not_excuse_a_different_workload(self):
        problems = self.check(arm(commit="aaaa1111"), arm(commit="bbbb2222", arena="pit"), "a size change")
        self.assertTrue(any("args.arena" in p for p in problems), problems)

    def test_declaring_it_does_not_excuse_a_dirty_tree(self):
        problems = self.check(arm(commit="aaaa1111"), arm(commit="bbbb2222", dirty=True), "a size change")
        self.assertTrue(any("DIRTY" in p for p in problems), problems)


class PerMatchup(unittest.TestCase):
    """Round 8: the per-FACTION number on pit was a flat 30% in both arms while `gangs vs law` went 9/20 to 0/20 --
    losing one matchup outright was offset by gaining another. Pooling is an average over exactly the dimension an
    asymmetry lives in."""

    def test_each_pair_is_reported_once_not_once_per_direction(self):
        rows = compare_arms.matchup_rows(arm(), arm())
        pairs = [key for _size, key, _v in rows]
        self.assertEqual(len(pairs), len(set(pairs)), "no duplicates: %s" % pairs)
        self.assertEqual(len(pairs), 3, "three pairings in the fixture, one row each: %s" % pairs)
        for side, other in pairs:
            self.assertLess(side, other, "canonical (alphabetical) orientation so it reads the same every time")

    def test_the_biggest_mover_comes_first(self):
        # A table nobody reads past line three must put the asymmetry on line one.
        treatment = copy.deepcopy(BASE)
        treatment["rows"][2]["win_rate"] = 0.0     # law vs syndicate: 0.5 -> 0.0, a 50-point move
        rows = compare_arms.matchup_rows(treatment, BASE)
        self.assertEqual(rows[0][1], ("law", "syndicate"))


class ExitStatus(unittest.TestCase):
    def test_a_refusal_exits_nonzero(self):
        # faction_matrix.py shipped with `main()` called bare, so its refusals returned 2 and the process exited
        # 0 -- a refusal reporting SUCCESS to make. This asserts the status, not the message.
        with tempfile.TemporaryDirectory() as folder:
            first, second = os.path.join(folder, "a.json"), os.path.join(folder, "b.json")
            for path in (first, second):
                with open(path, "w") as handle:
                    json.dump(arm(), handle)  # identical arms
            argv = sys.argv
            sys.argv = ["compare_arms.py", "--treatment", first, "--control", second]
            try:
                self.assertEqual(compare_arms.main(), 2)
            finally:
                sys.argv = argv



class SameRunTwice(unittest.TestCase):
    """The failure that produces a PERFECT NULL and looks like a measurement.

    `faction-matrix` named its output `-tuned.json` for any value of TUNE, so a control run and a treatment
    run wrote the same file: the second overwrote the first, and comparing them gave every cell zero with
    nothing in the report saying the two inputs were one file. **Running the series again reproduces it** —
    which is what makes this class of bug different from a flake.
    """

    def test_byte_identical_inputs_are_refused(self):
        a = arm(tune="switch.cost=1")
        out = compare_arms.refusals(a, copy.deepcopy(a), ("t.json", "c.json"),
                                    digests=("abc123" * 10, "abc123" * 10))
        self.assertTrue(any("THE SAME RUN TWICE" in line for line in out), out)

    def test_it_says_the_difference_is_zero_by_construction(self):
        a = arm(tune="switch.cost=1")
        out = compare_arms.refusals(a, copy.deepcopy(a), ("t.json", "c.json"),
                                    digests=("f" * 64, "f" * 64))
        self.assertTrue(any("zero by construction, not by measurement" in line for line in out), out)

    def test_different_digests_are_not_refused_for_that_reason(self):
        out = compare_arms.refusals(arm(tune="switch.cost=1"), arm(tune=""), ("t.json", "c.json"),
                                    digests=("a" * 64, "b" * 64))
        self.assertFalse(any("THE SAME RUN TWICE" in line for line in out), out)

    def test_no_digests_given_means_no_claim_either_way(self):
        """Absence of the check must not read as having passed it."""
        out = compare_arms.refusals(arm(tune="switch.cost=1"), arm(tune=""), ("t.json", "c.json"))
        self.assertFalse(any("THE SAME RUN TWICE" in line for line in out), out)

    def test_sha256_of_a_real_file_is_read(self):
        with tempfile.TemporaryDirectory() as tmp:
            one = os.path.join(tmp, "a.json")
            with open(one, "w") as handle:
                handle.write("{}")
            self.assertEqual(len(compare_arms.sha256(one)), 64)


class TuneIsAnArm(unittest.TestCase):
    """One checkout run twice with a different `--tune` IS two arms, and was being refused as one."""

    def test_two_tunes_are_two_arms(self):
        out = compare_arms.refusals(arm(tune="switch.cost=1"), arm(tune=""), ("t.json", "c.json"))
        self.assertFalse(any("IDENTICAL ARMS" in line for line in out), out)

    def test_the_same_tune_on_both_sides_is_one_arm(self):
        out = compare_arms.refusals(arm(tune="switch.cost=1"), arm(tune="switch.cost=1"),
                                    ("t.json", "c.json"))
        self.assertTrue(any("IDENTICAL ARMS" in line for line in out), out)


class Provenance(unittest.TestCase):
    def test_it_names_the_commit_the_machine_and_the_tune(self):
        line = compare_arms.provenance(arm(tune="switch.cost=1"))
        self.assertIn("switch.cost=1", line)
        self.assertIn(BASE["run"]["commit"], line)
        self.assertIn(BASE["run"]["machine"], line)

    def test_no_tune_says_none_rather_than_printing_nothing(self):
        self.assertIn("tune (none)", compare_arms.provenance(arm(tune="")))

    def test_a_dirty_tree_is_called_out(self):
        self.assertIn("DIRTY", compare_arms.provenance(arm(dirty=True)))

if __name__ == "__main__":
    unittest.main()
