extends TestCase
## Guards the unit catalog v2 contract (C1 in _agents/workstreams.md) shared by rules, ai, army, art, command.

const REQUIRED := ["display_name", "role", "blurb", "cost", "unlock_tier", "hull_size", "max_health", "max_shield",
		"shield_recharge_delay", "shield_recharge_rate", "max_forward_speed", "max_reverse_speed",
		"hull_turn_rate_deg", "sight_radius", "weapon", "mount", "turret_turn_rate_deg", "muzzle_height", "armor",
		"good_vs", "weak_vs"]


func test_every_unit_has_the_v2_fields() -> void:
	for unit_id: String in Units.PROFILES:
		var unit: Dictionary = Units.profile(unit_id)
		for key: String in REQUIRED:
			assert_true(unit.has(key), "%s is missing %s" % [unit_id, key])
		for gone: String in ["class", "hardpoints", "component_slots"]:
			assert_true(not unit.has(gone), "%s still has the v1 key %s" % [unit_id, gone])
		assert_true(Units.ROLES.has(unit["role"]), "%s has a known role (%s)" % [unit_id, unit["role"]])
		assert_true(Units.MOUNTS.has(unit["mount"]), "%s has a known mount (%s)" % [unit_id, unit["mount"]])
		assert_true(Weapons.exists(unit["weapon"]), "%s fires a real weapon (%s)" % [unit_id, unit["weapon"]])
		if unit["mount"] == "fixed":
			assert_true(float(unit.get("fire_arc_deg", 0.0)) > 0.0, "%s, a fixed mount, has a fire arc" % unit_id)
		for face in ["front", "side", "rear"]:
			assert_true(float(unit["armor"].get(face, -1.0)) >= 0.0, "%s has %s armor" % [unit_id, face])
		for role: String in unit["good_vs"] + unit["weak_vs"]:
			assert_true(Units.ROLES.has(role), "%s's matchup hint names a real role (%s)" % [unit_id, role])


func test_the_lead_named_roster_is_there() -> void:
	for role in ["scout", "tank", "ifv", "artillery", "lancer"]:
		assert_eq(Units.with_role(role).size(), 1, "one %s unit in the starting roster" % role)
	assert_eq(Units.profile("scout")["mount"], "fixed", "the scout's gun shoots straight forward (no turret)")
	assert_true(Units.profile("ifv")["turret_turn_rate_deg"] > Units.profile("tank")["turret_turn_rate_deg"],
			"the IFV's turret outpaces the tank's slow one")
	assert_eq(Units.profile("lancer")["weapon"], "laser", "the laser moved onto its own unit")
	assert_true(Units.profile("lancer").has("heat_capacity") and not Units.profile("tank").has("heat_capacity"),
			"heat only where the weapon uses it")


func test_every_muzzle_clears_under_every_hull_top() -> void:
	# Rounds fly flat at muzzle height (trip-up 15): a muzzle above a hull's top would shoot over that unit.
	var lowest_top := INF
	for unit_id: String in Units.PROFILES:
		lowest_top = minf(lowest_top, float(Units.profile(unit_id)["hull_size"][1]))
	for unit_id: String in Units.PROFILES:
		assert_true(float(Units.profile(unit_id)["muzzle_height"]) <= lowest_top - Units.MUZZLE_CLEARANCE,
				"%s's muzzle can hit the shortest hull (%.2f m vs %.2f m top)" % [unit_id, Units.profile(unit_id)["muzzle_height"], lowest_top])


func test_tuning_reaches_units_weapons_and_armor() -> void:
	assert_eq(Units.apply_tuning("tank.max_shield=10,cannon.damage=5,ifv.armor.front=1"), "", "valid tuning applies")
	assert_eq(Units.stat("tank", "max_shield"), 10.0, "unit stat tuned")
	assert_eq(Weapons.profile("cannon")["damage"], 5.0, "weapon stat tuned")
	assert_eq(Units.armor("ifv", "front"), 1.0, "armor facing tuned")
	assert_true(Units.apply_tuning("tank.wings=2") != "", "unknown stats are refused")
	Units.tuning.clear()
	Weapons.tuning.clear()


func test_skirmish_accepts_doctrine_names_and_paths() -> void:
	assert_eq(SkirmishMode.doctrine_path("player_default"), "res://doctrines/player_default.json", "names resolve to res://doctrines")
	assert_eq(SkirmishMode.doctrine_path("user://doctrines/mine.json"), "user://doctrines/mine.json", "full paths pass through")


func test_unknown_cpu_archetypes_are_refused_not_silently_balanced() -> void:
	# Integration 2026-09-15: the garage asked for cpu:flamers (its own archetype name) and quietly got Balanced.
	assert_true(Army.load_army("cpu:flamers", 1).has("error"), "an archetype Army doesn't have is an error")
	assert_true(Army.load_army("cpu", 1).has("doctrine"), "plain cpu picks a seeded archetype")
