"""K5 contract: the validator accepts the fixtures and rejects each kind of broken timeline; the generator is seeded."""

import copy
import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import events  # noqa: E402
import fake_match  # noqa: E402

FIXTURES = HERE.parent.parent / "tests" / "announcer" / "fixtures"


def fixture(name="comeback"):
    return events.load_timeline(FIXTURES / ("%s.jsonl" % name))


def first(timeline, kind):
    return next(e for e in timeline if e["type"] == kind)


class ValidatorTest(unittest.TestCase):
    def test_every_checked_in_fixture_is_valid(self):
        paths = sorted(FIXTURES.glob("*.jsonl"))
        self.assertGreaterEqual(len(paths), 6, "the six scenarios are checked in")
        for path in paths:
            self.assertEqual(events.validate_timeline(events.load_timeline(path)), [], path.name)

    def assert_rejected(self, timeline, fragment):
        problems = events.validate_timeline(timeline)
        self.assertTrue(any(fragment in p for p in problems), "expected a problem containing %r, got %s" % (fragment, problems))

    def test_missing_field(self):
        timeline = fixture()
        del first(timeline, "unit_destroyed")["killer_team"]
        self.assert_rejected(timeline, "missing killer_team")

    def test_unknown_type(self):
        timeline = fixture()
        timeline.insert(3, dict(timeline[3], type="taunt"))
        self.assert_rejected(timeline, "unknown type")

    def test_bad_team_and_ratio(self):
        timeline = fixture()
        # first_contact, not close_call: every match has a first shot, but a close call depends on someone
        # surviving at low hull, which a regenerated fixture may simply not produce.
        first(timeline, "first_contact")["team"] = "blue"
        self.assert_rejected(timeline, "team must be green or rust")
        timeline = fixture()
        first(timeline, "damage")["hull"] = 1.4
        self.assert_rejected(timeline, "hull must be a ratio")

    def test_booleans_are_not_numbers(self):
        timeline = fixture()
        first(timeline, "damage")["critical"] = 1
        self.assert_rejected(timeline, "critical must be true or false")
        timeline = fixture()
        timeline[1]["tick"] = True
        self.assert_rejected(timeline, "tick must be an integer")

    def test_time_never_decreases(self):
        timeline = fixture()
        timeline[5]["tick"] = 0
        self.assert_rejected(timeline, "must not decrease")

    def test_start_and_end_bracket_the_match(self):
        timeline = fixture()
        self.assert_rejected(timeline[1:], "first event must be match_start")
        self.assert_rejected(timeline[:-1], "last event must be match_end")
        doubled = fixture()
        doubled.insert(1, copy.deepcopy(doubled[0]))
        self.assert_rejected(doubled, "exactly one match_start")

    def test_references_must_exist_and_match_types(self):
        timeline = fixture()
        first(timeline, "damage")["shooter"] = "Green_Nobody_9"
        self.assert_rejected(timeline, "not in match_start")
        timeline = fixture()
        event = first(timeline, "unit_destroyed")
        event["victim_unit"] = "artillery" if event["victim_unit"] != "artillery" else "tank"
        self.assert_rejected(timeline, "not a")

    def test_the_dead_stay_dead(self):
        """A destroyed vehicle can still *kill* — its round was already in the air — but it cannot be hit, spot
        anything or be spotted. Those fields stay strict (see events.MAY_BE_DEAD)."""
        timeline = fixture()
        death = first(timeline, "unit_destroyed")
        later = [e for e in timeline if e["type"] == "damage" and e["tick"] >= death["tick"]][0]
        later["victim"], later["victim_unit"] = death["victim"], death["victim_unit"]
        self.assert_rejected(timeline, "already destroyed")

    def test_a_dead_crew_can_still_land_a_shot(self):
        """The other half of the same rule: a shell outlives the crew that fired it, so a kill credited to a unit
        that is already gone is a real thing the match produces, not a bookkeeping error."""
        timeline = fixture()
        death = first(timeline, "unit_destroyed")
        later = [e for e in timeline if e["type"] == "damage" and e["tick"] >= death["tick"]][0]
        later["shooter"], later["shooter_unit"] = death["victim"], death["victim_unit"]
        self.assertEqual(events.validate_timeline(timeline), [], "his round was already in the air")

    def test_friendly_flag_matches_teams_and_hazards_have_no_killer(self):
        timeline = fixture()
        first(timeline, "unit_destroyed")["friendly"] = True
        self.assert_rejected(timeline, "friendly must be true exactly when")
        timeline = fixture()
        event = first(timeline, "unit_destroyed")
        event["killer"] = ""
        self.assert_rejected(timeline, "hazard kill has empty killer")

    def test_shared_broken_cases_are_rejected(self):
        # The same cases run in tests/announcer/test_announcer_events.gd, so the two validators agree.
        cases = json.loads((HERE.parent.parent / "tests" / "announcer" / "contract_cases.json").read_text())["cases"]
        self.assertGreaterEqual(len(cases), 15)
        for case in cases:
            timeline = fixture(case["fixture"])
            if "drop" in case:
                timeline.pop(0 if case["drop"] == "first" else -1)
            else:
                target = first(timeline, case["event"])
                target.update(case.get("set", {}))
                if "delete" in case:
                    del target[case["delete"]]
            self.assertNotEqual(events.validate_timeline(timeline), [], "rejects: %s" % case["name"])

    def test_non_json_line_names_the_line(self):
        path = HERE / "_broken_fixture.jsonl"
        path.write_text('{"tick": 0}\nnot json\n')
        try:
            with self.assertRaisesRegex(ValueError, ":2: not JSON"):
                events.load_timeline(path)
        finally:
            path.unlink()


