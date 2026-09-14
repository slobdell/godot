extends TestCase
## Big armies (the lead, 2026-09-14: "maybe max 20"). Today's loader caps armies at 5 units / 3 squads, so
## these run against GarageCatalog.preview(): 20 units, 6 squads, at most 5 per squad.


func _units_per_squad(loadout: Loadout) -> Array:
	return loadout.squads().map(func(squad: Dictionary) -> int: return squad["tanks"].size())


func _open(screen_size := Vector2i(1280, 720)) -> GarageScreen:
	tree.root.size = screen_size
	var screen := GarageScreen.new()
	screen.settings = GarageSettings.new("")
	screen.store_dir = "user://test_garage_big/"
	screen.loadout = GarageScreen.starter_loadout(GarageCatalog.preview())
	add_to_tree(screen)
	await wait_physics_frames(3)
	return screen


func test_starter_fills_twenty_units_in_capped_squads() -> void:
	var loadout := GarageScreen.starter_loadout(GarageCatalog.preview())
	assert_eq(loadout.unit_count(), 20, "the starter buys a full 20-unit roster")
	assert_eq(_units_per_squad(loadout), [4, 4, 4, 4, 4], "in five squads of four")
	assert_eq(loadout.problems(), PackedStringArray(), "and follows every garage rule")
	var small := GarageScreen.starter_loadout(GarageCatalog.from_game())
	assert_eq(_units_per_squad(small), [3, 2], "today's 5-unit army still starts as 3 + 2")


func test_squads_are_capped_at_five() -> void:
	var loadout := Loadout.new(GarageCatalog.preview())
	for i in 5:
		assert_eq(loadout.add_unit(0, "scout"), "", "scout %d joins Alpha" % (i + 1))
	assert_true(loadout.add_unit(0, "scout").contains("full"), "a sixth is refused: a squad holds 5")
	loadout.add_squad()
	loadout.add_unit(1, "scout")
	assert_true(loadout.move_unit(1, 0, 0).contains("full"), "moving into a full squad is refused")
	loadout.squad(0)["tanks"].append(loadout.new_unit("scout"))
	assert_true(Array(loadout.problems()).any(func(p: String) -> bool: return p.contains("at most 5")),
			"a hand-edited oversized squad is a problem")
	for i in 8:
		loadout.add_squad()
	assert_eq(loadout.squads().size(), 6, "no more than 6 squads")


func test_archetypes_split_big_rosters_into_legal_squads() -> void:
	var catalog := GarageCatalog.preview()
	for archetype in ArmyPresets.ids():
		for for_player in [false, true]:
			var loadout := ArmyPresets.build(archetype, catalog, 2, for_player)
			assert_eq(loadout.problems(), PackedStringArray(), "%s (player %s) is legal: %s" % [archetype, for_player, loadout.problems()])
			assert_true(loadout.unit_count() >= 10, "%s spends the big budget (%d units)" % [archetype, loadout.unit_count()])
			assert_true(_units_per_squad(loadout).all(func(n: int) -> bool: return n >= 1 and n <= 5),
					"%s squads hold 1-5 units: %s" % [archetype, _units_per_squad(loadout)])
	var rush := ArmyPresets.build("rush", catalog, 2)
	assert_eq(rush.unit_count(), 20, "rush buys 20 fast scouts")
	assert_eq(rush.squads().size(), 4, "in four squads of five (one archetype squad, split)")


func test_add_spills_into_the_next_squad_with_room() -> void:
	var screen := await _open()
	screen.loadout.move_unit(4, 0, 0)
	screen.loadout.remove_unit(4, 0)
	assert_eq(_units_per_squad(screen.loadout), [5, 4, 4, 4, 2], "setup: Alpha is full, 19 units")
	screen.select_squad(0)
	assert_eq(screen.add_unit("scout"), "", "ADD with a full squad selected still works")
	assert_eq(_units_per_squad(screen.loadout), [5, 5, 4, 4, 2], "the unit went to the first squad with room")
	assert_eq(screen.selected_squad, 1, "and is selected there")
	assert_true(screen.toast_text().contains("added to Bravo"), "a toast says where it went: '%s'" % screen.toast_text())


func test_tap_menu_moves_a_unit_between_squads() -> void:
	var screen := await _open()
	screen.loadout.remove_unit(4, 0)
	screen.select_unit(0, 1)
	assert_true(screen.find_child("Squad", true, false) is OptionButton, "EQUIP has a Squad picker")
	assert_eq(screen.move_selected_unit(4), "", "pick Echo to move the unit there")
	assert_eq(_units_per_squad(screen.loadout), [3, 4, 4, 4, 4], "Alpha gave it to Echo")
	assert_eq([screen.selected_squad, screen.selected_unit], [4, 3], "the moved unit stays selected")
	screen.loadout.move_unit(2, 0, 1)
	assert_true(screen.move_selected_unit(1).contains("full"), "moving into a full squad explains why")


func test_twenty_units_fit_the_screen_by_wrapping_squads() -> void:
	for screen_size in [Vector2i(1280, 720), Vector2i(2400, 1080)]:
		var screen := await _open(screen_size)
		for panel: Control in screen.find_children("Squad_*", "Control", true, false):
			assert_true(panel.get_global_rect().end.x <= screen_size.x + 1.0,
					"%s fits across a %s screen (ends at %d)" % [panel.name, screen_size, panel.get_global_rect().end.x])
		var rows := {}
		for panel: Control in screen.find_children("Squad_*", "Control", true, false):
			rows[int(panel.global_position.y)] = true
		assert_true(rows.size() >= 2, "five squads wrap onto more than one row at %s" % screen_size)
		screen.free()


func test_preview_armies_cannot_fight_but_can_be_shared() -> void:
	var screen := await _open()
	var requests := []
	screen.fight_requested.connect(func(path: String, enemy: String) -> void: requests.append(path))
	assert_eq(screen.fight(), "", "FIGHT is refused for the preview catalog")
	assert_true(requests.is_empty() and screen.toast_text().contains("preview"), "with a reason: '%s'" % screen.toast_text())
	assert_true((screen.find_child("Problems", true, false) as Label).text.begins_with("PREVIEW"), "the status line doesn't say READY")
	var code := ArmyCode.encode(screen.loadout)
	assert_eq((ArmyCode.decode(code, screen.loadout.catalog)["loadout"] as Loadout).army, screen.loadout.army,
			"a 20-unit army survives an army code (%d chars)" % code.length())
