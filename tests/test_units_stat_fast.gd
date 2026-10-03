extends TestCase
## S4 (round 16, CP1b): `Units.stat` is called per tank per frame by the HUD and per think by brains, and it used to
## format a "unit.key" String on every call to look up `tuning`. Untuned (normal play) it now skips the lookup; these
## pin that the answer is the same and that every way of tuning still wins.


func test_untuned_stat_is_the_catalog_value_for_every_unit_and_key() -> void:
	assert_true(Units.tuning.is_empty(), "setup: nothing tuned")
	for unit_id: String in Units.PROFILES:
		var unit: Dictionary = Units.PROFILES[unit_id]
		for key: String in unit:
			assert_eq(Units.stat(unit_id, key), unit[key], "%s.%s" % [unit_id, key])
		assert_eq(Units.stat(unit_id, "no_such_key", 7), 7, "%s: a missing key reads the fallback" % unit_id)
		for face: String in ["front", "side", "rear"]:
			assert_eq(Units.armor(unit_id, face), float(unit["armor"][face]), "%s armor %s" % [unit_id, face])


func test_a_direct_tuning_write_wins_and_erasing_it_restores() -> void:
	var catalog: float = Units.PROFILES["tank"]["max_forward_speed"]
	Units.tuning["tank.max_forward_speed"] = 99.0
	assert_eq(Units.stat("tank", "max_forward_speed"), 99.0, "a write to Units.tuning wins on the next read")
	assert_eq(Units.stat("scout", "max_forward_speed"), Units.PROFILES["scout"]["max_forward_speed"],
			"and only for its own unit")
	Units.tuning["tank.armor.front"] = 2.0
	assert_eq(Units.armor("tank", "front"), 2.0, "a tuned armor face wins")
	Units.tuning.erase("tank.max_forward_speed")
	Units.tuning.erase("tank.armor.front")
	assert_eq(Units.stat("tank", "max_forward_speed"), catalog, "erased, the catalog value is back")
	assert_eq(Units.armor("tank", "front"), float(Units.PROFILES["tank"]["armor"]["front"]), "and the armor's")


func test_a_match_knob_alone_does_not_hide_a_unit_tune() -> void:
	# A non-unit key (a match knob) makes tuning non-empty; a unit tune beside it must still be found.
	Units.tuning["yaw_fit"] = 1.0
	Units.tuning["ifv.sight_radius"] = 12.0
	assert_eq(Units.stat("ifv", "sight_radius"), 12.0, "tuned beside a match knob")
	assert_eq(Units.stat("tank", "sight_radius"), Units.PROFILES["tank"]["sight_radius"], "untuned beside it")
	Units.tuning.erase("yaw_fit")
	Units.tuning.erase("ifv.sight_radius")


func test_apply_tuning_still_wins() -> void:
	assert_eq(Units.apply_tuning("scout.max_health=3"), "", "valid tuning applies")
	assert_eq(Units.stat("scout", "max_health"), 3.0, "the --tune path wins")
	Units.tuning.erase("scout.max_health")
	assert_eq(Units.stat("scout", "max_health"), Units.PROFILES["scout"]["max_health"], "erased, restored")