class FakeMatchTest(unittest.TestCase):
    def test_same_seed_same_match(self):
        self.assertEqual(fake_match.generate("close_match", 7), fake_match.generate("close_match", 7))
        self.assertNotEqual(fake_match.generate("close_match", 7), fake_match.generate("close_match", 40))

    def test_checked_in_fixtures_match_the_generator(self):
        # make announcer-fixtures writes seed 1 for every scenario; a generator change must regenerate the files.
        for name in fake_match.SCENARIOS:
            generated = [json.loads(json.dumps(e)) for e in fake_match.generate(name, 1)]
            self.assertEqual(generated, fixture(name), "%s.jsonl is stale: run make announcer-fixtures" % name)

    def test_scenarios_show_their_shape(self):
        for name, scenario in fake_match.SCENARIOS.items():
            timeline = fixture(name)
            self.assertTrue(scenario.fits(timeline), name)
            kinds = {e["type"] for e in timeline}
            self.assertTrue({"first_contact", "unit_destroyed", "momentum"} <= kinds, name)
        disaster = fixture("friendly_fire_disaster")
        self.assertGreaterEqual(sum(e["type"] == "friendly_fire" for e in disaster), 3)
        self.assertEqual(fixture("control_swing")[-1]["reason"], "control")




class DeadShooterTest(unittest.TestCase):
    """A shell outlives the crew that fired it, so a kill can be credited to a unit that is already gone. Rare
    until ai's brains started firing to suppress; then it became common and started failing `make check`."""

    START = {"tick": 0, "t": 0.0, "type": "match_start", "arena": "foundry", "budget": 1000, "teams": [
        {"team": "green", "faction": "law", "units": [{"id": "g1", "unit": "tank"}]},
        {"team": "rust", "faction": "gangs", "units": [{"id": "r1", "unit": "tank"}]}]}

    @staticmethod
    def kill(t, victim, victim_team, killer, killer_team):
        return {"tick": int(t * 60), "t": t, "type": "unit_destroyed", "victim": victim, "victim_unit": "tank",
                "victim_team": victim_team, "killer": killer, "killer_unit": "tank", "killer_team": killer_team,
                "friendly": False}

    @staticmethod
    def end(winner, green, rust):
        return {"tick": 120, "t": 2.0, "type": "match_end", "winner": winner, "reason": "elimination",
                "duration_seconds": 2.0, "units_left": {"green": green, "rust": rust},
                "kills_by_unit": {"green": {}, "rust": {}}}

    def test_a_kill_credited_to_a_dead_shooter_is_legal(self):
        timeline = [self.START, self.kill(1.0, "g1", "green", "r1", "rust"),
                    self.kill(1.5, "r1", "rust", "g1", "green"), self.end("draw", 0, 0)]
        self.assertEqual(events.validate_timeline(timeline), [], "his round was already in the air")

    def test_a_unit_dying_twice_is_still_a_bug(self):
        timeline = [self.START, self.kill(1.0, "g1", "green", "r1", "rust"),
                    self.kill(1.5, "g1", "green", "r1", "rust"), self.end("rust", 0, 1)]
        self.assertTrue(events.validate_timeline(timeline), "relaxing the shooter must not relax the victim")

    def test_a_dead_unit_being_targeted_is_still_a_bug(self):
        timeline = [self.START, self.kill(1.0, "g1", "green", "r1", "rust"),
                    {"tick": 90, "t": 1.5, "type": "first_contact", "team": "rust", "unit_id": "r1", "unit": "tank",
                     "target_id": "g1", "target_unit": "tank"}, self.end("rust", 0, 1)]
        self.assertTrue(events.validate_timeline(timeline), "you cannot open fire on something already destroyed")


if __name__ == "__main__":
    unittest.main()
