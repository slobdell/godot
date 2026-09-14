extends TestCase
## Garage stretch: shareable army codes (ArmyCode) and the SHARE panel.


func _future_catalog() -> GarageCatalog:
	var units := {"tank": {"cost": 200, "hardpoints": [{"id": "main", "accepts": ["cannon", "flamethrower"]},
			{"id": "side", "accepts": ["flamethrower", "laser"]}], "component_slots": 2}}
	var weapons := {"cannon": {"range": 70.0}, "flamethrower": {"range": 20.0}, "laser": {"range": 45.0}}
	return GarageCatalog.new(units, weapons, {"heat_sink": {"cost": 20}}, 2000)


func test_codes_round_trip_every_kind_of_army() -> void:
	var catalog := GarageCatalog.from_game()
	var armies: Array[Loadout] = [GarageScreen.starter_loadout(catalog), ArmyPresets.build("flamers", catalog, 3),
			ArmyPresets.build("turtle", catalog, 9, true),
			Loadout.from_doctrine(catalog, Doctrine.load_file("res://doctrines/anvil_hammer.json")["doctrine"])]
	for loadout in armies:
		var code := ArmyCode.encode(loadout)
		var decoded := ArmyCode.decode(code, catalog)
		assert_true(decoded.has("loadout"), "%s decodes: %s" % [loadout.army["name"], decoded.get("error", "")])
		if decoded.has("loadout"):
			var copy: Dictionary = loadout.army.duplicate(true)
			copy.erase("note")
			assert_eq((decoded["loadout"] as Loadout).army, copy, "%s survives the round trip" % loadout.army["name"])
		assert_true(code.length() < 400, "%s's code is short enough to paste (%d chars)" % [loadout.army["name"], code.length()])
		assert_true(code.is_valid_filename() and not code.contains("+") and not code.contains("/") and not code.contains("="),
				"codes are URL- and filename-safe: %s" % code)


func test_multi_hardpoint_components_paint_and_roles_survive() -> void:
	var catalog := _future_catalog()
	var loadout := Loadout.new(catalog)
	loadout.add_unit(0, "tank")
	loadout.set_weapon(0, 0, "side", "laser")
	loadout.add_component(0, 0, "heat_sink")
	loadout.set_paint(0, 0, "#3a8fd0")
	loadout.set_unit_role(0, 0, "scout")
	var decoded: Loadout = ArmyCode.decode(ArmyCode.encode(loadout), catalog)["loadout"]
	assert_eq(decoded.unit_at(0, 0), loadout.unit_at(0, 0), "weapons on both hardpoints, components, paint, and role survive")


func test_bad_codes_are_refused_politely() -> void:
	var catalog := GarageCatalog.from_game()
	var good := ArmyCode.encode(GarageScreen.starter_loadout(catalog))
	for bad in ["", "hello", "TS1", "TS1!!!!", good.substr(0, good.length() / 2), "TS1" + "A".repeat(5000)]:
		var decoded := ArmyCode.decode(bad, catalog)
		assert_true(decoded.has("error") and String(decoded["error"]).length() > 0, "'%s…' is refused with a reason" % bad.substr(0, 12))


func test_share_panel_copies_and_imports() -> void:
	tree.root.size = Vector2i(1280, 720)
	var screen := GarageScreen.new()
	screen.tutorial = GarageTutorial.new("")  # in memory: never the player's tips file
	screen.store_dir = "user://test_garage_codes/"
	add_to_tree(screen)
	await wait_physics_frames(2)
	var flamers := ArmyCode.encode(ArmyPresets.build("flamers", screen.loadout.catalog, 5, true))
	screen.toggle_share(true)
	var panel := screen.find_child("SharePanel", true, false) as Control
	assert_true(panel.visible, "SHARE opens the code panel")
	var edit := panel.find_child("CodeEdit", true, false) as LineEdit
	assert_eq(ArmyCode.decode(edit.text, screen.loadout.catalog)["loadout"].army, screen.loadout.army, "the panel shows this army's code")
	edit.text = "nonsense"
	(panel.find_child("Import", true, false) as Button).pressed.emit()
	assert_true(panel.visible and screen.toast_text().begins_with("Not an army code"), "a bad paste keeps the panel open and says why")
	edit.text = flamers
	(panel.find_child("Import", true, false) as Button).pressed.emit()
	await wait_physics_frames(1)
	assert_eq(String(screen.loadout.army["name"]), "Flamers #5", "a good paste imports the army")
	assert_true(not panel.visible, "and closes the panel")


func test_imported_cpu_armies_become_player_armies() -> void:
	tree.root.size = Vector2i(1280, 720)
	var screen := GarageScreen.new()
	screen.tutorial = GarageTutorial.new("")  # in memory: never the player's tips file
	screen.store_dir = "user://test_garage_codes/"
	add_to_tree(screen)
	await wait_physics_frames(2)
	assert_eq(screen.import_code(ArmyCode.encode(ArmyPresets.build("balanced", screen.loadout.catalog, 4))), "", "a CPU army code imports")
	for squad in screen.loadout.squads():
		assert_eq(squad.get("verb"), "hold", "%s waits for the player's orders" % squad["name"])
		assert_true(squad.has("formation"), "%s has a formation to form up in" % squad["name"])
		assert_true(not squad["directive"].has("objective"), "%s drops the CPU objective" % squad["name"])
