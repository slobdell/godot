extends TestCase
## L3 (round 4 combat X1/X4): faction rosters. Every unit in the catalog belongs to a faction, each faction fields
## the same roles with its own costs and stats, and a budget buys a faction army whose SIZE falls out of those
## costs (the lead: gangs swarm, then the Condemned, then the Law, and the Syndicate fields the fewest).
##
## X1 ships the schema with only the Condemned in it, so the per-faction checks run over the factions that HAVE a
## roster (`_playable()`) and tighten by themselves as X4 fills the other three.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


## Factions with units in the catalog, in Units.FACTIONS order.
func _playable() -> PackedStringArray:
	var found: PackedStringArray = []
	for faction: String in Units.FACTIONS:
		if not Units.roster(faction).is_empty():
			found.append(faction)
	return found


func test_the_schema_names_all_four_factions() -> void:
	assert_eq(Units.FACTIONS, ["condemned", "gangs", "law", "syndicate"], "the four factions of game_design.md")
	for faction: String in Units.FACTIONS:
		assert_true(Units.FACTION_NAMES.has(faction), "%s has a display name" % faction)
	assert_true(_playable().has("condemned"), "and the Condemned are playable")


func test_every_unit_belongs_to_a_known_faction() -> void:
	for unit_id in Units.ids():
		var faction := Units.faction_of(unit_id)
		assert_true(Units.FACTIONS.has(faction), "%s is in a known faction (%s)" % [unit_id, faction])
		assert_true(Units.roster(faction).has(unit_id), "%s is listed in its faction's roster" % unit_id)


func test_the_condemned_are_todays_roster() -> void:
	var condemned := Units.roster("condemned")
	for unit_id in ["scout", "tank", "ifv", "artillery", "lancer", "burner"]:
		assert_true(condemned.has(unit_id), "the Condemned keep the %s" % unit_id)
	assert_eq(Units.DEFAULT_FACTION, "condemned", "and are the default faction (round-3 armies keep working)")
	assert_eq(Units.faction_of(Units.DEFAULT), "condemned", "including the unit a bare spawn drives")


func test_an_unknown_faction_has_an_empty_roster_rather_than_a_surprise() -> void:
	assert_eq(Units.roster("wardens").size(), 0, "no units for a faction that doesn't exist")
	assert_eq(Units.faction_of("no_such_unit"), "", "and no faction for a unit that doesn't exist")
	assert_near(Units.roster_average_cost("wardens"), 0.0, 0.001, "and no average cost to divide a budget by")


func test_every_playable_faction_fills_the_core_roles() -> void:
	for faction in _playable():
		var roles := {}
		for unit_id in Units.roster(faction):
			roles[Units.role_of(unit_id)] = true
		for role in ["scout", "tank", "ifv", "artillery"]:
			assert_true(roles.has(role), "%s fields a %s (counters stay learnable across factions)" % [faction, role])
		assert_true(roles.size() >= 5, "%s has at least five roles, including its special (%s)" % [faction, roles.keys()])


func test_a_faction_army_spends_its_budget_on_its_own_units() -> void:
	for faction in _playable():
		var loaded := Army.load_army("cpu", 3, Units.BASELINE_BUDGET, faction)
		assert_true(not loaded.has("error"), "a %s army builds: %s" % [faction, loaded.get("error", "")])
		var doctrine: Dictionary = loaded["doctrine"]
		var entries := Doctrine.entries(doctrine)
		assert_true(not entries.is_empty(), "%s bought something" % faction)
		for item in entries:
			assert_eq(Units.faction_of(item["entry"]["unit"]), faction,
					"a %s army only fields %s units" % [faction, faction])
		assert_true(Units.army_cost(doctrine) <= Units.BASELINE_BUDGET,
				"%s stays inside the budget (%d)" % [faction, Units.army_cost(doctrine)])
		assert_true(entries.size() <= Army.MAX_ARMY_UNITS, "%s stays inside the unit cap (%d)" % [faction, entries.size()])


func test_unit_counts_fall_out_of_cost_in_the_order_the_lead_asked_for() -> void:
	# "the gang is diluted with cheaper units, so it should be a bigger swarm, the condemned have more expensive and
	# smaller unit counts from there, then the law … and the syndicate would have the fewest."
	# The lead's order, biggest army first. Units.FACTIONS is in catalog order (the default faction leads), which is
	# deliberately NOT this.
	var by_size := ["gangs", "condemned", "law", "syndicate"]
	var playable := _playable()
	var sizes := {}
	for faction in playable:
		sizes[faction] = Army.typical_size(faction, Units.BASELINE_BUDGET)
		assert_true(sizes[faction] > 0, "%s buys vehicles at the baseline budget" % faction)
	print("MEASURE faction_sizes at %d points: %s" % [Units.BASELINE_BUDGET, sizes])
	var ranked: Array = by_size.filter(func(faction: String) -> bool: return sizes.has(faction))
	for index in range(1, ranked.size()):
		var bigger: String = ranked[index - 1]
		var smaller: String = ranked[index]
		assert_true(sizes[bigger] > sizes[smaller], "%s outnumbers %s (%d vs %d)"
				% [bigger, smaller, sizes[bigger], sizes[smaller]])
	assert_true(sizes["condemned"] >= 26 and sizes["condemned"] <= 36,
			"the mid faction lands near the lead's 30 a side at the baseline budget (%d)" % sizes["condemned"])


