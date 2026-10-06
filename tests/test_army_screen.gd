extends TestCase
## The garage (round 19, G3) driven like a player: taps and drags pushed through the real viewport (so hit-testing, drag
## thresholds and drop targets are exercised), every gesture the screen offers, its refusals in words, the tap sizes,
## the faction switch, and the --garage mode's handover.

const TEST_DIR := "user://test_army_screen/"


func _open(screen_size := Vector2i(1280, 720)) -> GarageScreen:
	# Headless Godot's root viewport is 64×64 (trip-up #31): give it a real screen.
	tree.root.size = screen_size
	var screen := GarageScreen.new()
	screen.settings = GarageSettings.new("")  # in memory: never the player's tips file
	screen.progression = Progression.new("")  # nor their profile
	screen.store_dir = TEST_DIR
	add_to_tree(screen)
	await wait_physics_frames(3)
	return screen


func _find(root: Control, pattern: String) -> Control:
	var found := root.find_children(pattern, "Control", true, false)
	return found[0] if not found.is_empty() else null


func _squad(screen: GarageScreen, index: int) -> Control:
	return _find(screen, "Squad_%d" % index)


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func _mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = position
	event.global_position = position
	tree.root.push_input(event)


## Scroll a column so `control` is on screen, as a player would before tapping it.
func _reveal(control: Control) -> void:
	var node := control.get_parent()
	while node != null:
		if node is ScrollContainer:
			(node as ScrollContainer).ensure_control_visible(control)
			await wait_physics_frames(2)
			return
		node = node.get_parent()


func _tap(control: Control) -> void:
	assert_true(control != null, "there is something to tap")
	if control == null:
		return
	await _reveal(control)
	_mouse(_center(control), true)
	_mouse(_center(control), false)
	await wait_physics_frames(2)


## Press on `from`, slide in steps, release on `to`: what a finger drag delivers via mouse emulation.
func _drag(from: Control, to: Control) -> void:
	await _reveal(from)
	var start := _center(from)
	var end := _center(to)
	_mouse(start, true)
	for step in range(1, 11):
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = start.lerp(end, step / 10.0)
		motion.global_position = motion.position
		motion.relative = (end - start) / 10.0
		tree.root.push_input(motion)
		await tree.process_frame
	_mouse(end, false)
	await wait_physics_frames(2)


func _meter(screen: GarageScreen) -> CyberMeter:
	return _find(screen, "Credits") as CyberMeter


func test_a_first_visit_opens_on_a_ready_army_and_1000_credits() -> void:
	var screen := await _open()
	assert_eq(screen.faction, "condemned", "the first faction on show is the Condemned")
	assert_eq(screen.draft.catalog.budget, 1000, "with 1000 credits")
	assert_true(screen.draft.unit_count() > 0 and screen.draft.is_ready(), "and the suggested army, ready to FIGHT")
	assert_true(not (_find(screen, "Fight") as Button).disabled, "FIGHT is live")
	assert_eq(_meter(screen).value, 1000 - screen.draft.total_cost(), "the meter shows exactly what is left")
	for unit_id: String in Units.roster("condemned"):
		var card := _find(screen, "Card_" + unit_id)
		assert_true(card != null, "the %s has a card" % unit_id)
		var price := card.find_child("Price", true, false) as Label
		assert_eq(price.text, "%d CR" % Credits.of_unit(unit_id), "the %s's card shows its price in credits" % unit_id)
	assert_true(screen.draft.squads().size() <= 5, "at most five squads")


func test_tap_a_card_buys_one_and_the_meter_drops_by_its_price() -> void:
	var screen := await _open()
	await _tap(_find(screen, "Clear"))
	assert_eq(screen.draft.unit_count(), 0, "CLEAR sells everything")
	assert_eq(_meter(screen).value, 1000, "and the meter is full")
	await _tap(_find(screen, "Card_tank"))
	assert_eq(screen.draft.unit_count(), 1, "one tap buys one")
	assert_eq(_meter(screen).value, 1000 - Credits.of_unit("tank"), "the meter drops by the tank's price")
	assert_true(screen.toast_text().contains("Bought a Tank"), "and says so: %s" % screen.toast_text())


