extends TestCase
## Garage GA4: seeded, budget-constrained army archetypes (CPU opponents and garage presets).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


## A richer catalog than the game ships: a fast scout, a tough tank, a heat weapon, and components.
func _future_catalog() -> GarageCatalog:
	var units := {
		"scout": {"cost": 120, "max_health": 180, "max_forward_speed": 14.0,
				"hardpoints": [{"id": "main", "accepts": ["cannon", "laser"]}], "component_slots": 1},
		"tank": {"cost": 200, "max_health": 400, "max_forward_speed": 9.0,
				"hardpoints": [{"id": "main", "accepts": ["cannon", "flamethrower", "laser"]}], "component_slots": 1},
		"brute": {"cost": 260, "max_health": 700, "max_forward_speed": 6.0,
				"hardpoints": [{"id": "main", "accepts": ["cannon"]}], "component_slots": 0},
	}
	var weapons := {"cannon": {"range": 70.0, "ammo": 30}, "flamethrower": {"range": 20.0},
			"laser": {"range": 45.0, "heat_per_shot": 12.0, "cost": 10}}
	var components := {"heat_sink": {"cost": 20, "heat_dissipation": 4.0}, "ammo_rack": {"cost": 15, "ammo_bonus": 10}}
	return GarageCatalog.new(units, weapons, components, 1200)


func _units(loadout: Loadout) -> Array:
	var result := []
	for squad in loadout.squads():
		result.append_array(squad["tanks"])
	return result


func test_every_archetype_is_a_legal_full_army_for_the_game_catalog() -> void:
	var catalog := GarageCatalog.from_game()
	for archetype in ArmyPresets.ids():
		for seed_value in [1, 2, 3]:
			var loadout := ArmyPresets.build(archetype, catalog, seed_value)
			assert_true(loadout.is_ready(), "%s seed %d is legal: %s" % [archetype, seed_value, loadout.problems()])
			assert_true(loadout.total_cost() <= catalog.budget, "%s stays within budget" % archetype)
			var cheapest := loadout.unit_cost(loadout.new_unit(catalog.unit_ids()[0]))
			assert_true(loadout.unit_count() >= 1 and (loadout.unit_count() == catalog.max_units or loadout.remaining_budget() < cheapest),
					"%s spends the budget (%d units, %d left)" % [archetype, loadout.unit_count(), loadout.remaining_budget()])


func test_same_seed_same_army_and_seeds_vary() -> void:
	var catalog := GarageCatalog.from_game()
	var differs := false
	for archetype in ArmyPresets.ids():
		assert_eq(ArmyPresets.build(archetype, catalog, 7).to_doctrine(), ArmyPresets.build(archetype, catalog, 7).to_doctrine(),
				"%s is deterministic for a seed" % archetype)
		for seed_value in range(1, 6):
			if ArmyPresets.build(archetype, catalog, seed_value).squads() != ArmyPresets.build(archetype, catalog, seed_value + 1).squads():
				differs = true
	assert_true(differs, "different seeds give different armies")


func test_flamers_burn_and_turtles_do_not() -> void:
	var catalog := GarageCatalog.from_game()
	var flamers := _units(ArmyPresets.build("flamers", catalog, 1)).filter(func(t: Dictionary) -> bool: return t["weapon"] == "flamethrower")
	assert_true(flamers.size() >= 2, "flamers mount the short-range weapon across the flank (%d burners)" % flamers.size())
	var turtle_flames := _units(ArmyPresets.build("turtle", catalog, 1)).filter(func(t: Dictionary) -> bool: return t["weapon"] == "flamethrower")
	assert_eq(turtle_flames.size(), 0, "turtles keep long-range guns")


