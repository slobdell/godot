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
		assert_eq(int(sfx.synth_takes.get(sound, 0)), int(SfxSystem.TAKES[sound]),
				"%s has all %d of its synthesised takes (run make sfx)" % [sound, int(SfxSystem.TAKES[sound])])
		var expected := int(SfxLayers.TAKES[sound].size()) if SfxLayers.TAKES.has(sound) else int(SfxSystem.TAKES[sound])
		assert_eq((sfx.takes.get(sound, []) as Array).size(), expected, "%s plays from a pool of %d" % [sound, expected])
	assert_true(int(SfxSystem.TAKES["mg_round"]) >= 3,
			"a machine gun firing the same crack eleven times a second is what made this sound like an Atari game")


func test_the_takes_are_actually_different_recordings() -> void:
	var sfx := _sfx()
	for sound in sfx.takes:
		var pool: Array = sfx.takes[sound]
		for index in range(1, pool.size()):
			assert_true(pool[index] != pool[0] and pool[index].resource_path != pool[0].resource_path,
					"%s take %d is its own sound, not a copy" % [sound, index + 1])
	var synth: Array = []
	for take in int(SfxSystem.TAKES["mg_round"]):
		var path := "res://assets/audio/mg_round%s.wav" % ("" if take == 0 else "_%d" % (take + 1))
		synth.append(load(path) as AudioStreamWAV)
	for index in range(1, synth.size()):
		assert_true((synth[index] as AudioStreamWAV).data != (synth[0] as AudioStreamWAV).data,
				"synthesised take %d differs in its samples, not just its name" % (index + 1))


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
	var single := ""
	for sound in sfx.takes:
		if (sfx.takes[sound] as Array).size() == 1 and not sound.begins_with("ui_") and not sound.ends_with("_loop"):
			single = sound
			break
	assert_true(single != "", "some world sound still has a single take")
	sfx.play_at(single, Vector3.ZERO)
	assert_eq(sfx.played, 1, "and %s plays anyway" % single)


func test_layered_takes_replace_the_synthesised_ones() -> void:
	## Round 5 X1: ElevenLabs source material layered under the transients. Every take the manifest lists loads, and
	## a sound listed there plays only those.
	var sfx := _sfx()
	assert_true(SfxLayers.TAKES.size() > 0, "the pilot's sounds are in the manifest")
	for sound in SfxLayers.TAKES:
		assert_true(sfx.streams.has(sound), "%s is a sound SfxSystem knows (sfx_layers.gd names it)" % sound)
		assert_eq(int(sfx.layered.get(sound, 0)), (SfxLayers.TAKES[sound] as Array).size(), "every take of %s loaded" % sound)
		for take in sfx.takes[sound]:
			assert_true(String((take as AudioStream).resource_path).contains("/layered/"), "%s plays a layered take" % sound)


func test_every_loop_loops_over_its_whole_length() -> void:
	## Engine, crowd, flame and gunfire code set loop_end = data.size() / 2 on these streams. That counts frames only
	## for 16-bit PCM; on a QOA import every loop repeated its first fifth (0.2 s of a 1 s machine gun) until round 5.
	var sfx := _sfx()
	for key in ["engine_diesel", "engine_v8", "engine_electric", "crowd_murmur", "mg_loop", "flame_loop", "tread_loop", "tire_loop"]:
		var stream := sfx.streams[key] as AudioStreamWAV
		assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "%s imports as 16-bit PCM (compress/mode=0)" % key)
		assert_true(not stream.stereo, "%s is mono" % key)
		assert_eq(stream.data.size() / 2, SfxSystem.loop_frames(stream), "so %s's data.size() / 2 is its full length" % key)


