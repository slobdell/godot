extends TestCase
## Guards the unit catalog contract (schema v0) shared by gameplay and garage.


func test_every_unit_has_the_v0_fields() -> void:
	for unit_id: String in Units.PROFILES:
		var unit: Dictionary = Units.profile(unit_id)
		for key: String in ["display_name", "cost", "max_health", "max_shield", "max_forward_speed",
				"hull_turn_rate_deg", "sight_radius", "hardpoints", "component_slots"]:
			assert_true(unit.has(key), "%s is missing %s" % [unit_id, key])


func test_hardpoints_only_accept_real_weapons() -> void:
	for unit_id: String in Units.PROFILES:
		for hardpoint: Dictionary in Units.profile(unit_id)["hardpoints"]:
			for weapon_id: String in hardpoint["accepts"]:
				assert_true(Weapons.exists(weapon_id), "%s accepts unknown weapon %s" % [unit_id, weapon_id])


func test_skirmish_accepts_doctrine_names_and_paths() -> void:
	assert_eq(SkirmishMode.doctrine_path("player_default"), "res://doctrines/player_default.json", "names resolve to res://doctrines")
	assert_eq(SkirmishMode.doctrine_path("user://doctrines/mine.json"), "user://doctrines/mine.json", "full paths pass through")
