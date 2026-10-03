extends TestCase
## Round 17 G3/G4: a gun sound designed more than one way (SfxDirections, built by tools/audio/gun_layers.py) plays
## the direction SfxSystem.DIRECTION names, `--sfx-direction=` overrides it for an audition, and "0" is the sound
## the lead heard before round 17. Swapping a direction is one line.

func _sfx() -> SfxSystem:
	var sfx := SfxSystem.new()
	add_to_tree(sfx)
	return sfx


func test_every_chosen_direction_exists() -> void:
	for sound in SfxSystem.DIRECTION:
		var chosen := String(SfxSystem.DIRECTION[sound])
		assert_true(chosen == SfxSystem.TODAY or (SfxDirections.TAKES.get(sound, {}) as Dictionary).has(chosen),
				"%s's direction %s was built (tools/audio/gun_layers.py)" % [sound, chosen])


func test_a_directed_sound_plays_that_directions_takes() -> void:
	var sfx := _sfx()
	for sound in SfxSystem.DIRECTION:
		var chosen := String(SfxSystem.DIRECTION[sound])
		if chosen == SfxSystem.TODAY:
			continue
		var expected: Array = SfxDirections.TAKES[sound][chosen]
		assert_eq((sfx.takes[sound] as Array).size(), expected.size(), "%s plays every take of direction %s" % [sound, chosen])
		for take in sfx.takes[sound]:
			assert_true(String((take as AudioStream).resource_path).contains("%s~%s_" % [sound, chosen]),
					"%s plays %s, not another direction" % [(take as AudioStream).resource_path, chosen])
		assert_eq(String(sfx.direction_of(sound)), chosen, "and says so")


func test_the_directions_are_stereo() -> void:
	## ElevenLabs returns mono; gun_layers.py builds the width (paired takes, the arena's slaps). A take that came out
	## mono lost it.
	for sound in SfxDirections.TAKES:
		for direction in SfxDirections.TAKES[sound]:
			var stream := load(String(SfxDirections.TAKES[sound][direction][0])) as AudioStreamWAV
			assert_true(stream != null and stream.stereo, "%s~%s is a stereo take" % [sound, direction])


func test_an_audition_flag_overrides_the_choice() -> void:
	var parsed := SfxSystem.parse_directions("tank_boom:b,autocannon_shot:0, nonsense ,mg_loop:")
	assert_eq(String(parsed.get("tank_boom", "")), "b", "a sound and its direction")
	assert_eq(String(parsed.get("autocannon_shot", "")), SfxSystem.TODAY, "0 asks for the sound as it was")
	assert_true(not parsed.has("mg_loop") and parsed.size() == 2, "malformed entries are ignored")


func test_today_is_the_sound_before_round_17() -> void:
	var sfx := _sfx()
	var sound := String(SfxDirections.TAKES.keys()[0])
	sfx.use_direction(sound, SfxSystem.TODAY)
	for take in sfx.takes[sound]:
		assert_true(not String((take as AudioStream).resource_path).contains("~"), "%s is not a round-17 direction" % sound)
	assert_eq(String(sfx.direction_of(sound)), SfxSystem.TODAY, "and says so")


func test_a_looped_direction_imports_whole() -> void:
	## Trip-up 74: a QOA-imported loop's loop points land a fifth of the way in. A stereo 16-bit frame is 4 bytes.
	for sound in SfxDirections.TAKES:
		if not String(sound).ends_with("_loop"):
			continue
		for direction in SfxDirections.TAKES[sound]:
			for path in SfxDirections.TAKES[sound][direction]:
				var stream := load(String(path)) as AudioStreamWAV
				assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "%s imports as PCM" % path)
				assert_eq(stream.data.size() / 4, SfxSystem.loop_frames(stream), "%s's data is its whole length" % path)
