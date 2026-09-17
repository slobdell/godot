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