func test_a_real_army_is_about_as_big_as_the_costs_promise() -> void:
	for faction in _playable():
		var built := Doctrine.entries(Army.load_army("cpu", 5, Units.BASELINE_BUDGET, faction)["doctrine"]).size()
		var expected := Army.typical_size(faction, Units.BASELINE_BUDGET)
		assert_true(built >= expected / 2 and built <= Army.MAX_ARMY_UNITS,
				"%s fields %d vehicles where its costs promise about %d" % [faction, built, expected])


func test_a_faction_army_is_seeded_and_repeatable() -> void:
	var first: Dictionary = Army.load_army("cpu", 9, Units.BASELINE_BUDGET, "condemned")["doctrine"]
	var again: Dictionary = Army.load_army("cpu", 9, Units.BASELINE_BUDGET, "condemned")["doctrine"]
	assert_eq(Army.describe(first), Army.describe(again), "the same seed buys the same army")
	var varied := {}
	for seed_value in 12:
		var army: Dictionary = Army.load_army("cpu", seed_value, Units.BASELINE_BUDGET, "condemned")["doctrine"]
		varied[army["archetype"]] = true
	assert_true(varied.size() >= 3, "different seeds pick different archetypes (%s)" % [varied.keys()])


func test_a_named_archetype_must_belong_to_the_faction() -> void:
	var missing := Army.load_army("cpu", 1, Units.BASELINE_BUDGET, "wardens")
	assert_true(missing.has("error"), "an unknown faction is an error, not a silent Condemned army")
	assert_true(String(missing["error"]).contains("wardens"), "and it says which: %s" % missing["error"])
	var right := Army.load_army("cpu:armor", 1, Units.BASELINE_BUDGET, "condemned")
	assert_true(not right.has("error"), "a faction's own archetype works: %s" % right.get("error", ""))
	for faction in _playable():
		if faction == "condemned":
			continue
		var wrong := Army.load_army("cpu:armor", 1, Units.BASELINE_BUDGET, faction)
		assert_true(wrong.has("error"), "the Condemned's Armor archetype is not a %s army" % faction)


func test_an_army_bigger_than_five_squads_still_obeys_every_other_doctrine_rule() -> void:
	var squads: Array = []
	for index in 8:
		squads.append({"name": "S%d" % index, "units": [{"unit": "tank"}]})
	assert_true(Army.parse_scaled({"name": "Big", "squads": squads}).has("doctrine"),
			"eight squads is a legal faction army (Doctrine.MAX_SQUADS is a player-UI cap)")
	squads.append({"name": "S0", "units": [{"unit": "tank"}]})
	assert_true(Army.parse_scaled({"name": "Big", "squads": squads}).has("error"),
			"but duplicate squad names are still rejected across the whole army")
	assert_true(Army.parse_scaled({"name": "Big", "squads": [{"name": "A", "units": [{"unit": "no_such_unit"}]}]}).has("error"),
			"and so is an unknown unit")
	assert_true(Army.parse_scaled({"name": "Big", "squads": [{"name": "A", "units": [{"unit": "tank", "weapon": "cannon"}]}]}).has("error"),
			"and so are v1 keys")


func test_faction_units_spawn_and_fight() -> void:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var faction: String = _playable()[-1]
	var loaded := Army.load_army("cpu", 2, 900, faction)
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, loaded["doctrine"]), "", "a %s army loads into a match" % faction)
	await wait_physics_frames(2)
	var spawned := game_match.team_tanks(Match.Team.GREEN)
	assert_true(not spawned.is_empty(), "and its units exist")
	for unit in spawned:
		assert_eq(Units.faction_of(unit.unit_id), faction, "%s is a %s vehicle" % [unit.unit_id, faction])
		assert_true(unit.max_health > 0 and unit.max_forward_speed > 0.0, "%s has real stats" % unit.unit_id)
		assert_true(Weapons.exists(unit.weapon_id), "%s carries a real weapon (%s)" % [unit.unit_id, unit.weapon_id])
