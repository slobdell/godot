extends TestCase
## Army Y3/Y4: the results screen (what happened, credits, counters) and the loop's restart flags.


func _report() -> Dictionary:
	return {"key": "k", "winner": "Rust", "reason": "elimination", "duration_seconds": 131.0, "budget": 800, "tier": 0,
			"teams": {"green": {"units": {"tank": 3, "ifv": 1}, "units_left": 0, "units_lost": 4, "kills": 2,
					"kills_by_unit": {"tank": 2}, "losses_by_unit": {"tank": 3, "ifv": 1}},
				"rust": {"units": {"scout": 5, "tank": 1}, "units_left": 4, "units_lost": 2, "kills": 4,
					"kills_by_unit": {"scout": 4}, "losses_by_unit": {"scout": 2}}},
			"best_unit": {"name": "Rust_Eyes_2", "unit": "scout", "team": "Rust", "kills": 3, "alive": true}}


func test_the_lesson_names_what_they_fielded_and_its_counter() -> void:
	var catalog := ArmyCatalog.from_game()
	var lesson := ResultsScreen.counter_lesson(_report(), catalog)
	assert_true(lesson.begins_with("Their army was mostly Scouts."), "the most common enemy unit: %s" % lesson)
	for unit_id in catalog.unit_ids():
		if catalog.good_vs(unit_id).has("scout"):
			assert_true(lesson.contains(GarageAdvice._pluralize(catalog.display_name(unit_id))), "%s counters scouts and is named: %s" % [unit_id, lesson])


func test_the_screen_shows_the_outcome_credits_and_best_unit_and_its_buttons_work() -> void:
	tree.root.size = Vector2i(1280, 720)
	var profile := Progression.new("")
	var report := _report()
	var paid := Progression.credits_for(report, "Green", 0)
	var screen := ResultsScreen.new()
	screen.setup(report, paid, profile, ArmyCatalog.from_game(), "CPU: Swarm (seed 4)")
	add_to_tree(screen)
	await wait_physics_frames(2)
	assert_eq((screen.find_child("Headline", true, false) as Label).text, "DEFEAT", "a loss says DEFEAT")
	assert_true(screen.find_child("CreditsEarned", true, false) == null and screen.find_child("NextGoal", true, false) == null,
			"round 19: no credit breakdown and no unlock to sell")
	assert_true((screen.find_child("BestUnit", true, false) as Label).text.contains("Eyes #2"), "the best unit is named on its side")
	assert_true((screen.find_child("Destroyed_green", true, false) as Label).text.contains("worth 126 CR"),
			"what he destroyed, in credits: two scouts at 63")
	assert_true((screen.find_child("Lost_green", true, false) as Label).text.contains("3 Tanks"), "your losses by type")
	var pressed: Array = []
	screen.rematch_requested.connect(func() -> void: pressed.append("rematch"))
	screen.army_requested.connect(func() -> void: pressed.append("army"))
	for button_name in ["Rematch", "Army"]:
		var button := screen.find_child(button_name, true, false) as Button
		assert_true(button.size.y >= 48.0 or tree.root.size.y < 1080, "%s is a real tap target" % button_name)
		button.pressed.emit()
	assert_eq(pressed, ["rematch", "army"], "REMATCH and ARMY ask the loop to restart")


func test_restarts_carry_the_automation_flags_and_consume_one_auto_step() -> void:
	var current := LaunchFlags.parse(["--garage", "--garage-scratch", "--mute", "--army-loop-auto=rematch,army,quit", "--army-loop-time=6",
			"--seed=9", "--garage-autofight"])
	var next := ArmyLoop.restart_flags(current, {"garage": "", "garage-rematch": "", "seed": "9"})
	assert_true(next.has("garage-scratch") and next.has("mute") and next.has("garage-keep"), "a scratch run stays a scratch run and keeps its files")
	assert_eq(next.text("army-loop-auto"), "army,quit", "one automatic step is used up")
	assert_true(not next.has("garage-autofight"), "a restart doesn't re-tap FIGHT unless it's a rematch")
	assert_eq(ArmyLoop.restart_flags(LaunchFlags.parse(["--army-loop-auto=army"]), {}).has("army-loop-auto"), false, "the last step ends automation")
	assert_true(GameMode.choose(next) is GarageMode, "restarts open the army builder mode")


