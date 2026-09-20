extends TestCase
## Assets X4 groundwork (contract K4): faction art slots `unit.<faction>.<role>.hull/turret/weapon` for the road gangs,
## the Law and the Syndicate. Gallery only this round; the pipeline fits them to the Condemned unit in the same role
## until factions get catalog entries of their own.


func test_faction_slots_have_contracts_fitted_to_the_role() -> void:
	for faction in FactionArt.NEW_FACTIONS:
		for role in FactionArt.ROLES:
			for part in ["hull", "turret", "weapon"]:
				assert_true(AssetContracts.has("unit.%s.%s.%s" % [faction, role, part]), "unit.%s.%s.%s has a contract" % [faction, role, part])
	# ROUND 9 (scale, CP2): a faction slot is contracted against THAT FACTION'S OWN unit. This line used to assert
	# the opposite -- that a faction's tank-class hull fits the CONDEMNED tank's box -- which was a round-3
	# stand-in, and this test is what made it look deliberate. The factions have had catalog entries since round 4.
	#
	# It was invisible while every hull was 2.8-5.0 m long: a stand-in is only wrong when the thing it stands in
	# for differs. S1 spread the roster from 2.93 m to 14.0 m, and 11 of the 14 faction art slots stopped matching
	# their stand-in while every one of them still matched its own box.
	assert_eq(AssetContracts.catalog_unit("gangs.tank"), "gang_tank", "a faction role resolves to that faction's unit")
	assert_eq(AssetContracts.get_contract("unit.gangs.tank.hull")["guide"], AssetContracts.unit_info("gang_tank")["hull_size"],
			"a faction's tank-class hull fits ITS OWN box (the War Rig's), not the Condemned tank's")
	assert_true(AssetContracts.unit_info("gangs.tank")["hull_size"] != AssetContracts.unit_info("tank")["hull_size"],
			"and those two boxes really do differ, or this assertion proves nothing")
	assert_eq(AssetContracts.catalog_unit("law.scout"), "law_scout", "the Law's scout role is the Pursuit Cruiser")
	assert_eq(AssetContracts.unit_pivot("law.scout"), AssetContracts.unit_pivot("law_scout"),
			"and its turret sits where ITS OWN unit's does")
	assert_eq(AssetContracts.get_contract("unit.syndicate.ifv.hull")["file"], "unit_syndicate_ifv_hull", "files are named by slot")
	assert_eq(AssetContracts.unit_of("unit.pirates.tank.hull"), "", "unknown factions have no slots")
	assert_eq(AssetContracts.unit_of("unit.gangs.boat.hull"), "", "unknown roles have no slots")
	assert_eq(AssetContracts.unit_of("unit.ifv.hull"), "ifv", "today's roster slots still resolve")


func test_the_pipeline_sizes_art_from_the_CATALOG_and_not_a_copy_of_it() -> void:
	## Round 9 (scale's finding, Invariant 0): AssetContracts used to carry its own hull_size and muzzle_height and
	## had already drifted from Units.PROFILES with nothing tying them together -- inert for gameplay, but every model
	## generated after the roster resize would have been normalised to the stale numbers in silence.
	## This is the mutation check: every one of these heights was 1.6 in the old frozen table, so that table fails
	## this test as written, and the resize cannot drift away from the pipeline again.
	for unit_id in AssetContracts.UNITS:
		var catalog: Variant = Units.stat(unit_id, "hull_size")
		var info := AssetContracts.unit_info(unit_id)
		assert_eq(info["hull_size"], Vector3(float(catalog[0]), float(catalog[1]), float(catalog[2])),
				"%s's contract box IS its catalog box" % unit_id)
		assert_near(float(info["muzzle_height"]), float(Units.stat(unit_id, "muzzle_height", -1.0)), 0.0001,
				"%s's contract muzzle IS its catalog muzzle" % unit_id)
		assert_eq(AssetContracts.get_contract("unit.%s.hull" % unit_id)["guide"], info["hull_size"],
				"and the contract the pipeline enforces is built from it")
	assert_eq(AssetContracts.STANDARD_HULL, AssetContracts.unit_info("tank")["hull_size"],
			"the turret-scale reference is the catalog's tank, not a frozen 2.4 x 1.6 x 3.6")


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
