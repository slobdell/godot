extends TestCase
## Round 40 (native N3, R40.2): a balance candidate's absolute stats (`--unit-overrides=<json>`, Units.apply_overrides) land in
## the same tuning as `--tune=`, and a tuned cost prices the army (Units.cost_of, army_cost, the CPU's deal).


func teardown() -> void:
	Units.tuning.clear()
	Weapons.tuning.clear()
	super()


func _unit() -> String:
	return Units.roster("gangs")[0]


func test_a_valid_document_writes_units_weapons_and_armor() -> void:
	var unit := _unit()
	var weapon := String(Units.PROFILES[unit]["weapon"])
	var problem := Units.apply_overrides({"units": {unit: {"max_health": 483, "cost": 160, "armor": {"front": 8.05}}},
			"weapons": {weapon: {"damage": 299}}})
	assert_eq(problem, "", "accepted")
	assert_eq(Units.stat(unit, "max_health"), 483.0, "hull")
	assert_eq(Units.armor(unit, "front"), 8.05, "front armor")
	assert_eq(Units.armor(unit, "side"), float(Units.PROFILES[unit]["armor"]["side"]), "an untouched facing")
	assert_eq(float(Weapons.profile(weapon)["damage"]), 299.0, "weapon damage")


func test_a_tuned_cost_prices_the_army() -> void:
	var unit := _unit()
	var catalog := int(Units.PROFILES[unit]["cost"])
	assert_eq(Units.cost_of({"unit": unit}), catalog, "untuned: the catalog's")
	Units.apply_overrides({"units": {unit: {"cost": catalog + 30}}})
	assert_eq(Units.cost_of({"unit": unit}), catalog + 30, "tuned")
	assert_eq(Units.army_cost({"squads": [{"units": [{"unit": unit}, {"unit": unit}]}]}), 2 * (catalog + 30), "army cost")


func test_a_cheaper_unit_buys_a_bigger_cpu_army() -> void:
	var before := Army.cpu_army("cpu", 7, Units.BASELINE_BUDGET, "gangs")
	var counts := 0
	for squad: Dictionary in before["squads"]:
		counts += (squad["units"] as Array).size()
	var cheaper := {}
	for unit: String in Units.roster("gangs"):
		cheaper[unit] = {"cost": float(Units.PROFILES[unit]["cost"]) * 0.5}
	Units.apply_overrides({"units": cheaper})
	var after := Army.cpu_army("cpu", 7, Units.BASELINE_BUDGET, "gangs")
	var more := 0
	for squad: Dictionary in after["squads"]:
		more += (squad["units"] as Array).size()
	assert_true(more > counts, "half price buys more (%d -> %d)" % [counts, more])
	assert_true(int(after["cost"]) <= Units.BASELINE_BUDGET, "still inside the budget at the tuned price")


func test_a_bad_document_changes_nothing() -> void:
	var unit := _unit()
	for bad: Dictionary in [{"units": {"no_such_unit": {"cost": 1}}}, {"units": {unit: {"no_such_stat": 1}}},
			{"units": {unit: {"display_name": 3}}}, {"units": {unit: {"cost": "cheap"}}},
			{"units": {unit: {"armor": {"top": 3}}}}, {"weapons": {"no_such_weapon": {"damage": 1}}}, {"unit": {}}]:
		assert_true(Units.apply_overrides(bad) != "", "rejected: %s" % JSON.stringify(bad))
	# A valid unit before a bad one: nothing is written.
	assert_true(Units.apply_overrides({"units": {unit: {"cost": 1}, "no_such_unit": {"cost": 1}}}) != "", "rejected")
	assert_true(Units.tuning.is_empty() and Weapons.tuning.is_empty(), "nothing written")
