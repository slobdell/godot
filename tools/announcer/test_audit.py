"""The line library passes its own text audit, and the audit catches each kind of mistake."""

import copy
import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import audit_lines  # noqa: E402

LINES = json.loads(audit_lines.LINES.read_text())
BEATS = json.loads(audit_lines.BEATS.read_text())


def with_line(**fields):
    data = copy.deepcopy(LINES)
    line = {"id": "test.line", "speaker": "caller", "act": "call", "tags": ["kill"], "text": "A fine line."}
    line.update(fields)
    data["lines"].append(line)
    return data


class AuditTest(unittest.TestCase):
    def test_the_library_is_clean_and_large(self):
        errors, _ = audit_lines.audit(LINES, BEATS)
        self.assertEqual(errors, [])
        self.assertGreaterEqual(len(LINES["lines"]), 350, "hundreds of lines (N1)")
        speakers = {line["speaker"] for line in LINES["lines"]}
        self.assertEqual(speakers, {"caller", "color", "pa"})

    def assert_error(self, data, fragment):
        errors, _ = audit_lines.audit(data, BEATS)
        self.assertTrue(any(fragment in e for e in errors), "expected %r in %s" % (fragment, errors))

    def test_catches_structure_mistakes(self):
        self.assert_error(with_line(speaker="ref"), "unknown speaker")
        self.assert_error(with_line(act="sponsor_read"), "has no act")
        self.assert_error(with_line(tags=["upset"]), "name no moment kind")
        self.assert_error(with_line(id=LINES["lines"][0]["id"]), "duplicate id")
        self.assert_error(with_line(intensity=5), "intensity must be")

    def test_catches_what_a_voice_reads_badly(self):
        self.assert_error(with_line(text="That's 3 kills!"), "reads badly")
        self.assert_error(with_line(text="Green & Rust / tonight"), "reads badly")
        self.assert_error(with_line(text="What a {weapon}!"), "unknown slot")
        self.assert_error(with_line(text="That was a {victim_unit}!"), "'a {victim_unit}'")
        self.assert_error(with_line(text=LINES["lines"][0]["text"].upper()), "same text as")

    def test_catches_dangling_flags_topics_and_beats(self):
        self.assert_error(with_line(needs=["predicted_rain"]), "no line sets")
        self.assert_error(with_line(act="setup_question", tags=["lull"], topic="weather", text="Rain later?"), "never answered")
        data = copy.deepcopy(LINES)
        data["lines"] = [line for line in data["lines"] if not (line["speaker"] == "pa" and line["act"] == "welcome")]
        self.assert_error(data, "no pa line for welcome")

    def test_sides_are_named_by_faction_never_by_colour(self):
        """X3 (round 5): the lead heard "Green and Rust, live, right now!". Matches are always cross-faction, so a
        side has a sayable name and a colour is never it."""
        self.assert_error(with_line(tags=["intro"], act="hype", text="Green and Rust, live, right now!"), "colour")
        self.assert_error(with_line(text="The blue team takes it!"), "colour")
        self.assert_error(with_line(text="{team} take it!"), "colour")
        self.assert_error(with_line(text="That is {other_team_s} last one!"), "colour")
        errors, _ = audit_lines.audit(with_line(text="You can see the rust around the bolts."), BEATS)
        self.assertFalse([e for e in errors if "test.line" in e], "rust the substance is not a team")

    def test_a_named_faction_only_plays_when_that_faction_is_on_the_floor(self):
        """Line tags are requirements: a line that calls the Wreckers by name must carry faction_gangs or
        other_faction_gangs, or it can play in a Law-Syndicate match. The Syndicate and the Law also exist as the
        arena's owner and the state, so only their crews and machines count as naming a side."""
        self.assert_error(with_line(text="The Wreckers crack it wide open!"), "gangs")
        self.assert_error(with_line(text="The Condemned crew gets it done!"), "condemned")
        self.assert_error(with_line(text="The Syndicate machine takes it clean."), "syndicate")
        for fine in (with_line(tags=["kill", "faction_gangs"], text="The Wreckers crack it wide open!"),
                     with_line(tags=["kill", "other_faction_condemned"], text="The Condemned crew loses one!"),
                     with_line(speaker="pa", act="notice", tags=["lull"], text="The Syndicate thanks you for watching.")):
            errors, _ = audit_lines.audit(fine, BEATS)
            self.assertFalse([e for e in errors if "test.line" in e], errors)

    def test_a_faction_is_plural_all_the_way_through_the_sentence(self):
        self.assert_error(with_line(text="{other_faction} are down to its last vehicle!"), "plural")

    def test_warns_about_the_rejected_tone(self):
        _, warnings = audit_lines.audit(with_line(speaker="pa", act="notice", tags=["lull"],
                                                  text="He has been retired. Terms and conditions apply."), BEATS)
        self.assertTrue(any("rejected tone" in w for w in warnings), warnings)
        _, warnings = audit_lines.audit(with_line(text="Let's get it on!"), BEATS)
        self.assertTrue(any("borrowed" in w for w in warnings), warnings)


    def test_a_faction_is_plural_in_verb_and_pronoun(self):
        # Round 10: the transcripts read "The Wreckers draws first blood" and "hit its own scout". Both are the same
        # rule ("the Condemned take it"), and both slipped past a list that did not have the words in it.
        self.assert_error(with_line(text="{faction} draws first blood tonight."), "plural verb")
        self.assert_error(with_line(text="{faction} steals the point away!"), "plural verb")
        self.assert_error(with_line(text="{faction} hit its own scout!"), "their")
        errors, _ = audit_lines.audit(with_line(text="{faction} draw first blood here, and this crowd is on its feet!"),
                                      BEATS)
        self.assertEqual([e for e in errors if "test.line" in e], [], "the crowd keeps its own feet")

    # C10 (round 10): the PA's new lines carry their one wrong detail as data, and the audit holds it to the register.
    def pa_line(self, text, span, category="paperwork", **fields):
        line = dict(speaker="pa", act="notice", tags=["lull"], added="r10", text=text,
                    oddity={"span": span, "category": category})
        line.update(fields)
        return with_line(**line)

    def test_a_good_pa_line_passes(self):
        data = self.pa_line("Medical staff will attend to the crews after the match, in the order their forms arrive, "
                            "and not a minute before that.", "in the order their forms arrive")
        errors, _ = audit_lines.audit(data, BEATS)
        self.assertEqual([e for e in errors if "test.line" in e], [])

    def test_pa_gates(self):
        self.assert_error(with_line(speaker="pa", act="notice", tags=["lull"], added="r10", text="A calm notice here."),
                          "names no oddity")
        self.assert_error(self.pa_line("Water is served in the lower bowl tonight, for the crews.", "for the elephants"),
                          "is not in the text")
        self.assert_error(self.pa_line("Water service resumes for residents of approved households and their lawfully registered pets, "
                                       "on the usual schedule tonight.",
                                       "for residents of approved households and their lawfully registered pets"),
                          "1-6 words")
        self.assert_error(self.pa_line("Water service in the lower bowl resumes for approved households.",
                                       "for approved households"), "punchline position")
        self.assert_error(self.pa_line("Water service resumes for approved households only, as scheduled tonight.",
                                       "for approved households", category="wizardry"), "unknown oddity category")
        self.assert_error(self.pa_line("Water service resumes for approved households, and is scheduled for tonight!",
                                       "for approved households"), "flat register")
        self.assert_error(self.pa_line("Sadly, water service resumes for approved households only, as scheduled.",
                                       "for approved households"), "affect word")

    def test_pa_categories_do_not_repeat_in_a_pool(self):
        data = self.pa_line("Water service resumes for approved households only, and on schedule tonight.",
                            "for approved households", category="rationing")
        data["lines"].append(dict(data["lines"][-1], id="test.line2", text="Ration cards are honoured at the "
                                  "concourse this evening, at half value, for the whole of the match.",
                                  oddity={"span": "at half value", "category": "rationing"}))
        self.assert_error(data, "same kind of wrong detail")


if __name__ == "__main__":
    unittest.main()