func test_another_factions_vehicles_are_named_and_counted() -> void:
	var report := _report()
	report["teams"]["rust"]["units"] = {"law_tank": 4, "law_scout": 1}
	report["teams"]["rust"]["losses_by_unit"] = {"law_tank": 2}
	var catalog := ArmyCatalog.for_game("condemned")
	assert_eq(ResultsScreen.credits_of({"law_tank": 2}), 298, "two Law tanks are 298 credits")
	var lesson := ResultsScreen.counter_lesson(report, catalog)
	assert_true(lesson.begins_with("Their army was mostly %s" % GarageAdvice._pluralize(Units.profile("law_tank")["display_name"])),
			"the Law's tank by its own name: %s" % lesson)
	for unit_id in catalog.unit_ids():
		if catalog.good_vs(unit_id).has("tank"):
			assert_true(lesson.contains(GarageAdvice._pluralize(catalog.display_name(unit_id))), "his %s counters tanks: %s" % [
					unit_id, lesson])
	assert_true(MatchReport.describe_units({"law_tank": 2}, catalog).contains(String(Units.profile("law_tank")["display_name"])),
			"a vehicle outside his roster is named, not spelled as an id")


func test_the_reason_names_the_maps_zones_and_the_score_line_reads_the_board() -> void:
	var report := {"winner": "Rust", "reason": "time_limit", "control": {"green": 20, "rust": 55}}
	assert_true(ResultsScreen.reason_text(report, "loss").contains("held the centre longer"),
			"without the board's score (an older report) it says the centre")
	report["score"] = {"control": true, "points_to_win": 90, "objectives": [{"name": "west ring"}, {"name": "east ring"}],
			"sides": [{"points": 20, "kills": 3, "points_destroyed": 600}, {"points": 55, "kills": 5, "points_destroyed": 1100}]}
	assert_true(ResultsScreen.reason_text(report, "loss").contains("they held the rings longer (55 to 20)"),
			"a two-ring map says the rings: %s" % ResultsScreen.reason_text(report, "loss"))
	assert_eq(ResultsScreen.score_line(report), "Points 20 to 55 of 90  ·  Kills 3 to 5  ·  Destroyed 343 CR to 629 CR",
			"the board's numbers, you first, points destroyed shown in credits")
	report["score"]["objectives"] = [{"name": "centre"}]
	assert_true(ResultsScreen.reason_text(report, "loss").contains("held the centre longer"), "a one-zone map says the centre")
	assert_eq(ResultsScreen.score_line({}), "", "no board, no line")


func test_the_report_takes_the_board_at_the_finish_even_before_final_score_is_filled() -> void:
	add_to_tree(preload("res://game/arena/arena.tscn").instantiate())
	var game_match: Match = preload("res://game/match/match.tscn").instantiate()
	add_to_tree(game_match)
	await wait_physics_frames(2)
	game_match.final_score = {}
	var report := {}
	ArmyLoop.last_report_score(game_match, report)
	assert_true(report.has("score"), "an empty final_score falls back to the snapshot (finished is emitted first)")
	assert_true((report["score"].get("sides", []) as Array).size() == 2, "with both sides")
	assert_true(ResultsScreen.score_line(report).contains("Kills 0 to 0"), "and the line reads it: %s" % ResultsScreen.score_line(report))


func test_the_lesson_after_a_loss_on_the_rings_says_rings() -> void:
	var report := {"winner": "Rust", "reason": "time_limit", "control": {"green": 0, "rust": 30},
			"score": {"objectives": [{"name": "west ring"}, {"name": "east ring"}], "sides": []}}
	assert_eq(ResultsScreen.point_lesson(report, "loss"), CentreTip.RINGS_LINE, "a two-ring map's lesson names the rings")
	report["score"]["objectives"] = [{"name": "centre"}]
	assert_eq(ResultsScreen.point_lesson(report, "loss"), CentreTip.LINE, "a one-zone map's names the centre")
	assert_eq(CentreTip.line_for(2), CentreTip.RINGS_LINE, "the card in the fight says the same")


## Round 20 (stretch b): who held each ring at the finish, by the board's own names, you first.
func test_the_rings_line_says_who_held_each_ring_at_the_finish() -> void:
	var report := {"score": {"control": true, "points_to_win": 90, "sides": [
			{"zones": [{"name": "west ring", "label": "west ring", "held": true}, {"name": "east ring", "label": "east ring", "held": false},
					{"name": "mid", "label": "mid", "held": false}]},
			{"zones": [{"name": "west ring", "label": "west ring", "held": false}, {"name": "east ring", "label": "east ring", "held": true},
					{"name": "mid", "label": "mid", "held": false}]}]}}
	assert_eq(ResultsScreen.rings_line(report), "At the finish:  West Ring — yours  ·  East Ring — theirs  ·  Mid — nobody's",
			"each ring, who held it")
	report["score"]["control"] = false
	assert_eq(ResultsScreen.rings_line(report), "", "no control score, no line")
	assert_eq(ResultsScreen.rings_line({}), "", "an older report, no line")