func test_a_card_he_cannot_afford_refuses_in_words() -> void:
	var screen := await _open()
	await _tap(_find(screen, "Clear"))
	while screen.draft.remaining_budget() >= Credits.of_unit("artillery"):
		assert_eq(screen.buy("artillery"), "", "setup: spend the money")
	var before := screen.draft.unit_count()
	await _tap(_find(screen, "Card_artillery"))
	assert_eq(screen.draft.unit_count(), before, "nothing was bought")
	assert_true(screen.toast_text().contains("costs %d CR" % Credits.of_unit("artillery")) and screen.toast_text().contains("CR left"),
			"and the reason is in credits: %s" % screen.toast_text())


func test_tap_a_vehicle_then_tap_it_again_sells_it() -> void:
	var screen := await _open()
	var before := screen.draft.unit_count()
	var unit_id := String(screen.draft.unit_at(0, 0)["unit"])
	var left := screen.draft.remaining_budget()
	await _tap(_squad(screen, 0).find_child("Unit_0", true, false))
	assert_eq(screen.picked, [0, 0], "the first tap picks the vehicle up")
	assert_true((_squad(screen, 0).find_child("Unit_0", true, false) as CyberPictureChip).caption.text.begins_with("SELL"),
			"and the chip offers the sale")
	assert_eq(screen.draft.unit_count(), before, "nothing sold yet")
	await _tap(_squad(screen, 0).find_child("Unit_0", true, false))
	assert_eq(screen.draft.unit_count(), before - 1, "the second tap sells it")
	assert_eq(screen.draft.remaining_budget(), left + Credits.of_unit(unit_id), "for its full price")


func test_tap_a_vehicle_then_tap_another_squad_moves_it() -> void:
	var screen := await _open()
	assert_true(screen.draft.squads().size() >= 2, "setup: the suggested army has two squads or more")
	var unit_id := String(screen.draft.unit_at(0, 0)["unit"])
	var sizes := [screen.draft.units_of(0).size(), screen.draft.units_of(1).size()]
	if sizes[1] >= 5:
		screen.sell(1, 0)
		sizes[1] -= 1
	await _tap(_squad(screen, 0).find_child("Unit_0", true, false))
	await _tap(_squad(screen, 1).find_child("Header", true, false))
	assert_eq(screen.draft.units_of(1).size(), sizes[1] + 1, "the second squad gained it")
	assert_eq(String(screen.draft.units_of(1).back()["unit"]), unit_id, "the same vehicle")
	assert_eq(screen.picked, [], "and it was put down")


func test_drag_a_vehicle_onto_another_squad_moves_it() -> void:
	var screen := await _open()
	await _tap(_find(screen, "Clear"))
	screen.buy("tank")
	screen.buy("scout")
	await _tap(_find(screen, "AddSquad"))
	assert_eq(screen.draft.squads().size(), 2, "setup: a second, empty squad")
	await _drag(_squad(screen, 0).find_child("Unit_1", true, false), _squad(screen, 1))
	assert_eq(screen.draft.units_of(1).size(), 1, "the dropped vehicle joined the second squad")
	assert_eq(String(screen.draft.unit_at(1, 0)["unit"]), "scout", "it is the scout")
	assert_eq(screen.draft.units_of(0).size(), 1, "and left the first")


func test_drag_a_vehicle_onto_the_vehicles_sells_it() -> void:
	var screen := await _open()
	var before := screen.draft.unit_count()
	var left := screen.draft.remaining_budget()
	var unit_id := String(screen.draft.unit_at(0, 0)["unit"])
	await _drag(_squad(screen, 0).find_child("Unit_0", true, false), _find(screen, "Vehicles"))
	assert_eq(screen.draft.unit_count(), before - 1, "dragged back to the vehicles, it is sold")
	assert_eq(screen.draft.remaining_budget(), left + Credits.of_unit(unit_id), "for its price")