func test_archetypes_resolve_preferences_against_any_catalog() -> void:
	var catalog := _future_catalog()
	var rush := ArmyPresets.build("rush", catalog, 1)
	assert_eq(rush.problems(false), PackedStringArray(), "rush follows the garage rules on the future catalog")
	assert_eq(_units(rush)[0]["unit"], "scout", "rush prefers the fastest class")
	var turtle := ArmyPresets.build("turtle", catalog, 1)
	assert_eq(turtle.problems(false), PackedStringArray(), "turtle follows the garage rules on the future catalog")
	assert_true(_units(turtle).any(func(t: Dictionary) -> bool: return t["unit"] == "brute"), "turtle buys the toughest class")
	assert_true(_units(turtle).all(func(t: Dictionary) -> bool: return t["weapon"] == "cannon"), "turtle mounts the longest range")
	var flamers := ArmyPresets.build("flamers", catalog, 1)
	assert_eq(_units(flamers)[0]["unit"], "tank", "flamers build on the workhorse (the class with the most weapon options)")
	assert_true(_units(flamers).filter(func(t: Dictionary) -> bool: return t["weapon"] == "flamethrower").size() >= 3,
			"and arm the flank with its shortest-range weapon")


func test_components_match_the_weapons_they_serve() -> void:
	var catalog := _future_catalog()
	var loadout := Loadout.new(catalog, {"name": "probe", "squads": []})
	loadout.add_squad()
	loadout.add_unit(0, "tank")
	loadout.set_weapon(0, 0, "main", "laser")
	loadout.add_unit(0, "tank")
	ArmyPresets._fit_components(loadout, "cheapest")
	assert_eq(loadout.unit_at(0, 0)["components"], ["heat_sink"], "a laser tank gets a heat sink")
	assert_eq(loadout.unit_at(0, 1)["components"], ["ammo_rack"], "a cannon tank gets an ammo rack")


func test_player_presets_hold_without_objectives() -> void:
	for archetype in ArmyPresets.ids():
		for squad in ArmyPresets.build(archetype, GarageCatalog.from_game(), 1, true).squads():
			assert_eq(squad.get("verb"), "hold", "%s preset squads wait for the player's orders" % archetype)
			assert_true(not squad["directive"].has("objective"), "%s preset squads have no CPU objective" % archetype)
	for archetype in ArmyPresets.ids():
		for squad in ArmyPresets.build(archetype, GarageCatalog.from_game(), 1).squads():
			assert_true(not squad.has("verb"), "%s CPU squads don't wait for orders" % archetype)
			# Found by the archetype match series: a doctrine formation alone makes a squad hold at base.
			assert_true(not squad.has("formation"), "%s CPU squads carry no formation (it would hold them at base)" % archetype)


func test_cpu_armies_load_into_a_match() -> void:
	# The garage's CPU opponents are gameplay's Army archetypes (one generator for garage, skirmish, runner).
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	for entry in GarageScreen.ENEMIES:
		var value: String = entry[0]
		if value.begins_with("cpu:"):
			assert_true(Army.ARCHETYPES.has(value.trim_prefix("cpu:")), "%s is one of Army.ARCHETYPES" % value)
		var loaded := Army.load_army(value, 3)
		assert_true(loaded.has("doctrine"), "%s loads: %s" % [value, loaded.get("error", "")])
	var siege := Army.load_army("cpu:siege", 3)
	assert_eq(game_match.load_doctrine(Match.Team.RUST, siege["doctrine"]), "", "the match loads a CPU army")
	assert_true(game_match.team_tanks(Match.Team.RUST).size() >= 3, "and its units spawn")
	await wait_physics_frames(2)


func test_garage_preset_menu_rolls_a_new_variation_each_pick() -> void:
	tree.root.size = Vector2i(1280, 720)
	var screen := GarageScreen.new()
	screen.settings = GarageSettings.new("")  # in memory: never the player's tips file
	screen.store_dir = "user://test_garage_presets/"
	add_to_tree(screen)
	await wait_physics_frames(2)
	screen.apply_preset("flamers")
	var first := screen.loadout.army.duplicate(true)
	assert_true(screen.loadout.is_ready(), "the preset is ready to fight")
	assert_eq(String(first["name"]), "Flamers #1", "named after the archetype and its seed")
	screen.apply_preset("flamers")
	assert_eq(String(screen.loadout.army["name"]), "Flamers #2", "picking again rolls the next seed")
	screen.apply_preset("starter")
	assert_eq(screen.loadout.unit_count(), GarageScreen.starter_loadout(screen.loadout.catalog).unit_count(), "Starter is back on the menu")
