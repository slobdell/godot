extends TestCase
## X4: the battle's sound. What can be checked headless is the mix's structure — that repeated shots are not the
## same take every time, that world sound goes through one bus that can be limited and ducked, and that distance
## dulls the big sounds. How it actually sounds is a listening job (see the brief's Status).

func _sfx() -> SfxSystem:
	var sfx := SfxSystem.new()
	add_to_tree(sfx)
	return sfx


func test_the_most_repeated_sounds_have_several_takes() -> void:
	var sfx := _sfx()
	for sound in SfxSystem.TAKES:
		var pool: Array = sfx.takes.get(sound, [])
		assert_eq(pool.size(), int(SfxSystem.TAKES[sound]),
				"%s has all %d of its takes (run make sfx)" % [sound, int(SfxSystem.TAKES[sound])])
	assert_true(int(SfxSystem.TAKES["mg_round"]) >= 3,
			"a machine gun firing the same crack eleven times a second is what made this sound like an Atari game")


func test_the_takes_are_actually_different_recordings() -> void:
	var sfx := _sfx()
	var pool: Array = sfx.takes["mg_round"]
	for index in range(1, pool.size()):
		assert_true((pool[index] as AudioStreamWAV).data != (pool[0] as AudioStreamWAV).data,
				"take %d is its own sound, not a copy" % (index + 1))


func test_a_burst_does_not_play_one_take_over_and_over() -> void:
	var sfx := _sfx()
	var heard := {}
	for shot in 40:
		sfx.play_at("mg_round", Vector3.ZERO)
		heard[sfx._a_take("mg_round")] = true
	assert_true(heard.size() >= 3, "forty rounds drew at least three different takes (%d)" % heard.size())
	assert_eq(sfx.played, 40, "and every one of them played")


func test_a_sound_with_one_take_still_plays() -> void:
	var sfx := _sfx()
	assert_eq((sfx.takes["shell_whine"] as Array).size(), 1, "the shell whine was never varied")
	sfx.play_at("shell_whine", Vector3.ZERO)
	assert_eq(sfx.played, 1, "and it plays anyway")


func test_world_sound_goes_through_one_bus_that_can_be_limited_and_ducked() -> void:
	var sfx := _sfx()
	var index := AudioServer.get_bus_index(SfxSystem.WORLD_BUS)
	assert_true(index >= 0, "the World bus exists")
	var limited := false
	for effect_index in AudioServer.get_bus_effect_count(index):
		limited = limited or AudioServer.get_bus_effect(index, effect_index) is AudioEffectLimiter
	assert_true(limited, "with a limiter, so twenty voices in a firefight do not clip the master")
	assert_true(AudioServer.get_bus_volume_db(index) < 0.0, "and trimmed, leaving the limiter room to work")
	for child in sfx.get_children():
		if child is AudioStreamPlayer3D:
			assert_eq((child as AudioStreamPlayer3D).bus, SfxSystem.WORLD_BUS, "%s is on it" % child.name)
	# The announcer ducks whatever is on this bus; that wiring is AnnouncerVoice's and is covered by its own test.
	assert_eq(AnnouncerVoice.WORLD_BUS, SfxSystem.WORLD_BUS, "the booth ducks the same bus the battle plays on")


func test_distance_dulls_the_big_sounds_and_leaves_the_small_ones_alone() -> void:
	var sfx := _sfx()
	sfx.play_at("tank_boom", Vector3(200.0, 0.0, 0.0))
	var voice := sfx.get_node("Voice0") as AudioStreamPlayer3D
	assert_true(voice.attenuation_filter_cutoff_hz < 2000.0, "a cannon across the arena is dull, not just quiet")
	assert_true(voice.attenuation_filter_db < -10.0, "and noticeably filtered")
	sfx.play_at("ui_blip", Vector3.ZERO)  # not in DISTANCE_FILTER
	var next := sfx.get_node("Voice1") as AudioStreamPlayer3D
	assert_true(next.attenuation_filter_cutoff_hz > 20000.0, "a sound only ever heard close keeps its brightness")


func test_feel_s_engine_and_crowd_loops_still_get_a_wav_to_duplicate() -> void:
	## game/theme/fx/{engine,crowd}_system.gd cast sfx.streams[key] to AudioStreamWAV and set loop points on the
	## copy. Those files are feel's, so this contract is mine to keep, not theirs to adapt.
	var sfx := _sfx()
	for key in ["engine_diesel", "engine_v8", "engine_electric", "crowd_murmur", "mg_loop", "flame_loop"]:
		assert_true(sfx.streams.get(key) is AudioStreamWAV, "%s is still a plain AudioStreamWAV" % key)
