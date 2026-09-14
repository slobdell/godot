extends TestCase
## Garage stretch: readable trade-offs and the comparison tables (GarageAdvice).


func _catalog() -> GarageCatalog:
	var units := {
		"scout": {"cost": 120, "max_health": 180, "max_forward_speed": 14.0, "hardpoints": [{"id": "main", "accepts": ["laser"]}],
				"component_slots": 0},
		"tank": {"cost": 200, "max_health": 400, "max_forward_speed": 9.0,
				"hardpoints": [{"id": "main", "accepts": ["cannon", "laser", "flamethrower"]}], "component_slots": 1},
	}
	var weapons := {"cannon": {"damage": 34.0, "reload": 2.5, "range": 70.0, "ammo": 30},
			"laser": {"damage": 12.0, "reload": 0.5, "range": 45.0, "heat_per_shot": 8.0, "cost": 15},
			"flamethrower": {"damage_per_second": 45.0, "range": 20.0}}
	var components := {"heat_sink": {"cost": 20, "heat_dissipation": 4.0}, "ammo_rack": {"cost": 15, "ammo_bonus": 10}}
	return GarageCatalog.new(units, weapons, components, 1000)


func _has(hints: PackedStringArray, text: String) -> bool:
	return Array(hints).any(func(hint: String) -> bool: return hint.contains(text))


func test_a_laser_boat_is_told_it_needs_heat_sinks() -> void:
	var catalog := _catalog()
	var loadout := Loadout.new(catalog)
	loadout.add_unit(0, "tank")
	loadout.set_weapon(0, 0, "main", "laser")
	assert_true(_has(GarageAdvice.tradeoffs(catalog, loadout.unit_at(0, 0)), "add a heat sink"), "a laser tank with a free slot is told to add a heat sink")
	loadout.add_component(0, 0, "heat_sink")
	assert_true(_has(GarageAdvice.tradeoffs(catalog, loadout.unit_at(0, 0)), "your heat sink helps"), "and credited once it has one")
	loadout.add_unit(0, "scout")
	assert_true(_has(GarageAdvice.tradeoffs(catalog, loadout.unit_at(0, 1)), "can't carry heat sinks"), "a slotless laser scout is warned")


func test_cannons_mention_ammo_and_flamers_mention_range() -> void:
	var catalog := _catalog()
	var loadout := Loadout.new(catalog)
	loadout.add_unit(0, "tank")
	assert_true(_has(GarageAdvice.tradeoffs(catalog, loadout.unit_at(0, 0)), "finite ammo: consider extra ammo"), "a cannon build is told about ammo")
	loadout.set_weapon(0, 0, "main", "flamethrower")
	assert_true(_has(GarageAdvice.tradeoffs(catalog, loadout.unit_at(0, 0)), "close range"), "a flamethrower is flagged as close range")
	# Catalog v2 (rules R1): the game's units have fixed weapons and no hardpoints, so the game-catalog half of
	# this test moved to the army stream's rebuild of the garage.


func test_comparison_tables_highlight_the_best() -> void:
	var catalog := _catalog()
	var weapons := GarageAdvice.weapon_table(catalog)
	assert_eq(weapons["headers"], ["", "Cost", "Dmg/s", "Hit", "Range", "Reload", "Ammo", "Heat/shot"], "only columns some weapon has, plus derived damage/s")
	var cannon: Array = weapons["rows"][0]
	assert_eq(cannon[0], "Cannon", "weapons sorted by id")
	assert_eq(cannon[2], "13.6", "cannon damage/s = 34 / 2.5")
	assert_true(weapons["best"][1][2], "the flamethrower has the best damage/s")
	assert_true(weapons["best"][0][4], "the cannon has the best range")
	var game_weapons := GarageAdvice.weapon_table(GarageCatalog.from_game())
	var flamer_row: Array = game_weapons["rows"].filter(func(row: Array) -> bool: return row[0] == "Flamethrower")[0]
	assert_eq(flamer_row[game_weapons["headers"].find("Reload")], "-", "a continuous weapon shows no reload (not a 'best' 0)")
	assert_true(weapons["best"][0][1] and not weapons["best"][2][1], "free weapons tie for cheapest; the laser isn't")
	var units := GarageAdvice.unit_table(catalog)
	assert_eq(units["rows"][0][0], "Scout", "units cheapest first")
	assert_true(units["best"][0][1], "the scout is the cheapest")
	assert_true(units["best"][1][2], "the tank has the most hull")