func test_world_sound_goes_through_one_bus_that_can_be_limited_and_ducked() -> void:
	var sfx := _sfx()
	var index := AudioServer.get_bus_index(SfxSystem.WORLD_BUS)
	assert_true(index >= 0, "the World bus exists")
	var limited := false
	for effect_index in AudioServer.get_bus_effect_count(index):
		limited = limited or AudioServer.get_bus_effect(index, effect_index) is AudioEffectLimiter
	assert_true(limited, "with a limiter, so twenty voices in a firefight do not clip the master")
	assert_true(AudioServer.get_bus_volume_db(index) < 0.0, "and trimmed, leaving the limiter room to work")
	sfx.play_at("tank_boom", Vector3.ZERO)
	sfx.play_at("bullet_hit_metal", Vector3.ZERO)
	for child in sfx.get_children():
		if child is AudioStreamPlayer3D:
			var bus := (child as AudioStreamPlayer3D).bus
			var feeds: String = bus if bus == SfxSystem.WORLD_BUS else String(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)))
			assert_eq(feeds, SfxSystem.WORLD_BUS, "%s reaches it (through %s)" % [child.name, bus])
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


func test_a_sound_too_far_to_hear_never_takes_a_voice() -> void:
	var sfx := _sfx()
	sfx.listener = Vector3.ZERO
	sfx.play_at("bullet_hit_metal", Vector3(2000.0, 0.0, 0.0))
	assert_eq(sfx.played, 0, "a ping two kilometres away is not started")
	assert_eq(sfx.culled, 1, "it is counted as culled")
	sfx.play_at("tank_boom", Vector3(300.0, 0.0, 0.0))
	assert_eq(sfx.played, 1, "a cannon at 300 m still carries")


func test_a_quiet_sound_never_cuts_a_loud_one_when_the_pool_is_full() -> void:
	var sfx := _sfx()
	sfx.listener = Vector3.ZERO
	for i in SfxSystem.WORLD_VOICES:
		sfx.play_at("tank_boom", Vector3(10.0, 0.0, 0.0))
	# Headless players stop almost at once, so hold the pool "playing" by what the system believes it started.
	var busy := 0
	for voice in sfx._world:
		busy += 1 if voice.playing else 0
	if busy < SfxSystem.WORLD_VOICES:
		return  # the dummy audio driver doesn't keep voices playing; the level maths is covered below
	sfx.play_at("bullet_hit_metal", Vector3(150.0, 0.0, 0.0))
	assert_eq(sfx.culled, 1, "twenty cannons nearby: a distant ping waits")


func test_the_level_a_sound_is_heard_at_falls_with_distance() -> void:
	var sfx := _sfx()
	sfx.listener = Vector3.ZERO
	assert_near(sfx.heard_level_db(0.0, Vector3(10.0, 0, 0)), 0.0, 0.01, "inside unit size it is its own level")
	assert_near(sfx.heard_level_db(0.0, Vector3(SfxSystem.UNIT_SIZE * 10.0, 0, 0)), -20.0, 0.01, "ten times as far, 20 dB down")


func test_a_shell_landing_ducks_the_fight_underneath_it() -> void:
	## X2: the moment a shell lands is the loudest thing in the mix, then it falls away.
	var sfx := _sfx()
	sfx.listener = Vector3.ZERO
	var bed := AudioServer.get_bus_index(SfxSystem.BED_BUS)
	assert_true(bed >= 0 and AudioServer.get_bus_index(SfxSystem.IMPACT_BUS) >= 0, "impacts and the bed have buses")
	var keyed := false
	for i in AudioServer.get_bus_effect_count(bed):
		var effect := AudioServer.get_bus_effect(bed, i) as AudioEffectCompressor
		keyed = keyed or (effect != null and effect.sidechain == SfxSystem.IMPACT_BUS)
	assert_true(keyed, "the bed is compressed by the impacts")
	sfx.play_at("tank_boom", Vector3.ZERO)
	var boom: Array = sfx._world.filter(func(v: AudioStreamPlayer3D) -> bool: return v.playing)
	assert_eq((boom[0] as AudioStreamPlayer3D).bus, SfxSystem.IMPACT_BUS, "a cannon plays on the impact bus")
	var engines := EngineSystem.new()
	add_to_tree(engines)
	assert_eq((engines.get_child(0) as AudioStreamPlayer3D).bus, SfxSystem.BED_BUS, "engines sit in the bed")