func test_drag_a_card_onto_a_squad_buys_it_there() -> void:
	var screen := await _open()
	await _tap(_find(screen, "Clear"))
	screen.buy("tank")
	await _tap(_find(screen, "AddSquad"))
	await _tap(_squad(screen, 0).find_child("Header", true, false))
	assert_eq(screen.selected_squad, 0, "setup: buys go to the first squad")
	assert_eq(screen.draft.squads().size(), 1, "and selecting it dropped the empty second squad")
	await _tap(_find(screen, "AddSquad"))
	await _drag(_find(screen, "Card_lancer"), _squad(screen, 1))
	assert_eq(String(screen.draft.unit_at(1, 0).get("unit", "")), "lancer", "a card dropped on a squad buys into it")


func test_a_new_squad_takes_the_next_buys_and_an_empty_one_goes_away() -> void:
	var screen := await _open()
	await _tap(_find(screen, "Clear"))
	screen.buy("tank")
	var squads := 1
	await _tap(_find(screen, "AddSquad"))
	assert_eq(screen.draft.squads().size(), squads + 1, "+ NEW SQUAD adds one")
	assert_eq(screen.selected_squad, squads, "and selects it")
	if screen.draft.remaining_budget() < Credits.of_unit("scout"):
		screen.sell(0, 0)
	await _tap(_find(screen, "Card_scout"))
	assert_eq(String(screen.draft.unit_at(squads, 0).get("unit", "")), "scout", "the next buy lands in the new squad")
	await _tap(_find(screen, "AddSquad"))
	await _tap(_squad(screen, 0).find_child("Header", true, false))
	assert_eq(screen.draft.squads().size(), squads + 1, "an empty squad left behind disappears")


func test_a_full_squad_spills_into_the_next() -> void:
	var screen := await _open()
	await _tap(_find(screen, "Clear"))
	for i in 5:
		screen.buy("scout")
	assert_eq(screen.draft.units_of(0).size(), 5, "setup: the first squad is full")
	await _tap(_squad(screen, 0).find_child("Header", true, false))
	await _tap(_find(screen, "Card_scout"))
	assert_eq(screen.draft.squads().size(), 2, "a buy into a full squad opens the next")
	assert_true(screen.toast_text().contains("was full"), "and says why it went elsewhere: %s" % screen.toast_text())


func test_fight_is_refused_with_the_reason_in_words() -> void:
	var screen := await _open()
	await _tap(_find(screen, "Clear"))
	var fight := _find(screen, "Fight") as Button
	assert_true(fight.disabled, "an empty army cannot FIGHT")
	assert_true(screen.toast_text().contains("Buy a vehicle"), "and the line says what to do: %s" % screen.toast_text())
	assert_eq(screen.fight(), "", "fight() refuses too")
	# Over budget: an army opened from a file that costs more than 1000 credits (an edited save, an older tier).
	var squads: Array = []
	for name in ["Alpha", "Bravo", "Charlie", "Delta", "Echo"]:
		squads.append({"name": name, "units": [{"unit": "artillery"}, {"unit": "artillery"}, {"unit": "artillery"},
				{"unit": "artillery"}, {"unit": "artillery"}]})
	var over := ArmyDraft.new(screen.draft.catalog, {"name": "Too Big", "squads": squads})
	screen._adopt(over, "")
	screen._refresh()
	await wait_physics_frames(1)
	assert_true(fight.disabled, "an army over 1000 credits cannot FIGHT")
	var by := 25 * Credits.of_unit("artillery") - 1000
	assert_true(screen.toast_text().contains("Over budget by %d CR" % by), "and the line says by how much: %s" % screen.toast_text())
	assert_eq(_meter(screen).readout(), "OVER BY %d CR" % by, "so does the meter")


func test_a_faction_tap_switches_roster_and_each_keeps_its_army() -> void:
	var screen := await _open()
	await _tap(_find(screen, "Clear"))
	screen.buy("tank")
	await _tap(_find(screen, "Faction_law"))
	assert_eq(screen.faction, "law", "a tap picks the Law")
	assert_eq(screen.draft.catalog.faction, "law", "the catalog is the Law's")
	assert_true(_find(screen, "Card_law_tank") != null and _find(screen, "Card_tank") == null, "its vehicles, not the Condemned's")
	assert_true(screen.draft.is_ready(), "a faction he has not built for opens on its suggested army")
	await _tap(_find(screen, "Faction_condemned"))
	assert_eq(screen.draft.unit_count(), 1, "back to the Condemned: the army he left (one tank) is still there")


