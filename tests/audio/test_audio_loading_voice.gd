extends TestCase
## Feel X5 (round 6): the crowd under control's loading screen fades up, roars when the lights come on, and hands over.


func test_the_murmur_fades_up_then_the_crowd_roars_and_it_leaves() -> void:
	var voice := LoadingVoice.new()
	add_to_tree(voice)
	await wait_physics_frames(1)
	assert_eq(voice.murmur.bus, SfxSystem.CROWD_BUS, "on the crowd's own bus")
	assert_true(voice.murmur.playing, "the stands murmur the moment FIGHT is pressed")
	voice._process(LoadingVoice.FADE_IN_S * 0.5)
	assert_true(voice.murmur.volume_db > LoadingVoice.SILENT_DB and voice.murmur.volume_db < LoadingVoice.MURMUR_DB, "fading up")
	voice._process(LoadingVoice.FADE_IN_S)
	assert_eq(voice.phase, "hold", "then holding under the screen")
	assert_near(voice.murmur.volume_db, LoadingVoice.MURMUR_DB, 0.01, "at its level")
	voice.lights_up()
	assert_true(voice.roar.playing, "the lights come up to a roar")
	voice._process(LoadingVoice.FADE_OUT_S * 0.5)
	assert_true(voice.murmur.volume_db < LoadingVoice.MURMUR_DB, "and the murmur hands over to the match's crowd")
	voice.roar.stop()
	voice._process(LoadingVoice.FADE_OUT_S)
	assert_true(voice.is_queued_for_deletion(), "gone once it has faded")


func test_no_voice_without_sound() -> void:
	# Tests run headless: start() must not make a player there (and the same holds for --mute).
	assert_true(LoadingVoice.start(Engine.get_main_loop() as SceneTree) == null, "headless: silent, nothing made")
	LoadingVoice.finish()  # and finishing with nothing playing is harmless