func test_compare_panel_opens_from_the_units_column() -> void:
	tree.root.size = Vector2i(1280, 720)
	var screen := GarageScreen.new()
	screen.settings = GarageSettings.new("")  # in memory: never the player's tips file
	screen.store_dir = "user://test_garage_advice/"
	add_to_tree(screen)
	await wait_physics_frames(2)
	(screen.find_child("Compare", true, false) as Button).pressed.emit()
	var panel := screen.find_child("ComparePanel", true, false) as Control
	assert_true(panel.visible, "COMPARE opens the tables")
	assert_true(panel.find_child("WeaponTable", true, false) != null, "with a weapon table")
	(panel.find_child("Close", true, false) as Button).pressed.emit()
	assert_true(not panel.visible, "CLOSE hides it")


# ---- First-run tips and paint (kept here: small, same "readability" stretch) --------------------

const TIPS_PATH := "user://test_garage_tips.cfg"


func test_tips_advance_with_the_player_and_are_remembered() -> void:
	DirAccess.remove_absolute(TIPS_PATH)
	tree.root.size = Vector2i(1280, 720)
	var screen := GarageScreen.new()
	screen.store_dir = "user://test_garage_advice/"
	screen.settings = GarageSettings.new(TIPS_PATH)
	add_to_tree(screen)
	await wait_physics_frames(2)
	var tip := screen.find_child("TipBar", true, false) as Control
	assert_true(tip.visible and screen.settings.tip().begins_with("TIP 1/3"), "a first visit shows tip 1")
	screen.select_unit(1, 0)
	assert_true(screen.settings.tip().begins_with("TIP 2/3"), "selecting a unit moves to tip 2")
	screen.select_unit(0, 1)
	assert_true(screen.settings.tip().begins_with("TIP 2/3"), "selecting again doesn't skip tip 2")
	screen.loadout.set_paint(0, 1, "#c8a02a")  # catalog v2: no weapon picks; paint is an edit too
	assert_true(screen.settings.tip().begins_with("TIP 3/3"), "an edit moves to tip 3")
	assert_eq(GarageSettings.new(TIPS_PATH).step, 2, "progress is saved")
	(screen.find_child("SkipTips", true, false) as Button).pressed.emit()
	assert_true(not tip.visible, "X hides the tips")
	assert_eq(GarageSettings.new(TIPS_PATH).take_match_tips(), [], "skipping also skips the skirmish tips")
	DirAccess.remove_absolute(TIPS_PATH)


func test_skirmish_tips_come_once() -> void:
	DirAccess.remove_absolute(TIPS_PATH)
	assert_eq(GarageSettings.new(TIPS_PATH).take_match_tips().size(), GarageSettings.MATCH_TIPS.size(), "the first skirmish gets the tips")
	assert_eq(GarageSettings.new(TIPS_PATH).take_match_tips(), [], "later ones don't")
	DirAccess.remove_absolute(TIPS_PATH)


func test_painted_tanks_wear_their_paint_in_the_match() -> void:
	# Match applies doctrine paint itself (Tank.set_paint → slot set_paint); the team stays an accent
	# (Tank.set_team_accent → slot set_team_color), the lead's "friend or foe by accent lights" rule.
	add_to_tree(preload("res://game/arena/arena.tscn").instantiate())
	var game_match: Match = preload("res://game/match/match.tscn").instantiate()
	add_to_tree(game_match)
	var loadout := GarageScreen.starter_loadout(GarageCatalog.from_game())
	loadout.set_paint(1, 0, "#d04a8c")
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, loadout.to_doctrine()), "", "setup: the army loads")
	await wait_physics_frames(3)
	var painted: Node = (game_match.tanks.get_node("Green_Bravo_1") as Tank).get_node("HullVisual").visual
	var plain: Node = (game_match.tanks.get_node("Green_Alpha_1") as Tank).get_node("HullVisual").visual
	if "paint_color" in painted:  # the cyberpunk theme; `default` boxes show team colors only
		assert_true((painted.get("paint_color") as Color).is_equal_approx(Color.html("#d04a8c")), "Bravo's first tank wears the pink paint")
		assert_true((painted.get("team_color") as Color).is_equal_approx(GameTheme.team_color(Match.Team.GREEN)), "and keeps Green's accent lights")
		assert_eq((plain.get("paint_color") as Color).a, 0.0, "unpainted tanks keep the theme's default body")
