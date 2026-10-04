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


func test_his_picks_are_what_the_game_plays() -> void:
	## His taps on the audition page (2026-10-03 23:31-23:37 PDT; references/round17/guns_g4_picks_db.json), by the
	## page's ids: tank a, 25mm b, mg a, kill a, railgun 0, mortar 0 (redo asked), the second tries skid b, squeal c,
	## incoming b, shield c. A change here is a change to what he chose.
	var picks := {"tank_boom": "a", "autocannon_shot": "b", "mg_loop": "a", "explosion_big": "a",
		"railgun_shot": SfxSystem.TODAY, "mortar_launch": SfxSystem.TODAY, "twin_mg_loop": "a", "missile_launch": "a",
		"pulse_shot": "a", "flame_loop": "a", "track_skid": "b", "track_squeal": "c", "shell_incoming": "b", "shield_up": "c"}
	for sound in picks:
		assert_eq(String(SfxSystem.DIRECTION[sound]), String(picks[sound]), "%s plays his pick" % sound)
	var sfx := _sfx()
	for sound in ["railgun_shot", "mortar_launch"]:
		assert_true(not (sfx.takes[sound] as Array).is_empty(), "%s has its sound from before round 17" % sound)
		for take in sfx.takes[sound]:
			assert_true(not String((take as AudioStream).resource_path).contains("~"), "%s: not a round-17 direction" % sound)


## Sounds he sent back with a redo whose candidates are on the page now (the mortar: "Both of these sound lame and we
## should redo", 2026-10-03 23:33 PDT). Remove an entry when his tap is applied.
const OPEN_REDOS := ["mortar_launch"]


func test_only_his_picks_ship() -> void:
	## The unpicked directions are retired (assets/audio/gun_designs.json) and their takes are out of the game: one
	## direction per sound in the manifest, the one DIRECTION names.
	for sound in SfxDirections.TAKES:
		var built := (SfxDirections.TAKES[sound] as Dictionary).keys()
		if OPEN_REDOS.has(sound):
			# He asked for a redo and has not tapped yet: the game plays TODAY, the candidates wait for his tap.
			assert_eq(String(SfxSystem.DIRECTION[sound]), SfxSystem.TODAY, "%s plays today's sound until he picks" % sound)
			continue
		assert_eq(built.size(), 1, "%s ships one direction (%s)" % [sound, built])
		assert_eq(String(built[0]), String(SfxSystem.DIRECTION.get(sound, "")), "%s's one direction is the chosen one" % sound)
