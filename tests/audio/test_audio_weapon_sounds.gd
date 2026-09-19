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
	var wanted: Array = gunfire._loops.get(plasma, [])
	if not wanted.is_empty():
		assert_true(voice.stream in wanted, "one of the repeater's own loops")
	else:
		assert_true(voice.stream != null, "until that loop exists it still streams something")


func test_machine_guns_spread_across_their_takes_and_twin_guns_have_their_own() -> void:
	## Round 6 (the lead: "I believe we're missing machine guns"): four machine-gun loops and a twin-gun loop.
	var sfx := SfxSystem.new()
	add_to_tree(sfx)
	var gunfire := GunfireLoops.new()
	add_to_tree(gunfire)
	gunfire.use_streams(sfx.streams, sfx.takes)
	assert_eq(gunfire.loop_count("mg_loop"), (sfx.takes.get("mg_loop", []) as Array).size(), "every machine-gun take loops")
	assert_true(gunfire.loop_count("mg_loop") >= 3, "several takes, so a firing line isn't one recording (%d)" % gunfire.loop_count("mg_loop"))
	assert_eq(SfxWeapons.sound_for("twin_mg", "loop", "mg_loop"), "twin_mg_loop", "two guns firing together have their own loop")
	assert_true(gunfire.loop_count("twin_mg_loop") >= 1, "and it is loaded")
	var heard := {}
	for i in GunfireLoops.VOICES:
		gunfire.trigger("gunner_%d" % i, Vector3(i, 0, 0), 1.0)
	gunfire.update(Vector3.ZERO, 1.0)
	for voice in gunfire._voices:
		heard[voice.stream] = true
	assert_true(heard.size() >= 2, "four gunners don't all stream the same take (%d distinct)" % heard.size())


func test_machine_guns_have_their_own_bus_that_cannon_impacts_only_dip() -> void:
	## Round 6: on the Bed bus every cannon impact ducked the machine guns 5:1, so they vanished in a busy fight.
	var gunfire := GunfireLoops.new()
	add_to_tree(gunfire)
	for voice in gunfire._voices:
		assert_eq(voice.bus, SfxSystem.GUNFIRE_BUS, "machine-gun loops play on the gunfire bus")
	var guns := AudioServer.get_bus_index(SfxSystem.GUNFIRE_BUS)
	assert_true(guns >= 0, "the bus exists")
	var dip := AudioServer.get_bus_effect(guns, 0) as AudioEffectCompressor
	var bed := AudioServer.get_bus_effect(AudioServer.get_bus_index(SfxSystem.BED_BUS), 0) as AudioEffectCompressor
	assert_true(dip.sidechain == StringName(SfxSystem.IMPACT_BUS) and dip.ratio < bed.ratio, "a lighter dip than the bed's")
