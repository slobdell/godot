extends TestCase
## Control X5 (L3): pick a faction per side in skirmish. Army SIZE has to fall out of the faction's costs, not
## out of a number somebody typed, and every automated run must keep starting the match it always did.

func _frames(count := 2) -> void:
	for i in count:
		await tree.process_frame


func _flags(values: Dictionary) -> LaunchFlags:
	var flags := LaunchFlags.new()
	flags.values = values
	return flags


# ---- What each side fields ----------------------------------------------------------------------------------

func test_a_faction_raises_the_budget_so_size_comes_from_the_roster() -> void:
	var plain := SkirmishMode.lineup_plan("player_default", "cpu", "", "", 0)
	assert_eq(int(plain["budget"]), Units.DEFAULT_BUDGET, "no faction, no change: round 3's small skirmish")
	var faction := SkirmishMode.lineup_plan("player_default", "cpu", "gangs", "", 0)
	assert_eq(int(faction["budget"]), Units.BASELINE_BUDGET, "a faction is fought at the baseline budget")
	assert_eq(faction[Match.Team.GREEN]["faction"], "gangs", "on the side that named it")
	assert_eq(faction[Match.Team.GREEN]["lineup"], "cpu", "whose army is built from that faction's archetypes")
	assert_eq(faction[Match.Team.RUST]["faction"], "", "and not on the other")
	var chosen := SkirmishMode.lineup_plan("my_army", "cpu", "law", "syndicate", 0)
	assert_eq(chosen[Match.Team.GREEN]["lineup"], "my_army", "a named army is kept even with a faction")
	assert_eq(chosen[Match.Team.RUST]["faction"], "syndicate", "each side picks its own")
	assert_eq(int(SkirmishMode.lineup_plan("player_default", "cpu", "gangs", "", 2500)["budget"]), 2500,
			"--budget still wins")


func test_the_factions_field_the_sizes_the_lead_asked_for() -> void:
	var sizes := {}
	for option: Dictionary in FactionPicker.options(Units.BASELINE_BUDGET):
		sizes[option["faction"]] = int(option["units"])
	assert_eq(sizes.size(), Units.FACTIONS.size(), "every faction can field an army")
	print("MEASURE control_faction_sizes %s" % [sizes])
	# The lead: "the gang is diluted with cheaper units, so it should be a bigger swarm, the condemned have more
	# expensive and smaller unit counts from there, then the law ... and the syndicate would have the fewest".
	assert_true(int(sizes["gangs"]) > int(sizes["condemned"]), "the gangs swarm (%s vs %s)" % [sizes["gangs"], sizes["condemned"]])
	assert_true(int(sizes["condemned"]) > int(sizes["law"]), "then the Condemned (%s vs %s)" % [sizes["condemned"], sizes["law"]])
	assert_true(int(sizes["law"]) > int(sizes["syndicate"]), "then the Law (%s vs %s)" % [sizes["law"], sizes["syndicate"]])
	assert_true(int(sizes["condemned"]) >= 25 and int(sizes["condemned"]) <= 35,
			"the mid faction is around the lead's 30 a side (%s)" % sizes["condemned"])


func test_every_option_says_what_it_fields() -> void:
	for option: Dictionary in FactionPicker.options(Units.BASELINE_BUDGET):
		assert_true(String(option["name"]) != String(option["faction"]), "%s has a display name" % option["faction"])
		assert_true(int(option["units"]) > 0, "%s fields something" % option["faction"])
		assert_true(float(option["average_cost"]) > 0.0, "%s has a cost per vehicle" % option["faction"])
		assert_true(String(option["summary"]).length() > 3, "%s says what it brings: %s" % [option["faction"], option["summary"]])


# ---- The menu -----------------------------------------------------------------------------------------------

