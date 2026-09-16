extends TestCase
## Assets X4 groundwork (contract K4): faction art slots `unit.<faction>.<role>.hull/turret/weapon` for the road gangs,
## the Law and the Syndicate. Gallery only this round; the pipeline fits them to the Condemned unit in the same role
## until factions get catalog entries of their own.


func test_faction_slots_have_contracts_fitted_to_the_role() -> void:
	for faction in FactionArt.NEW_FACTIONS:
		for role in FactionArt.ROLES:
			for part in ["hull", "turret", "weapon"]:
				assert_true(AssetContracts.has("unit.%s.%s.%s" % [faction, role, part]), "unit.%s.%s.%s has a contract" % [faction, role, part])
	var condemned_twin: String = AssetContracts.ROLE_UNITS["tank"]
	assert_eq(AssetContracts.get_contract("unit.gangs.tank.hull")["guide"], AssetContracts.UNITS[condemned_twin]["hull_size"],
			"a faction's tank-class hull fits the Condemned tank's box")
	assert_eq(AssetContracts.unit_pivot("law.scout"), AssetContracts.unit_pivot("scout"), "and its turret sits where the scout's does")
	assert_eq(AssetContracts.get_contract("unit.syndicate.ifv.hull")["file"], "unit_syndicate_ifv_hull", "files are named by slot")
	assert_eq(AssetContracts.unit_of("unit.pirates.tank.hull"), "", "unknown factions have no slots")
	assert_eq(AssetContracts.unit_of("unit.gangs.boat.hull"), "", "unknown roles have no slots")
	assert_eq(AssetContracts.unit_of("unit.ifv.hull"), "ifv", "today's roster slots still resolve")


func test_the_condemned_fill_every_role_from_todays_roster() -> void:
	for role in FactionArt.ROLES:
		var hull := FactionArt.instantiate("condemned", role, "hull")
		assert_true(hull != null, "the Condemned have a %s hull" % role)
		if hull != null:
			hull.free()


func test_every_faction_fills_every_role_with_the_approved_model() -> void:
	# The lead approved one concept per role on 2026-09-16; tools/assets/build_factions.sh fits them into the K4 slots.
	for faction in FactionArt.NEW_FACTIONS:
		for role in FactionArt.ROLES:
			assert_true(FactionArt.has_art(faction, role), "%s has its %s" % [faction, role])
			var hull := FactionArt.instantiate(faction, role, "hull")
			assert_true(hull != null, "%s %s hull loads" % [faction, role])
			if hull != null:
				hull.free()
	# Fixed-mount scouts and the hover units carry their weapon in the body: those slots are deliberately empty.
	var turreted := {"gangs": ["tank", "ifv", "artillery"], "law": ["tank", "ifv", "artillery", "special"],
			"syndicate": ["tank", "ifv"]}
	for faction in turreted:
		for role: String in turreted[faction]:
			var turret := FactionArt.instantiate(faction, role, "turret")
			assert_true(turret != null, "%s %s has a turret that can traverse" % [faction, role])
			if turret != null:
				turret.free()
	assert_eq(FactionArt.instantiate("gangs", "nonexistent_role", "hull"), null, "a missing part is null, not an error")


func test_the_wreck_husk_fills_its_slot_in_both_themes() -> void:
	var previous := GameTheme.theme_name
	for theme in ["default", "cyberpunk"]:
		GameTheme.use(theme)
		var packed := GameTheme.scene("prop.wreck")
		var wreck := packed.instantiate() if packed != null else null
		assert_true(wreck != null, "%s fills prop.wreck (the lead approved wreck_a)" % theme)
		if wreck != null:
			wreck.free()
	GameTheme.use(previous)
