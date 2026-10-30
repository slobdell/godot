extends TestCase
## Round 45 (the lead: "make garage lets you select everything except for the map - can we make that workflow select the map
## as well?"): a MAP pick beside VS, RANDOM then every arena in the rotation, remembered like the last army, and the fight
## is played on it (the arena builds before the garage opens, so a different pick relaunches into the fight on that map).


func _open(settings: GarageSettings) -> GarageScreen:
	tree.root.size = Vector2i(1280, 720)
	var screen := GarageScreen.new()
	screen.settings = settings
	screen.progression = Progression.new("")
	screen.store_dir = "user://test_garage_map/"
	add_to_tree(screen)
	await wait_physics_frames(2)
	return screen


func test_the_map_button_cycles_random_then_every_arena_and_back() -> void:
	var screen := await _open(GarageSettings.new(""))
	assert_eq(screen.arena, GarageScreen.RANDOM, "a first visit picks a random map")
	var map := screen.find_child("Map", true, false) as Button
	assert_true(map != null, "the MAP button sits in the top bar")
	assert_true(map.text.contains("RANDOM"), "and says RANDOM (%s)" % map.text)
	var names: Array = GameLauncher.arena_choices().map(func(c: Dictionary) -> String: return String(c["name"]))
	assert_true(names.size() >= 2, "setup: the rotation has arenas (%s)" % [names])
	for expected: String in names:
		screen.cycle_arena()
		assert_eq(screen.arena, expected, "the next tap picks %s" % expected)
		assert_true(map.text.contains(GarageScreen.arena_title(expected).to_upper().trim_prefix("THE ")),
				"the button names it (%s)" % map.text)
	screen.cycle_arena()
	assert_eq(screen.arena, GarageScreen.RANDOM, "and after the last one, RANDOM again")


func test_his_last_map_is_remembered_like_his_last_army() -> void:
	var path := "user://test_garage_map_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var settings := GarageSettings.new(path)
	assert_eq(settings.last_arena, "", "nothing remembered yet")
	settings.remember_arena("gorge")
	assert_eq(GarageSettings.new(path).last_arena, "gorge", "a new garage reads his last pick back")
	settings.remember_arena(GarageScreen.RANDOM)
	assert_eq(GarageSettings.new(path).last_arena, GarageScreen.RANDOM, "and RANDOM is remembered as RANDOM, not the roll")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_the_garage_opens_on_the_carried_pick_else_the_command_line_else_his_last() -> void:
	var settings := GarageSettings.new("")
	settings.last_arena = "pit"
	assert_eq(GarageMode.opening_arena(LaunchFlags.parse([]), settings), "pit", "his last pick")
	assert_eq(GarageMode.opening_arena(LaunchFlags.parse(["--arena=gorge"]), settings), "gorge", "the command line's ARENA wins")
	assert_eq(GarageMode.opening_arena(LaunchFlags.parse(["--arena=gorge", "--garage-map=random"]), settings),
			GarageScreen.RANDOM, "a relaunch carries his pick (random), not the arena it rolled")
	assert_eq(GarageMode.opening_arena(LaunchFlags.parse(["--arena=random", "--garage-map-remembered"]), settings), "pit",
			"`make garage` without ARENA builds a random backdrop and opens on his last pick")
	assert_eq(GarageMode.opening_arena(LaunchFlags.parse([]), GarageSettings.new("")), GarageScreen.RANDOM, "else random")
	assert_eq(GarageMode.opening_arena(LaunchFlags.parse(["--arena=no_such_map"]), GarageSettings.new("")),
			GarageScreen.RANDOM, "a name that is no arena falls back to random")


func test_a_pick_that_is_not_the_built_arena_relaunches_into_the_fight_on_it() -> void:
	var current := LaunchFlags.parse(["--garage", "--garage-scratch", "--mute"])
	var next := GarageMode.relaunch_flags(current, "user://garage_scratch/a.json", "cpu", "law", 41, "gorge", GarageScreen.RANDOM)
	assert_eq(next.text("arena"), "gorge", "the relaunch builds the arena he fights on")
	assert_true(next.has("garage-rematch"), "and goes straight to the fight")
	assert_eq(next.text("garage-army"), "user://garage_scratch/a.json", "with the army he just saved")
	assert_eq(next.text("enemy-faction"), "law", "against the opponent he picked")
	assert_eq(next.text("seed"), "41", "on the same seed")
	assert_eq(next.text("garage-map"), GarageScreen.RANDOM, "carrying his pick, so the garage still says RANDOM after")
	assert_true(next.has("garage-scratch") and next.has("mute"), "keeping the carried flags")
	var looping := LaunchFlags.parse(["--garage", "--army-loop-auto=rematch,army,quit"])
	assert_eq(GarageMode.relaunch_flags(looping, "a.json", "cpu", "law", 41, "gorge", "gorge").text("army-loop-auto"),
			"rematch,army,quit", "a map relaunch is not a step of the automated loop")
