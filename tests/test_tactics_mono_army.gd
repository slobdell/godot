extends TestCase
## B5 (round 40, balance; R40.6): the MONO army, a measurement control. `cpu:mono_<role>` deals a faction's units of one role
## only (his "100% tanks"), at the same budget, so a series can ask whether a mixed army beats it. Never a normal deal: it
## is not an archetype, so no seed ever rolls it, and the demo keeps it only when it is named on the command line.


func test_mono_tank_army_is_all_tanks_at_the_budget() -> void:
	for faction: String in Units.FACTIONS:
		var loaded := Army.load_army("cpu:mono_tank", 8501, Units.BASELINE_BUDGET, faction)
		assert_true(not loaded.has("error"), "%s mono_tank loads: %s" % [faction, loaded.get("error", "")])
		var army: Dictionary = loaded.get("doctrine", {})
		var entries := Doctrine.entries(army)
		assert_true(entries.size() > 0, "%s mono_tank has vehicles" % faction)
		for item: Dictionary in entries:
			var unit_id := String(item["entry"]["unit"])
			assert_eq(Units.role_of(unit_id), "tank", "%s mono_tank fields only tanks (%s)" % [faction, unit_id])
			assert_eq(Units.faction_of(unit_id), faction, "%s mono_tank fields its own faction's tank" % faction)
		var cost := Units.army_cost(army)
		var tank_cost := Units.cost_of(entries[0]["entry"])
		assert_true(cost <= Units.BASELINE_BUDGET, "%s mono_tank fits the budget (%d)" % [faction, cost])
		assert_true(entries.size() >= Army.MAX_ARMY_UNITS or cost > Units.BASELINE_BUDGET - tank_cost,
				"%s mono_tank spends all it can (%d)" % [faction, cost])


func test_mono_is_never_rolled_and_needs_a_faction_role() -> void:
	for faction: String in Units.FACTIONS:
		assert_true(not Array(Army.archetypes_for(faction)).any(func(a: String) -> bool: return a.begins_with("mono_")),
				"%s has no mono archetype to roll" % faction)
	assert_true(Army.load_army("cpu:mono_burner", 1, Units.BASELINE_BUDGET, "gangs").has("error"),
			"a role the faction doesn't field is an error")
	assert_true(Army.load_army("cpu:mono_wizard", 1, Units.BASELINE_BUDGET, "law").has("error"), "an unknown role is an error")


func test_demo_keeps_a_named_mono_lineup_only() -> void:
	var flags := LaunchFlags.new()
	flags.values = {"seed": "8501", "player": "cpu:mono_tank", "enemy": "cpu:law_line"}
	var demo := SkirmishMode.demo_flags(flags)
	assert_eq(demo.text("player"), "cpu:mono_tank", "the demo keeps a mono lineup named on the command line")
	assert_eq(demo.text("enemy"), "cpu", "any other lineup is still the demo's own deal")
