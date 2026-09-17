extends TestCase
## Render X6 (round 5): the faction rosters wear their own art in play, and a build without that art falls back cleanly.


func test_every_faction_unit_with_art_gets_its_own_slots() -> void:
	var slots := FactionArt.unit_slots()
	var units := 0
	for faction in FactionArt.NEW_FACTIONS:
		for unit_id in Units.roster(faction):
			var role := FactionArt.art_role(Units.role_of(unit_id))
			if not ResourceLoader.exists(FactionArt.generated_scene(faction, role, "hull")):
				continue
			units += 1
			for part in ["hull", "turret", "weapon"]:
				assert_true(slots.has("unit.%s.%s" % [unit_id, part]), "%s has a %s slot" % [unit_id, part])
			assert_true(String(slots["unit.%s.hull" % unit_id]).contains("/factions/%s/parts/" % faction), "%s's hull is its faction's art" % unit_id)
	assert_true(units >= 12, "the three new rosters play in their own art (%d units)" % units)


func test_a_part_without_its_own_model_is_empty_not_the_condemned_dozer() -> void:
	var slots := FactionArt.unit_slots()
	for key in slots:
		var path := String(slots[key])
		assert_true(path == FactionArt.NO_PART or ResourceLoader.exists(path), "%s -> %s exists" % [key, path])
	# The gang scout's hood gun is part of its hull model.
	assert_eq(slots.get("unit.gang_scout.turret"), FactionArt.NO_PART, "no turret is drawn on the gang scout")


func test_the_cyberpunk_theme_registers_the_faction_slots_and_a_tank_wears_them() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	assert_true(GameTheme.slots.has("unit.law_tank.hull"), "the theme carries the faction slots")
	var slot := VisualSlot.new()
	slot.slot = "unit.law_tank.hull"
	add_to_tree(slot)
	var hull := slot.visual as Node3D
	assert_true(hull != null and hull.get_node_or_null("Model") != null, "the law tank hull is a generated model")
	assert_true(hull.get_node_or_null("Shield") is ShieldEffect, "wearing the theme's shield like every hull")
	GameTheme.use(previous)


func test_special_roles_share_the_faction_special_art() -> void:
	assert_eq(FactionArt.art_role("support"), "special", "the gangs' support truck")
	assert_eq(FactionArt.art_role("lancer"), "special", "the Syndicate's lancer")
	assert_eq(FactionArt.art_role("tank"), "tank", "core roles keep their own art")
