extends TestCase
## Feel, round 10 backlog 4: a faint rim per faction, so hulls read between the lamp pools without their rings.
## The frames are the judge (a pair at his pose, rim off and on); these hold the mechanism: each faction's hull wears its
## own rim colour, the team hint is untouched, and switching it off gives back exactly the old material.


func _source() -> StandardMaterial3D:
	var source := StandardMaterial3D.new()
	var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	source.albedo_texture = ImageTexture.create_from_image(image)
	return source


func test_each_faction_wears_its_own_rim_and_keeps_the_team_hint() -> void:
	var source := _source()
	var team := Color(0.2, 0.9, 0.4)
	var seen := {}
	for faction: String in UnitSkin.FACTION_RIM:
		var material := UnitSkin.material_for(source, team, Color(1, 1, 1, 0), 0, faction)
		var rim: Vector3 = material.get_shader_parameter("rim_color")
		var wanted: Color = UnitSkin.FACTION_RIM[faction]
		assert_near(rim.distance_to(Vector3(wanted.r, wanted.g, wanted.b)), 0.0, 0.001, "%s's rim is its colour" % faction)
		assert_near(float(material.get_shader_parameter("rim_strength")), UnitSkin.FACTION_RIM_STRENGTH, 0.001,
				"%s's rim is at the faction strength" % faction)
		assert_eq(material.get_shader_parameter("team_color"), team, "%s keeps the team colour for the rim's hint" % faction)
		seen[str(rim)] = faction
	assert_eq(seen.size(), UnitSkin.FACTION_RIM.size(), "four factions, four different rims")


func test_off_and_unknown_give_back_the_old_rim() -> void:
	var source := _source()
	var plain := UnitSkin.material_for(source, UnitSkin.DEFAULT_TEAM, Color(1, 1, 1, 0), 0, "")
	assert_eq(plain.get_shader_parameter("rim_color"), null, "no faction: the shader's own default rim, untouched")
	UnitSkin.faction_rim_enabled = false
	var off := UnitSkin.material_for(source, UnitSkin.DEFAULT_TEAM, Color(1, 1, 1, 0), 0, "gangs")
	UnitSkin.faction_rim_enabled = true
	assert_true(off == plain, "--no-faction-rim: the very material a faction-less hull gets (the A/B's control arm)")
	var on := UnitSkin.material_for(source, UnitSkin.DEFAULT_TEAM, Color(1, 1, 1, 0), 0, "gangs")
	assert_true(on != plain, "and on, a material of its own (positive control: the switch does something)")