func test_the_menu_opens_for_a_player_and_never_for_an_automated_run() -> void:
	# Headless is what every smoke test, playtest and match run uses, and none of them may stop for a menu.
	assert_true(not SkirmishMode.wants_faction_menu(_flags({"skirmish": ""})), "headless runs never open it")
	assert_true(SkirmishMode.wants_faction_menu(_flags({"skirmish": "", "pick-faction": ""})),
			"--pick-faction opens it anywhere")
	for automated in ["scripted", "control-playtest", "command-playtest", "touch-map"]:
		assert_true(not SkirmishMode.wants_faction_menu(_flags({"skirmish": "", "pick-faction": "", automated: ""})),
				"--%s starts the match it always did" % automated)
	assert_true(not SkirmishMode.wants_faction_menu(_flags({"skirmish": "", "pick-faction": "", "no-pick-faction": ""})),
			"--no-pick-faction wins")
	assert_true(not SkirmishMode.wants_faction_menu(_flags({"skirmish": "", "pick-faction": "", "player-faction": "gangs",
			"no-pick-faction": ""})), "naming a faction skips the menu")


func test_picking_sides_and_confirming() -> void:
	tree.root.size = Vector2i(1280, 720)
	var picker := FactionPicker.new()
	add_to_tree(picker)
	await _frames(2)
	var got: Array = []
	picker.chosen.connect(func(mine: String, theirs: String) -> void: got.append([mine, theirs]))
	assert_eq(picker.player_faction, Units.DEFAULT_FACTION, "it starts on the default faction")
	picker.set_side("gangs", false)
	picker.set_side("syndicate", true)
	assert_eq(picker.player_faction, "gangs", "1-4 picks yours")
	assert_eq(picker.enemy_faction, "syndicate", "shift+1-4 picks theirs")
	picker.set_side("nonsense", false)
	assert_eq(picker.player_faction, "gangs", "a faction that doesn't exist is ignored")
	picker.confirm()
	assert_eq(got, [["gangs", "syndicate"]], "confirming reports both sides once")


func test_the_menu_restarts_the_skirmish_with_what_you_picked() -> void:
	var launched := _flags({"skirmish": "", "pick-faction": "", "seed": "7", "enemy": "cpu"})
	var next := SkirmishMode.faction_flags(launched, "law", "gangs")
	assert_eq(next.text("player-faction"), "law", "your faction goes on the command line")
	assert_eq(next.text("enemy-faction"), "gangs", "and theirs")
	assert_eq(next.text("seed"), "7", "the flags it was launched with are carried over")
	assert_eq(next.text("enemy"), "cpu", "all of them")
	assert_true(not next.has("pick-faction"), "the menu does not open again")
	assert_true(next.has("no-pick-faction"), "explicitly, so a default-on menu stays shut too")
	assert_true(not SkirmishMode.wants_faction_menu(next), "which is what the restart checks")


func test_clicking_a_row_picks_that_side() -> void:
	tree.root.size = Vector2i(1280, 720)
	var picker := FactionPicker.new()
	add_to_tree(picker)
	await _frames(3)
	var row := picker.row_rect("law", false)
	assert_true(row.size.x > 20.0, "the rows have a real size on screen (%s)" % row)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = row.get_center()
	event.global_position = row.get_center()
	tree.root.push_input(event)
	await _frames(1)
	assert_eq(picker.player_faction, "law", "left-clicking a row takes that faction")
	var enemy_row := picker.row_rect("syndicate", true)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = enemy_row.get_center()
	right.global_position = enemy_row.get_center()
	tree.root.push_input(right)
	await _frames(1)
	assert_eq(picker.enemy_faction, "syndicate", "right-clicking the other half gives it to the enemy")


## Round 5 (the lead: "I can't actually click any of the first buttons"): the menu starts the match with a click, not
## only with a key the player has to read about first.
func test_clicking_fight_starts_the_match() -> void:
	tree.root.size = Vector2i(1280, 720)
	var picker := FactionPicker.new()
	add_to_tree(picker)
	await _frames(3)
	var got: Array = []
	picker.chosen.connect(func(mine: String, theirs: String) -> void: got.append([mine, theirs]))
	var fight := picker.fight_rect()
	assert_true(fight.size.x >= 150.0 and fight.size.y >= 44.0, "FIGHT is a real button, big enough to hit (%s)" % fight)
	assert_true(Rect2(Vector2.ZERO, picker.size).encloses(fight), "and on screen")
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = fight.get_center()
		event.global_position = fight.get_center()
		tree.root.push_input(event)
		await _frames(1)
	assert_eq(got, [[Units.DEFAULT_FACTION, Units.DEFAULT_FACTION]], "clicking FIGHT confirms once")


