extends TestCase
## Round 6 (the lead: "The announcers cut each others' audio off, so that destroys the feel of the announcement ...
## if someone interrupts then an announcer should interrupt (if necessary) and the other announcer only stops speaking
## after they've been interrupted").


func _voice() -> AnnouncerVoice:
	var voice := AnnouncerVoice.new()
	voice.load_stream = func(_path: String) -> AudioStream: return load("res://assets/audio/crowd_murmur.wav")
	voice.manifest = {"lines": {"a": {"variants": {"": "clip_a"}}, "b": {"variants": {"": "clip_b"}}},
			"clips": {"clip_a": {"file": "a.ogg"}, "clip_b": {"file": "b.ogg"}}}
	add_to_tree(voice)
	return voice


func test_an_interrupted_voice_trails_off_after_the_interrupter_starts() -> void:
	var voice := _voice()
	await wait_physics_frames(1)
	assert_true(voice.play({"line_id": "a", "speaker": "color"}), "the colour man starts a line")
	voice.cut()  # the director decides the caller must cut in
	assert_eq(voice.voices_sounding(), 1, "he is not silenced the instant the decision is made")
	assert_true(voice.play({"line_id": "b", "speaker": "caller", "cut_in": true}), "the caller starts")
	assert_eq(voice.voices_sounding(), 2, "both are heard for a moment: the interrupted voice trails off under the new one")
	await tree.create_timer(AnnouncerVoice.TRAIL_S + 0.3).timeout
	assert_eq(voice.voices_sounding(), 1, "then only the caller")
	assert_true(voice.is_speaking(), "who is still talking")


func test_a_line_that_ends_on_its_own_is_never_faded() -> void:
	var voice := _voice()
	await wait_physics_frames(1)
	voice.play({"line_id": "a", "speaker": "caller"})
	assert_eq(voice.voices_sounding(), 1, "one voice")
	assert_near(float(voice._player.volume_db), 0.0, 0.01, "at full level: only an interruption trails a line off")
