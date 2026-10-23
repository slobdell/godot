extends TestCase
## Round 38 (feedback F1/F2): what the end of a match says. He played on after a match ended on the rings (game_design.md, round
## 37's mid-round note: the end at 195.4 s, his later clicks still answered "move"), so the end names who won AND why, in his words,
## and the next match is one key away.

const FACTIONS := {Match.Team.GREEN: "law", Match.Team.RUST: "syndicate"}


func _result(winner: String, reason: String, control: Variant = null, left := {"green": 3, "rust": 4}) -> Dictionary:
	return {"winner": winner, "reason": reason, "control": control, "units_left": left}


func test_the_headline_is_from_his_side() -> void:
	assert_eq(MatchEnd.headline(_result("Green", "control"), Match.Team.GREEN, false, FACTIONS), "VICTORY", "his side won")
	assert_eq(MatchEnd.headline(_result("Rust", "control"), Match.Team.GREEN, false, FACTIONS), "DEFEAT", "the CPU won")
	assert_eq(MatchEnd.headline(_result("draw", "time_limit"), Match.Team.GREEN, false, FACTIONS), "DRAW", "nobody won")
	assert_eq(MatchEnd.headline(_result("Rust", "control"), Match.Team.GREEN, true, FACTIONS), "THE SYNDICATE WIN",
			"spectated: the winning faction")
	assert_eq(MatchEnd.outcome(_result("Rust", "elimination"), Match.Team.GREEN), "loss", "outcome for colour and sound")


func test_his_case_a_loss_on_the_rings_says_who_held_them() -> void:
	var line := MatchEnd.reason_line(_result("Rust", "control", {"green": 61, "rust": 90}), Match.Team.GREEN, FACTIONS)
	assert_eq(line, "The Syndicate held the rings: 90 points to 61", "the reason he missed")
	line = MatchEnd.reason_line(_result("Green", "control", {"green": 90, "rust": 12}), Match.Team.GREEN, FACTIONS)
	assert_eq(line, "You held the rings: 90 points to 12", "a win on the rings")


func test_elimination_says_who_was_wiped_out_and_what_was_left() -> void:
	var lost := MatchEnd.reason_line(_result("Rust", "elimination", null, {"green": 0, "rust": 4}), Match.Team.GREEN, FACTIONS)
	assert_eq(lost, "Your last vehicle was destroyed. The Syndicate kept 4", "a wipe-out")
	var won := MatchEnd.reason_line(_result("Green", "elimination", null, {"green": 1, "rust": 0}), Match.Team.GREEN, FACTIONS)
	assert_eq(won, "Every enemy vehicle destroyed. You kept 1", "one survivor: singular")


func test_a_time_out_says_who_led() -> void:
	assert_eq(MatchEnd.reason_line(_result("Green", "time_limit", {"green": 40, "rust": 22}), Match.Team.GREEN, FACTIONS),
			"Time's up: you led at the rings, 40 points to 22", "a timed-out ring match")
	assert_eq(MatchEnd.reason_line(_result("draw", "time_limit", {"green": 30, "rust": 30}), Match.Team.GREEN, FACTIONS),
			"Time's up, level at the rings: 30 points each", "a level time-out")
	assert_eq(MatchEnd.reason_line(_result("Rust", "time_limit", null), Match.Team.GREEN, FACTIONS),
			"Time's up: The Syndicate destroyed more", "a timed-out wipe-out match")


func test_spectated_names_both_factions() -> void:
	var line := MatchEnd.reason_line(_result("Rust", "control", {"green": 50, "rust": 90}), -1, FACTIONS)
	assert_eq(line, "The Syndicate held the rings: 90 points to 50", "no 'you' when nobody commands")
	line = MatchEnd.reason_line(_result("Green", "elimination", null, {"green": 2, "rust": 0}), -1, FACTIONS)
	assert_eq(line, "Every Syndicate vehicle destroyed. The Law kept 2", "the loser named by faction")


func test_no_faction_falls_back_to_team_names() -> void:
	var line := MatchEnd.reason_line(_result("Rust", "control", {"green": 1, "rust": 90}), Match.Team.GREEN, {})
	assert_eq(line, "Rust held the rings: 90 points to 1", "no faction flags (make run)")


func test_the_score_line_reads_the_final_board() -> void:
	assert_eq(MatchEnd.score_line(_result("Rust", "control", {"green": 61, "rust": 90}, {"green": 2, "rust": 5}), Match.Team.GREEN),
			"Vehicles left: you 2, enemy 5", "what was left on the field")


func test_play_again_keeps_his_factions_and_rolls_a_new_seed() -> void:
	var flags := LaunchFlags.new()
	flags.values = {"skirmish": "", "seed": "41", "player-faction": "law", "enemy-faction": "syndicate", "arena": "terminus",
			"no-pick-faction": ""}
	var again := MatchEnd.next_flags(flags, "again", 777)
	assert_eq(again.text("seed"), "777", "a new fight")
	assert_eq(again.text("player-faction"), "law", "his side kept")
	assert_eq(again.text("arena"), "terminus", "a rematch: the same map")
	assert_eq(flags.text("seed"), "41", "the old flags untouched")
	var menu := MatchEnd.next_flags(flags, "factions", 778)
	assert_true(menu.has("pick-faction") and not menu.has("no-pick-faction"), "the faction menu")
	assert_true(not menu.has("player-faction") and not menu.has("enemy-faction"), "a fresh pick")