func test_vs_cycles_random_and_every_faction() -> void:
	var screen := await _open()
	var vs := _find(screen, "Opponent") as Button
	assert_eq(vs.text, "VS RANDOM", "the CPU starts random")
	var seen: Array = []
	for i in Units.FACTIONS.size() + 1:
		await _tap(vs)
		seen.append(screen.enemy_faction)
	assert_eq(seen, Array(Units.FACTIONS) + [GarageScreen.RANDOM], "each faction in turn, then random again")
	for seed_value in 40:
		for player: String in Units.FACTIONS:
			assert_true(GarageMode.resolve_enemy_faction("random", seed_value, player) != player, "random is never a mirror")
	assert_eq(GarageMode.resolve_enemy_faction("syndicate", 3, "syndicate"), "syndicate", "a picked faction is kept")


func test_tap_targets_are_phone_sized() -> void:
	var screen := await _open(Vector2i(2400, 1080))
	screen.clear()  # one squad, so + NEW SQUAD shows (a full suggested army has five squads)
	screen.buy("tank")
	await wait_physics_frames(1)
	assert_near(screen.ui_scale, 1.0, 0.01, "a 1080-tall desktop screen is the 1080p reference")
	for control: Control in [_find(screen, "Fight"), _find(screen, "Card_tank"), _squad(screen, 0).find_child("Unit_0", true,
			false), _squad(screen, 0).find_child("Header", true, false), _find(screen, "AddSquad"), _find(screen, "Clear"),
			_find(screen, "Faction_law"), _find(screen, "Opponent")]:
		assert_true(control != null and control.size.y >= 48.0, "%s is at least 48 px tall at 1080p (%s)" % [
				control.name if control != null else "?", control.size.y if control != null else "missing"])
	var fight := _find(screen, "Fight")
	assert_true(fight.get_global_rect().end.x <= 2400.0 and fight.get_global_rect().end.y <= 1080.0, "FIGHT is on screen")
	var meter := _meter(screen)
	assert_true(meter.get_global_rect().end.y <= 1080.0 * 0.15, "the credits are at the top, always in view")


func test_a_full_army_says_so() -> void:
	var screen := await _open()
	await _tap(_find(screen, "Faction_gangs"))
	await _tap(_find(screen, "Clear"))
	for i in 25:
		assert_eq(screen.buy("gang_scout"), "", "setup: scout %d of 25" % (i + 1))
	# Round 20 (R1), his rule: five squads of five Gangs scouts is exactly the 1000 credits.
	assert_eq(screen.draft.unit_count(), 25, "the gangs' 25 scouts fill five squads of five")
	assert_eq(screen.draft.remaining_budget(), 0, "and spend every credit")
	assert_true(screen.toast_text().begins_with("Your army is full") and screen.toast_text().contains("every credit spent"),
			"the line says the army is full and every credit is spent: %s" % screen.toast_text())
	# A budget bigger than the slots (his later "more credits") says the money can't be spent.
	var rich := ArmyDraft.new(screen.draft.catalog.with_budget(1100), screen.draft.to_doctrine())
	assert_true(GarageScreen.full_line(rich).contains("100 CR left can't be spent"), GarageScreen.full_line(rich))
	var error := screen.buy("gang_scout")
	assert_true(error.begins_with("Your army is full"), "a buy says the same: %s" % error)
	await _tap(_squad(screen, 0).find_child("Unit_0", true, false))
	await _tap(_squad(screen, 0).find_child("Unit_0", true, false))
	assert_eq(screen.draft.unit_count(), 24, "selling one makes room")
	assert_true(not screen.army_full(), "and the army is no longer full")


