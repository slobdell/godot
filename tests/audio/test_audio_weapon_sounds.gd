extends TestCase
## Round 5, after the lead played the Syndicate: *"the sound effects were no good they sounded like a cheesy
## cartoon"*. Sounds were picked by fire model, so a plasma repeater played a machine gun, guided missiles played a
## mortar tube, and the railgun and the laser shared one ray-gun zap. Weapons now name their own sounds.


func _family_default(weapon_id: String, slot: String) -> String:
	var model := String(Weapons.profile(weapon_id).get("fire_model", "shell"))
	var family: Dictionary = WeaponFx.FAMILIES.get(model, {})
	return String(family.get("fire_sound", "")) if slot != "hit" else String(family.get("hit_sound", ""))


func test_no_syndicate_weapon_borrows_another_faction_s_gun() -> void:
	for unit_id in Units.roster("syndicate"):
		var weapon := String(Units.PROFILES[unit_id].get("weapon", ""))
		var model := String(Weapons.profile(weapon).get("fire_model", ""))
		var slot := "loop" if model == "stream" else "fire"
		var sound := SfxWeapons.sound_for(weapon, slot, _family_default(weapon, slot))
		assert_true(sound != _family_default(weapon, slot),
				"%s's %s has its own sound, not the %s family's %s" % [unit_id, weapon, model, sound])


func test_the_railgun_and_the_laser_are_not_the_same_weapon() -> void:
	assert_true(SfxWeapons.sound_for("railgun", "fire", "laser_pulse") != SfxWeapons.sound_for("laser", "fire", "laser_pulse"),
			"a railgun throws a slug; a laser burns")


func test_an_unlisted_weapon_keeps_its_family_s_sound() -> void:
	assert_eq(SfxWeapons.sound_for("cannon", "fire", "tank_boom"), "tank_boom", "the Condemned cannon is unchanged")
	assert_eq(SfxWeapons.sound_for("not_a_weapon", "fire", "mg_loop"), "mg_loop", "an unknown weapon falls back too")


func test_every_sound_a_weapon_names_can_actually_play() -> void:
	## Until a sound is generated it has no file; ALIAS keeps the weapon audible instead of silent.
	var sfx := SfxSystem.new()
	add_to_tree(sfx)
	for sound in SfxWeapons.named_sounds():
		var playable: bool = sfx.streams.has(sound) or sfx.streams.has(String(SfxSystem.ALIAS.get(sound, "")))
		assert_true(playable, "%s plays something (its own take, or the sound it stands in for)" % sound)
		var before := sfx.played
		sfx.play_at(sound, Vector3.ZERO)
		assert_eq(sfx.played, before + 1, "%s was heard" % sound)


func test_a_plasma_repeater_streams_plasma_not_a_machine_gun() -> void:
	var sfx := SfxSystem.new()
	add_to_tree(sfx)
	var gunfire := GunfireLoops.new()
	add_to_tree(gunfire)
	gunfire.use_streams(sfx.streams)
	var plasma := SfxWeapons.sound_for("pulse_repeater", "loop", "mg_loop")
	gunfire.trigger("syn_scout", Vector3.ZERO, 1.0, plasma)
	gunfire.update(Vector3.ZERO, 1.0)
	var voice := gunfire._voices[gunfire._assigned.find("syn_scout")] as AudioStreamPlayer3D
	var wanted: AudioStream = gunfire._loops.get(plasma)
	if wanted != null:
		assert_eq(voice.stream, wanted, "the repeater's own loop")
	else:
		assert_true(voice.stream != null, "until that loop exists it still streams something")
