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


func test_the_next_goal_is_the_cheapest_unlock() -> void:
	var catalog := ArmyCatalog.from_game()
	var profile := Progression.new("")
	profile.credits = 50
	var goal := ResultsScreen.next_goal(profile, catalog)
	var cheapest := 1000000
	for unit_id in catalog.unit_ids():
		if not profile.has_unit(catalog, unit_id):
			cheapest = mini(cheapest, Progression.unit_unlock_credits(catalog, unit_id))
	cheapest = mini(cheapest, int(profile.next_tier()["unlock_credits"]))
	assert_true(goal.begins_with("%d more credits" % (cheapest - 50)), "how far to the cheapest unlock: %s" % goal)
	profile.credits = 100000
	assert_true(ResultsScreen.next_goal(profile, catalog).contains("now"), "and when it's affordable, says so")


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
	assert_eq((screen.find_child("CreditsEarned", true, false) as Label).text, "+%d" % paid["credits"], "the credits earned")
	assert_true((screen.find_child("BestUnit", true, false) as Label).text.contains("Eyes #2"), "the best unit is named on its side")
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