func test_the_share_line_carries_the_army_and_opens_with_its_faction() -> void:
	var screen := await _open()
	await _tap(_find(screen, "Faction_syndicate"))
	var code := (_find(screen, "ShareCode") as LineEdit).text
	assert_true(code.begins_with(ArmyCode.PREFIX), "the line holds the army code: %s" % code.left(12))
	var opened := GarageMode.open_code(code)
	assert_true(opened.has("draft"), "the code opens: %s" % opened.get("error", ""))
	assert_eq((opened["draft"] as ArmyDraft).catalog.faction, "syndicate", "as a Syndicate army")
	assert_eq((opened["draft"] as ArmyDraft).unit_count(), screen.draft.unit_count(), "every vehicle in it")
	assert_true(GarageMode.open_code(code.left(code.length() - 3)).has("error"), "a cut-off code is refused in words")


func test_a_spent_army_says_so() -> void:
	var screen := await _open()
	await _tap(_find(screen, "Faction_law"))
	await _tap(_find(screen, "Clear"))
	for i in 12:
		assert_eq(screen.buy("law_scout"), "", "setup: Law scout %d of 12" % (i + 1))
	# Round 20 (R1): an all-scout Law army is 12 (960 CR); the credits run out before the slots.
	assert_eq(screen.draft.unit_count(), 12, "twelve Law scouts")
	assert_true(not screen.army_full(), "with slots left")
	assert_true(screen.toast_text().begins_with("Your credits have run out") and screen.toast_text().contains("40 CR left"),
			"the last buy's line says the credits ran out and what is left: %s" % screen.toast_text())
	assert_true(screen.buy("law_scout").begins_with("Not enough credits"), "a thirteenth is refused for the money")
	assert_true(GarageScreen.spent_line(ArmyDraft.new(ArmyCatalog.for_game("law").with_budget(0))).begins_with(
			"Every credit is spent"), "nothing left: every credit is spent")


func test_garage_flag_chooses_the_garage_mode() -> void:
	assert_true(GameMode.choose(LaunchFlags.parse(["--garage"])) is GarageMode, "--garage opens the garage")
	assert_true(GameMode.choose(LaunchFlags.parse(["--match", "--garage"])) is MatchRunnerMode, "the match runner still wins")


func test_a_resize_rebuild_keeps_the_army_and_the_selection() -> void:
	var screen := await _open()
	await _tap(_find(screen, "Clear"))
	screen.buy("tank")
	await _tap(_find(screen, "AddSquad"))
	var squads := screen.draft.squads().size()
	var selected := screen.selected_squad
	tree.root.size = Vector2i(2400, 1080)
	await wait_physics_frames(3)
	assert_near(screen.ui_scale, 1.0, 0.01, "setup: the screen rebuilt at the new scale")
	assert_eq([screen.draft.squads().size(), screen.selected_squad], [squads, selected], "the same army, the same squad")


# ---- Saving policy ----------------------------------------------------------------------------

const SAVE_DIR := "user://test_army_saving/"
const SETTINGS_PATH := "user://test_army_saving.cfg"


func _clean_saves() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	for file_name in DirAccess.get_files_at(SAVE_DIR):
		DirAccess.remove_absolute(SAVE_DIR.path_join(file_name))
	DirAccess.remove_absolute(SETTINGS_PATH)


func _open_with(settings: GarageSettings) -> GarageScreen:
	tree.root.size = Vector2i(1280, 720)
	var screen := GarageScreen.new()
	screen.settings = settings
	screen.store_dir = SAVE_DIR
	add_to_tree(screen)
	await wait_physics_frames(2)
	return screen


func test_fight_saves_a_loadable_army_and_the_garage_reopens_on_it() -> void:
	_clean_saves()
	var screen := await _open_with(GarageSettings.new(SETTINGS_PATH))
	screen.set_faction("gangs")
	await wait_physics_frames(1)
	var fought := screen.fight()
	var fought_units := screen.draft.unit_count()
	assert_true(fought != "", "FIGHT saved the army")
	var loaded := ArmyStore.read(fought)
	var parsed := Doctrine.parse(ArmyFormat.to_game_doctrine(loaded["doctrine"]))
	assert_true(parsed.has("doctrine"), "the match's loader takes it: %s" % parsed.get("error", ""))
	assert_eq(String(loaded["doctrine"]["garage"]["faction"]), "gangs", "the file says its faction")
	assert_true(Units.army_cost(loaded["doctrine"]) <= Credits.game_points(), "and fits 1000 credits in points")
	screen.queue_free()
	await wait_physics_frames(1)
	var again := await _open_with(GarageSettings.new(SETTINGS_PATH))
	assert_eq(again.faction, "gangs", "the next visit opens on the Road Gangs")
	assert_eq(again.army_path, fought, "tied to its file")
	assert_eq(again.draft.unit_count(), fought_units, "with the army he fought with")
	assert_eq(again.save(), fought, "and a save updates that file, no duplicate")
	assert_eq(ArmyStore.list(SAVE_DIR).size(), 1, "one file")
	_clean_saves()


