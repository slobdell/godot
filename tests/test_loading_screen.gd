extends TestCase
## Control X4 (round 6): the loading screen between FIGHT and the match. It names the matchup and the arena, teaches
## one task by its symbol, shows which stage the load is in, records how long each took, and gets out of the way.


func _flags(values: Dictionary) -> LaunchFlags:
	var flags := LaunchFlags.new()
	flags.values = values
	return flags


func test_it_names_the_matchup_and_the_arena_and_teaches_a_task() -> void:
	var screen := LoadingScreen.show_for(tree, _flags({"player-faction": "condemned", "enemy-faction": "syndicate",
			"arena": "yard", "seed": "3"}))
	assert_true(screen.matchup.contains(String(Units.FACTION_NAMES.get("condemned", "")).to_upper()), "our faction (%s)" % screen.matchup)
	assert_true(screen.matchup.contains(String(Units.FACTION_NAMES.get("syndicate", "")).to_upper()), "and theirs")
	assert_true(screen.arena_title != "", "the arena has a title (%s)" % screen.arena_title)
	var row := TaskPalette.row(screen.tip)
	assert_true(bool(row.get("earned", false)) and String(row["id"]) != "formation", "the card teaches a task on the card (%s)" % screen.tip)
	assert_true(screen.get_parent() == tree.root, "it lives on the root, so it survives the scene switch")
	assert_eq(LoadingScreen.current, screen, "and is the current loading screen")
	screen.queue_free()
	await tree.process_frame


func test_stages_are_timed_in_order_and_it_fades_out_when_done() -> void:
	var screen := LoadingScreen.show_for(tree, _flags({"arena": "yard"}))
	screen.enter("scene")
	screen.report(0.5)
	assert_near(screen.progress, 0.5 / LoadingScreen.STAGES.size(), 0.001, "half-way through the first stage")
	await tree.process_frame
	screen.enter("arena")
	assert_near(screen.progress, 1.0 / LoadingScreen.STAGES.size(), 0.001, "the bar moves by stage")
	await tree.process_frame
	screen.enter("armies")
	screen.enter("first_frame")
	var blocker := screen.get_child(0) as Control
	assert_eq(blocker.mouse_filter, Control.MOUSE_FILTER_STOP, "while loading, nothing behind it takes a click")
	screen.done()
	assert_eq(blocker.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"once the match is playable, the fading screen lets clicks through (it ate shell-playtest's on builder0)")
	var timings := screen.timings()
	for entry: Array in LoadingScreen.STAGES:
		assert_true(timings.has(entry[0]), "stage %s was timed" % entry[0])
	assert_true(int(timings["total"]) >= int(timings["scene"]), "the total covers the stages")
	var gone := [false]
	screen.finished.connect(func() -> void: gone[0] = true)
	for i in 60:
		if gone[0]:
			break
		await tree.process_frame
	assert_true(gone[0], "it fades out and frees itself")
	assert_true(LoadingScreen.current == null, "leaving no current screen behind")


func test_a_doctrine_army_without_factions_has_no_matchup_line() -> void:
	assert_eq(LoadingScreen.matchup_of(_flags({})), "", "no factions, no matchup line")
	assert_true(LoadingScreen.matchup_of(_flags({"enemy-faction": "law"})).begins_with("YOUR ARMY"), "one faction names ours plainly")
