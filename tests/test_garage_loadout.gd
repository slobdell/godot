extends TestCase
## Garage GA0: the loadout model (costs, budget, validation) and its doctrine output, which the
## match must load unchanged. Most tests use a hand-made catalog with more classes, weapon costs,
## and components than the game ships today, proving the garage codes against the catalog's shape.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const TEST_DIR := "user://test_garage/"


func _catalog() -> GarageCatalog:
	var units := {
		"scout": {"display_name": "Scout", "cost": 120, "max_health": 180, "max_forward_speed": 14.0, "sight_radius": 110.0,
				"hardpoints": [{"id": "main", "accepts": ["cannon"]}], "component_slots": 1},
		"tank": {"display_name": "Tank", "cost": 200, "max_health": 400, "max_forward_speed": 9.0, "sight_radius": 75.0,
				"hardpoints": [{"id": "main", "accepts": ["cannon", "flamethrower"]}, {"id": "side", "accepts": ["flamethrower"]}],
				"component_slots": 2},
	}
	var weapons := {"cannon": {"cost": 0, "range": 70.0, "damage": 34.0, "reload": 2.5},
			"flamethrower": {"cost": 40, "range": 20.0, "damage_per_second": 45.0}}
	var components := {"heat_sink": {"display_name": "Heat sink", "cost": 30}, "ammo_rack": {"cost": 25}}
	return GarageCatalog.new(units, weapons, components, 1000)


func test_new_unit_mounts_the_first_accepted_weapon_everywhere() -> void:
	var loadout := Loadout.new(_catalog())
	var tank := loadout.new_unit("tank")
	assert_eq(tank["weapons"], {"main": "cannon", "side": "flamethrower"}, "every hardpoint starts armed")
	assert_eq(tank["weapon"], "cannon", "the doctrine's `weapon` mirrors the main hardpoint")
	assert_eq(loadout.unit_cost(tank), 240, "cost = chassis 200 + cannon 0 + flamethrower 40")


func test_costs_add_up_and_the_budget_refuses_overspending() -> void:
	var loadout := Loadout.new(_catalog())
	for i in 4:
		assert_eq(loadout.add_unit(0, "tank"), "", "tank %d fits the budget" % (i + 1))
	assert_eq(loadout.total_cost(), 960, "four armed tanks cost 960")
	var refusal := loadout.add_unit(0, "scout")
	assert_true(refusal.contains("budget"), "a fifth unit over budget is refused with a budget reason: %s" % refusal)
	assert_eq(loadout.unit_count(), 4, "the refused unit was not added")
	assert_eq(loadout.set_weapon(0, 0, "side", "cannon"), "The side hardpoint can't mount cannon.",
			"a hardpoint only takes weapons it accepts")
	assert_eq(loadout.set_weapon(0, 0, "main", "flamethrower"), "",
			"swapping to a pricier weapon within budget works (40 left)")
	assert_eq(loadout.unit_at(0, 0)["weapon"], "flamethrower", "`weapon` follows the main hardpoint")
	assert_true(loadout.add_component(0, 0, "heat_sink").contains("budget"), "no budget left for a heat sink")


func test_army_size_squads_and_component_slots_are_capped() -> void:
	var catalog := _catalog()
	catalog.budget = 100000
	var loadout := Loadout.new(catalog)
	for i in Doctrine.MAX_TANKS:
		assert_eq(loadout.add_unit(0, "scout"), "", "unit %d fits" % (i + 1))
	assert_true(loadout.add_unit(0, "scout").contains("full"), "the army stops at Doctrine.MAX_TANKS units")
	assert_eq(loadout.add_squad(), "", "a second squad")
	assert_eq(loadout.add_squad(), "", "a third squad")
	assert_true(loadout.add_squad() != "", "no fourth squad (Doctrine.MAX_SQUADS)")
	assert_eq(loadout.squad(1)["name"], "Bravo", "squads get the next phonetic name")
	assert_eq(loadout.add_component(0, 0, "heat_sink"), "", "a scout has one component slot")
	assert_true(loadout.add_component(0, 0, "ammo_rack") != "", "and no second one")


func test_problems_explain_what_blocks_a_fight() -> void:
	var loadout := Loadout.new(_catalog())
	loadout.add_squad()
	loadout.add_unit(0, "tank")
	var problems := loadout.problems()
	assert_true(Array(problems).any(func(p: String) -> bool: return p.contains("Bravo has no units")),
			"an empty squad is named: %s" % [problems])
	loadout.remove_squad(1)
	assert_true(loadout.is_ready(), "one armed tank in one squad is ready: %s" % [loadout.problems()])
	loadout.unit_at(0, 0)["weapons"]["side"] = "cannon"
	assert_true(Array(loadout.problems()).any(func(p: String) -> bool: return p.contains("can't mount")),
			"a hand-edited illegal weapon is caught: %s" % [loadout.problems()])
	loadout.unit_at(0, 0)["weapons"]["side"] = "flamethrower"
	loadout.unit_at(0, 0)["unit"] = "hovercraft"
	assert_true(Array(loadout.problems()).any(func(p: String) -> bool: return p.contains("unknown unit")),
			"an unknown unit class is caught")