## Drawing the menu reuses its options instead of assembling four armies per redraw (measured 1.1 ms on builder0).
func test_the_menu_builds_its_options_once() -> void:
	tree.root.size = Vector2i(1280, 720)
	var picker := FactionPicker.new()
	add_to_tree(picker)
	await _frames(2)
	var first: Array = picker.choices()
	picker.set_side("gangs", false)
	await _frames(2)
	assert_true(is_same(first, picker.choices()), "the options are computed once and reused across redraws")


## X6 (arena's request): the menu picks the arena too, and says what fight each one is for.
func test_the_menu_offers_the_arenas_with_what_each_is_for() -> void:
	var choices := GameLauncher.arena_choices()
	var names: Array = choices.map(func(c: Dictionary) -> String: return c["name"])
	for kit_built in ["yard", "boulevard", "pit", "boneyard"]:
		assert_true(names.has(kit_built), "%s is offered (%s)" % [kit_built, names])
	for choice: Dictionary in choices:
		assert_true(String(choice["title"]) != "" and String(choice["note"]) != "", "%s has a title and a note" % choice["name"])
	tree.root.size = Vector2i(1280, 720)
	var picker := FactionPicker.new()
	add_to_tree(picker)
	await _frames(3)
	assert_eq(picker.arena, GameLauncher.RANDOM, "random by default")
	var row := picker.arena_rect()
	assert_true(row.has_area() and Rect2(Vector2.ZERO, picker.size).encloses(row), "the arena row is on screen (%s)" % row)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = row.get_center()
	event.global_position = row.get_center()
	tree.root.push_input(event)
	await _frames(1)
	assert_eq(picker.arena, names[0], "a click steps to the first arena")
	var right := event.duplicate() as InputEventMouseButton
	right.button_index = MOUSE_BUTTON_RIGHT
	tree.root.push_input(right)
	await _frames(1)
	assert_eq(picker.arena, GameLauncher.RANDOM, "a right-click steps back")


func test_the_arena_choice_reaches_the_restarted_match() -> void:
	var launched := _flags({"skirmish": "", "pick-faction": "", "seed": "7"})
	var next := SkirmishMode.faction_flags(launched, "law", "gangs", "pit")
	assert_eq(next.text("arena"), "pit", "the arena goes on the flags")
	var random := GameLauncher.resolve_arena(SkirmishMode.faction_flags(launched, "law", "gangs", GameLauncher.RANDOM))
	assert_eq(random.text("arena"), Arena.resolve_name(GameLauncher.RANDOM, 7), "Arena's own roll decides, from the match's seed")
	var seeded := GameLauncher.with_seed(_flags({"skirmish": ""}))
	assert_true(seeded.text("seed").is_valid_int(), "a launch without a seed gets one, so the roll can be replayed")
	assert_eq(GameLauncher.with_seed(launched).text("seed"), "7", "and keeps the one it has")
	var names: Array = GameLauncher.arena_choices().map(func(c: Dictionary) -> String: return c["name"])
	assert_true(names.has(random.text("arena")), "random resolves to a real arena (%s)" % random.text("arena"))
	assert_eq(GameLauncher.resolve_arena(SkirmishMode.faction_flags(launched, "law", "gangs", GameLauncher.RANDOM)).text("arena"),
			random.text("arena"), "the same seed picks the same arena")
	assert_eq(GameLauncher.resolve_arena(_flags({"skirmish": ""})).values, {"skirmish": ""}, "no arena flag, nothing changes")
	var main := GameLauncher.instantiate(next)
	assert_eq(String(main.get_node("Arena").get("layout_name")), "pit", "the new scene's arena builds the chosen layout")
	main.free()
