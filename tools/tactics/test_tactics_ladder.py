#!/usr/bin/env python3
"""Round 15 (squad P2): the tactics ladder carries its winner rule and refuses to compare across one.

Known answers: the rule hash of match.gd as it stands, and of the pre-5f562dd0 rule (a fixture copy of the old
`result`), differ and are named; a comment edit does not change the hash; a code edit does; `--compare` refuses a
reference taken under another rule, a reference with no rule, and a different workload, and accepts a twin.
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import tactics_ladder  # noqa: E402

OLD_RULE = '''
func result(reason: String) -> Dictionary:
	var winner := "draw"
	if reason == "control" or (control_point and reason == "time_limit" and control_score[0] != control_score[1]):
		winner = TEAM_NAMES[Team.GREEN] if control_score[0] > control_score[1] else TEAM_NAMES[Team.RUST]
	elif elimination:
		# Last team with tanks wins; on a time limit, more tanks alive, then more total health.
		var standing := [_team_standing(Team.GREEN), _team_standing(Team.RUST)]
		if standing[0] != standing[1]:
			winner = TEAM_NAMES[Team.GREEN] if standing[0] > standing[1] else TEAM_NAMES[Team.RUST]
	elif score_green != score_rust:
		winner = TEAM_NAMES[Team.GREEN] if score_green > score_rust else TEAM_NAMES[Team.RUST]
	var units_left := {"green": alive_count(Team.GREEN), "rust": alive_count(Team.RUST)}
	return {"winner": winner}


func _team_standing(team: int) -> int:
	var health := 0
	for tank in team_tanks(team):
		if tank.is_alive():
			health += tank.health
	return alive_count(team) * 100000 + health
'''


def ladder(rule_hash, **overrides):
    args = {"army": "combined_arms", "arenas": "foundry,yard", "factions": "", "budget": 5200, "control": "on",
            "runs": 2, "first_seed": 1, "time_limit": 240, "extra": ""}
    args.update(overrides)
    return {"args": args, "winner_rule": {"hash": rule_hash, "name": "x"} if rule_hash else None,
            "conditions": {"machine": "builder0", "commit": "abc"}, "ratings": {"brains": 990.0, "faction": 1010.0}}


class WinnerRule(unittest.TestCase):
    def test_the_live_rule_is_known_by_name(self):
        rule = tactics_ladder.current_winner_rule()
        self.assertIn("r14", rule["name"], "match.gd's winner rule as shipped is the round-14 rule: %s" % rule)

    def test_the_old_rule_hashes_differently_and_is_named(self):
        old = tactics_ladder.winner_rule(OLD_RULE)
        self.assertNotEqual(old["hash"], tactics_ladder.current_winner_rule()["hash"])
        self.assertIn("r13", old["name"])

    def test_a_comment_does_not_change_the_rule_but_code_does(self):
        base = tactics_ladder.winner_rule(OLD_RULE)["hash"]
        commented = OLD_RULE.replace("var winner := \"draw\"", "var winner := \"draw\"  # nobody yet\n\t# more words")
        self.assertEqual(tactics_ladder.winner_rule(commented)["hash"], base)
        changed = OLD_RULE.replace("* 100000", "* 1000")
        self.assertNotEqual(tactics_ladder.winner_rule(changed)["hash"], base)

    def test_rule_reads_only_up_to_the_winner(self):
        body = tactics_ladder._function_body(OLD_RULE, "result")
        self.assertIn("winner", body)
        self.assertNotIn("units_left", body)


class Refusal(unittest.TestCase):
    def test_refuses_across_a_rule_change(self):
        reasons = tactics_ladder.comparison_refusals(ladder("aaaa"), ladder("bbbb"))
        self.assertTrue(any("winner rule" in r for r in reasons), reasons)
        self.assertEqual(tactics_ladder.compare(ladder("aaaa"), ladder("bbbb")), 3)

    def test_refuses_a_reference_without_a_rule(self):
        reasons = tactics_ladder.comparison_refusals(ladder("aaaa"), ladder(None))
        self.assertTrue(any("no winner rule" in r for r in reasons), reasons)

    def test_refuses_another_workload(self):
        for key, value in (("time_limit", 180), ("arenas", "foundry"), ("runs", 4), ("army", "law_mirror")):
            reasons = tactics_ladder.comparison_refusals(ladder("aaaa", **{key: value}), ladder("aaaa"))
            self.assertTrue(any(r.startswith(key) for r in reasons), (key, reasons))

    def test_accepts_a_twin(self):
        self.assertEqual(tactics_ladder.comparison_refusals(ladder("aaaa"), ladder("aaaa")), [])
        self.assertEqual(tactics_ladder.compare(ladder("aaaa"), ladder("aaaa")), 0)

    def test_the_kept_reference_carries_a_rule(self):
        path = os.path.join(HERE, "ladder_reference.json")
        if not os.path.exists(path):
            self.skipTest("no reference recorded yet")
        with open(path) as handle:
            reference = json.load(handle)
        self.assertTrue(reference.get("winner_rule", {}).get("hash"), "the reference names its rule")
        self.assertTrue(reference.get("conditions", {}).get("commit"), "and its commit")
        self.assertEqual(reference["winner_rule"]["hash"], tactics_ladder.current_winner_rule()["hash"],
                         "the kept reference is the CURRENT rule's: re-baseline the ladder when the rule changes")


class EndToEnd(unittest.TestCase):
    def test_the_script_exits_3_when_refusing(self):
        # The script's own --compare path, without a Godot: a run json fed in through compare() is what main() does,
        # so check the exit code through a subprocess that imports the module and calls compare on two files.
        with tempfile.TemporaryDirectory() as tmp:
            a, b = os.path.join(tmp, "a.json"), os.path.join(tmp, "b.json")
            for path, rule in ((a, "aaaa"), (b, "bbbb")):
                with open(path, "w") as handle:
                    json.dump(ladder(rule), handle)
            code = subprocess.run([sys.executable, "-c",
                                   "import sys, json; sys.path.insert(0, %r); import tactics_ladder as t; "
                                   "sys.exit(t.compare(json.load(open(%r)), json.load(open(%r))))"
                                   % (os.path.join(HERE, ".."), a, b)], capture_output=True, text=True)
            self.assertEqual(code.returncode, 3, code.stdout + code.stderr)
            self.assertIn("LADDER_COMPARE REFUSED", code.stdout)


if __name__ == "__main__":
    unittest.main()