func test_moving_units_between_squads() -> void:
	var loadout := Loadout.new(_catalog())
	loadout.add_squad()
	loadout.add_unit(0, "scout")
	loadout.add_unit(0, "tank")
	assert_eq(loadout.move_unit(0, 0, 1), "", "drag the scout to Bravo")
	assert_eq(loadout.squad(0)["tanks"].size(), 1, "Alpha keeps the tank")
	assert_eq(loadout.unit_at(1, 0)["unit"], "scout", "Bravo has the scout")


func test_hand_written_doctrines_import_with_loadout_fields() -> void:
	var loaded := Doctrine.load_file("res://doctrines/flame_rush.json")
	var loadout := Loadout.from_doctrine(GarageCatalog.from_game(), loaded["doctrine"])
	var burner := loadout.unit_at(0, 0)
	assert_eq(burner["unit"], "tank", "an old doctrine's tanks become the tank class")
	assert_eq(burner["weapons"], {"main": "flamethrower"}, "its weapon lands on the main hardpoint")
	assert_eq(loadout.total_cost(), 1000, "five tanks at 200 each")
	assert_true(loadout.is_ready(), "flame rush is a legal garage army: %s" % [loadout.problems()])


func test_game_catalog_builds_a_full_legal_army() -> void:
	var loadout := Loadout.new(GarageCatalog.from_game())
	loadout.add_squad()
	for i in 3:
		assert_eq(loadout.add_unit(0, loadout.catalog.unit_ids()[0]), "", "Alpha unit %d" % (i + 1))
	for i in 2:
		assert_eq(loadout.add_unit(1, loadout.catalog.unit_ids()[0]), "", "Bravo unit %d" % (i + 1))
	assert_true(loadout.is_ready(), "the shipped catalog + budget allow a full army: %s" % [loadout.problems()])


func test_round_trip_save_load_and_fight() -> void:
	var loadout := Loadout.new(_catalog())
	loadout.set_army_name("Night Raiders!")
	loadout.add_squad()
	loadout.add_unit(0, "tank")
	loadout.set_weapon(0, 0, "main", "flamethrower")
	loadout.add_component(0, 0, "heat_sink")
	loadout.set_paint(0, 0, "#c8a02a")
	loadout.set_unit_role(0, 0, "flanker")
	loadout.add_unit(1, "scout")
	loadout.set_formation(1, "line")
	loadout.set_squad_role(1, "scout")
	assert_true(loadout.is_ready(), "setup: the army is ready: %s" % [loadout.problems()])

	var stem := ArmyStore.slug(loadout.army["name"])
	assert_eq(stem, "night_raiders", "file names are slugs of the army name")
	var saved := ArmyStore.save(loadout.to_doctrine(), stem, TEST_DIR)
	assert_true(saved.has("path"), "the army saves: %s" % saved)
	var loaded := Doctrine.load_file(saved["path"])
	assert_true(loaded.has("doctrine"), "today's Doctrine.load_file accepts the garage file: %s" % loaded.get("error", ""))
	var listed := ArmyStore.list(TEST_DIR)
	assert_eq(listed.size(), 1, "the saved army is listed")
	assert_eq(listed[0]["name"], "Night Raiders!", "under its display name")

	var reopened := Loadout.from_doctrine(_catalog(), ArmyStore.read(saved["path"])["doctrine"])
	assert_eq(reopened.army, loadout.army, "reopening in the garage gives back the same army")
	assert_eq(reopened.unit_at(0, 0)["components"], ["heat_sink"], "components survive the round trip")
	assert_eq(loaded["doctrine"]["garage"]["cost"], 430, "the file records the army's cost")

	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, loaded["doctrine"]), "", "the match loads the garage army")
	var burner := game_match.tanks.get_node_or_null("Green_Alpha_1") as Tank
	assert_true(burner != null, "Alpha's tank spawned")
	if burner != null:
		assert_eq(burner.weapon_id, "flamethrower", "it fights with the weapon picked in the garage")
	assert_true(game_match.squads.has("0/Bravo"), "Bravo exists as a runtime squad")
	await wait_physics_frames(2)
	ArmyStore.remove(stem, TEST_DIR)
