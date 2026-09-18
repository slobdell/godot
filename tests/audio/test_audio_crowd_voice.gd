extends TestCase
## X4 (round 5): the crowd's sound follows the match, not only the last explosion.


class HeldMood extends MatchMood:
	var held := 0.0

	func intensity() -> float:
		return held


func _voice(mood: MatchMood = null) -> CrowdVoice:
	var voice := CrowdVoice.new()
	voice.mood = mood
	add_to_tree(voice)
	voice.use_streams({"crowd_murmur": load("res://assets/audio/crowd_murmur.wav"),
			"crowd_cheer": load("res://assets/audio/crowd_cheer.wav")})
	return voice


func test_a_kill_lifts_the_crowd_and_it_settles_back() -> void:
	var voice := _voice()
	await wait_physics_frames(1)
	voice.react(Vector3.ZERO, 1.0)
	assert_true(voice.excitement > 0.8, "a kill brings them to their feet (%.2f)" % voice.excitement)
	for i in 30:
		voice._process(0.2)
	assert_near(voice.excitement, CrowdVoice.CALM, 0.01, "six seconds of nothing and it's a murmur again")


func test_a_long_firefight_keeps_the_crowd_loud_between_kills() -> void:
	var mood := HeldMood.new("green")
	var voice := _voice(mood)
	await wait_physics_frames(1)
	mood.held = 0.9
	voice.react(Vector3.ZERO, 1.0)
	for i in 30:
		voice._process(0.2)
	var hot := voice.murmur.volume_db
	assert_true(voice.excitement >= CrowdVoice.CALM + 0.9 * CrowdVoice.MOOD_HOLD - 0.01,
			"the murmur settles onto the fight's intensity, not below it (%.2f)" % voice.excitement)
	mood.held = 0.0
	for i in 30:
		voice._process(0.2)
	assert_true(voice.murmur.volume_db < hot - 6.0, "and quiets when the floor does (%.1f → %.1f dB)" % [hot, voice.murmur.volume_db])


func test_the_result_gets_a_roar() -> void:
	var mood := HeldMood.new("green")
	var voice := _voice(mood)
	await wait_physics_frames(1)
	voice._process(0.1)
	assert_true(not voice.roar.playing, "nothing to cheer yet")
	mood.state = "victory"
	voice._process(0.1)
	assert_true(voice.roar.playing, "the final whistle gets a roar")
	assert_eq(voice.roar.volume_db, CrowdVoice.RESULT_ROAR_DB, "louder than a kill's")


func test_a_crowd_with_no_fx_world_makes_no_voice() -> void:
	## A CrowdVoice built in a field initializer was never added to the tree on headless peers, and leaked there
	## ("8 ObjectDB instances leaked", "1 resources still in use"), which failed relay-smoke's clients.
	var crowd := CrowdSystem.new()
	add_to_tree(crowd)
	await wait_physics_frames(1)
	assert_true(FxWorld.get_instance() == null, "no FxWorld in this test")
	assert_true(crowd.voice == null, "so no voice was made to leak")


func test_the_crowd_plays_on_its_own_bus_that_impacts_only_dip() -> void:
	## Feel X3 (round 6): on the Bed bus the crowd was ducked 5:1 by every impact while already 20-25 dB under the mix.
	var voice := _voice()
	assert_eq(voice.murmur.bus, SfxSystem.CROWD_BUS, "the murmur has its own bus")
	assert_eq(voice.roar.bus, SfxSystem.CROWD_BUS, "and so does the roar")
	var crowd := AudioServer.get_bus_index(SfxSystem.CROWD_BUS)
	assert_true(crowd >= 0, "the bus exists")
	assert_eq(AudioServer.get_bus_send(crowd), StringName(SfxSystem.WORLD_BUS), "it feeds World (limited, ducked under the booth)")
	var dip := AudioServer.get_bus_effect(crowd, 0) as AudioEffectCompressor
	var bed := AudioServer.get_bus_effect(AudioServer.get_bus_index(SfxSystem.BED_BUS), 0) as AudioEffectCompressor
	assert_true(dip != null and dip.sidechain == StringName(SfxSystem.IMPACT_BUS), "impacts still dip the stands")
	assert_true(dip.ratio < bed.ratio, "but more gently than the bed under the guns (%.1f:1 < %.1f:1)" % [dip.ratio, bed.ratio])


func test_a_weak_spot_hit_gets_a_smaller_cheer_and_a_plain_hit_none() -> void:
	## Feel X8 (round 6): FxWorld.spectacle weighs a plain hit 0.3, a weak spot 0.5 and a kill 1.0.
	var voice := _voice()
	await wait_physics_frames(1)
	voice.react(Vector3.ZERO, 0.3)
	assert_true(not voice.roar.playing, "a plain hit only lifts the murmur")
	voice.react(Vector3.ZERO, 0.5)
	assert_true(voice.roar.playing, "a weak spot gets a cheer")
	assert_eq(voice.roar.volume_db, CrowdVoice.CHEER_DB, "quieter than a kill's roar")
	voice.roar.stop()
	voice.react(Vector3.ZERO, 1.0)
	assert_eq(voice.roar.volume_db, CrowdVoice.ROAR_DB, "a kill still roars")
