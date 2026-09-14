extends TestCase
## Directive set 2: budgeted armies and seeded CPU compositions.


func test_cpu_armies_are_valid_affordable_and_seeded() -> void:
	for archetype: String in Army.ARCHETYPES:
		for budget in [500, 1000, 2000]:
			var army := Army.cpu_army("cpu:" + archetype, 7, budget)
			var parsed := Doctrine.parse(army)
			assert_true(parsed.has("doctrine"), "%s at %d is a valid doctrine: %s" % [archetype, budget, parsed.get("error", "")])
			assert_true(Units.army_cost(army) <= budget, "%s at %d fits the budget (%d)" % [archetype, budget, Units.army_cost(army)])
			assert_true(Units.army_cost(army) >= budget - 150, "%s at %d spends most of it (%d)" % [archetype, budget, Units.army_cost(army)])
	assert_eq(Army.cpu_army("cpu", 42), Army.cpu_army("cpu", 42), "the same seed builds the same army")
	var seen := {}
	for seed_value in 30:
		seen[Army.cpu_army("cpu", seed_value)["archetype"]] = true
	assert_true(seen.size() >= 4, "different seeds pick different archetypes (%s)" % [seen.keys()])


func test_leftover_points_buy_heat_sinks_for_lasers_first() -> void:
	var found_laser := false
	for seed_value in 20:
		var army := Army.cpu_army("cpu:recon_strike", seed_value, 1000)
		for squad in army["squads"]:
			for entry in squad["tanks"]:
				if entry.get("weapon") == "laser" and entry.has("components"):
					found_laser = true
					assert_eq(entry["components"][0], "heat_sink", "a laser's first component is a heat sink (%s)" % [entry])
	assert_true(found_laser, "setup: some recon strike armies carried upgraded lasers")


func test_budget_checks_and_descriptions() -> void:
	var five_tanks: Dictionary = Doctrine.load_file("res://doctrines/player_default.json")["doctrine"]
	assert_eq(Army.check_budget(five_tanks, 1000), "", "the default player army (5 tanks) fits 1000")
	assert_true(Army.check_budget(five_tanks, 900).contains("over"), "and not 900")
	assert_eq(Army.describe(Doctrine.load_file("res://doctrines/combined_arms.json")["doctrine"]),
			"3 tanks, 1 scout, 1 artillery (930 pts)", "a readable summary")
	assert_true(Army.load_army("cpu:siege", 3).has("doctrine"), "CPU names load like doctrine files")
	assert_true(Army.load_army("individuals", 3).has("doctrine"), "and so do doctrine names")