func test_rematch_reopens_another_factions_army_whole() -> void:
	_clean_saves()
	var law := GarageSuggest.draft(ArmyCatalog.for_game("law"))
	var path := String(ArmyStore.save(law.to_doctrine(), "law_army", SAVE_DIR)["path"])
	var opened := GarageMode.open_saved(path)
	assert_true(opened != null, "the saved Law army opens")
	assert_eq(opened.catalog.faction, "law", "with the Law's catalog")
	assert_eq(opened.unit_count(), law.unit_count(), "every vehicle kept (read through the Condemned catalog it lost them all)")
	assert_true(opened.is_ready(), "and it can fight, so REMATCH fights")
	var card := GarageMode.loader_card(LaunchFlags.parse(["--garage", "--garage-army=" + path]))
	assert_true(String(card.get("line", "")).contains("1000 CR"), "the loader names it at its price: %s" % card.get("line", ""))
	_clean_saves()


func test_a_round_18_save_opens_in_credits() -> void:
	_clean_saves()
	var old := {"name": "Old Army", "squads": [{"name": "Alpha", "formation": "wedge", "verb": "hold",
			"directive": {"role": "assault"}, "units": [{"unit": "tank"}, {"unit": "tank"}, {"unit": "ifv"}]}],
			"garage": {"schema": 2, "budget": 1200, "cost": 550, "tier": 1}}
	var path := String(ArmyStore.save(old, "old_army", SAVE_DIR)["path"])
	var settings := GarageSettings.new("")
	settings.last_army = path
	var screen := await _open_with(settings)
	assert_eq(screen.faction, "condemned", "an old save is a Condemned army")
	assert_eq(screen.draft.total_cost(), 316, "priced in credits: 115 + 115 + 86")
	assert_eq(_meter(screen).value, 684, "with 684 left")
	_clean_saves()


## Round 20 (R4): on the phone (touch scale, the 20:9 window garage-shots uses) five squads of pictured chips fit the
## squads panel without scrolling, and a vehicle chip is still a full tap target. The round-19 phone scrolled.
func test_on_the_phone_five_squads_fit_without_scrolling() -> void:
	var before := CyberStyle.touch_boost()
	CyberStyle.set_touch_boost(1.5)
	var screen := await _open(Vector2i(1800, 810))
	await _tap(_find(screen, "Faction_gangs"))
	await wait_physics_frames(3)
	assert_eq(screen.draft.squads().size(), 5, "setup: the Gangs' suggestion is five squads")
	var squads := _find(screen, "Squads")
	var scroll := squads.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	var bar := scroll.get_v_scroll_bar()
	assert_true(bar.max_value <= bar.page + 1.0, "the five squads fit the panel: content %d px, panel %d px" % [bar.max_value,
			bar.page])
	var chip := _squad(screen, 0).find_child("Unit_0", true, false) as CyberPictureChip
	assert_true(chip.size.y >= CyberKit.TAP * CyberKit.s(screen) - 1.0, "a chip is one tap target tall (%s)" % chip.size)
	assert_true(not chip.caption.visible, "the chip is its picture alone (the name is on its card)")
	await _tap(chip)
	var picked := _squad(screen, 0).find_child("Unit_0", true, false) as CyberPictureChip
	assert_true(picked.caption.visible and picked.caption.text.begins_with("SELL"), "picked up, it says SELL")
	CyberStyle.set_touch_boost(before)
