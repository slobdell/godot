extends TestCase
## Budgeted armies and seeded CPU compositions on catalog v2.


func test_cpu_armies_are_valid_affordable_and_seeded() -> void:
	for archetype: String in Army.ARCHETYPES:
		for budget in [500, 1000, 2000, 5000]:
			var army := Army.cpu_army("cpu:" + archetype, 7, budget)
			var parsed := Doctrine.parse(army)
			assert_true(parsed.has("doctrine"), "%s at %d is a valid doctrine: %s" % [archetype, budget, parsed.get("error", "")])
			assert_true(Units.army_cost(army) <= budget, "%s at %d fits the budget (%d)" % [archetype, budget, Units.army_cost(army)])
			# A plain cpu army (no faction) stops at Doctrine.MAX_UNITS; Army.MAX_ARMY_UNITS is the faction-army cap.
			var capped := Doctrine.entries(army).size() >= Doctrine.MAX_UNITS
			# L3 (round 4): "most of it" has to be measured against what this faction's cheapest vehicle costs. A
			# Syndicate army cannot spend the last 200 points of a 500 budget, because nothing it fields is that cheap.
			var cheapest := INF
			for unit_id: String in Army.ARCHETYPES[archetype]["units"]:
				cheapest = minf(cheapest, float(Units.cost_of({"unit": unit_id})))
			assert_true(capped or Units.army_cost(army) > budget - cheapest,
					"%s at %d spends all it can (%d, cheapest vehicle %d)" % [archetype, budget, Units.army_cost(army), cheapest])
	assert_eq(Army.cpu_army("cpu", 42), Army.cpu_army("cpu", 42), "the same seed builds the same army")
	var seen := {}
	for seed_value in 30:
		var army := Army.cpu_army("cpu", seed_value)
		seen[army["archetype"]] = true
		assert_eq(Units.faction_of(Doctrine.entries(army)[0]["entry"]["unit"]), Units.DEFAULT_FACTION,
				"a plain cpu army is still the default faction (%s)" % army["archetype"])
	assert_true(seen.size() >= 4, "different seeds pick different archetypes (%s)" % [seen.keys()])


func test_every_role_appears_in_some_cpu_army() -> void:
	var roles := {}
	for archetype: String in Army.ARCHETYPES:
		for item in Doctrine.entries(Army.cpu_army("cpu:" + archetype, 1, 1500)):
			roles[Units.role_of(item["entry"]["unit"])] = true
	for role: String in Units.ROLES:
		assert_true(roles.has(role), "CPU armies field %s units" % role)


func test_squads_fold_into_five_when_roles_overflow() -> void:
	var entries: Array = []
	for unit_id in ["scout", "scout", "tank", "ifv", "artillery", "lancer", "scout", "scout", "scout", "scout"]:
		entries.append({"unit": unit_id})
	var squads := Army.squads_for(entries)
	assert_true(squads.size() <= Doctrine.MAX_SQUADS, "at most %d squads (%d)" % [Doctrine.MAX_SQUADS, squads.size()])
	var total := 0
	for squad: Dictionary in squads:
		total += squad["units"].size()
		assert_true(squad["units"].size() <= Doctrine.MAX_SQUAD_UNITS, "%s holds at most 5" % squad["name"])
	assert_eq(total, entries.size(), "no unit is dropped")


func test_budget_checks_and_descriptions() -> void:
	var player: Dictionary = Doctrine.load_file("res://doctrines/player_default.json")["doctrine"]
	assert_eq(Army.check_budget(player, 1000), "", "the default player army fits 1000")
	assert_true(Army.check_budget(player, 700).contains("over"), "and not 700")
	assert_eq(Army.describe(Doctrine.load_file("res://doctrines/combined_arms.json")["doctrine"]),
			"1 scout, 3 tanks, 1 artillery (930 pts)", "a readable summary")
	assert_true(Army.load_army("cpu:siege", 3).has("doctrine"), "CPU names load like doctrine files")
	assert_true(Army.load_army("individuals", 3).has("doctrine"), "and so do doctrine names")


func test_every_doctrine_file_is_army_json_v2() -> void:
	for file_name in DirAccess.get_files_at("res://doctrines"):
		if file_name.ends_with(".json"):
			var loaded := Doctrine.load_file("res://doctrines/" + file_name)
			assert_true(loaded.has("doctrine"), "%s loads: %s" % [file_name, loaded.get("error", "")])
