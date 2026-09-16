extends TestCase
## X6: the music director picks a bed per MatchMood state, crossfades on the beat, and plays stingers. The audio
## itself can't be asserted headless, so these cover the decisions: which track, when the fade may start, and that
## a missing file is silence rather than a crash.

const MUSIC := "res://assets/music"

var _loaded: Array[String] = []


func _director() -> MusicDirector:
	var music := MusicDirector.new()
	assert_true(music.load_tracks(MUSIC), "the placeholder manifest loads (make music-placeholders)")
	# Never touch the audio server in a test: remember what it would have loaded instead.
	_loaded = []
	music.load_stream = func(path: String) -> AudioStream:
		_loaded.append(path.get_file())
		return AudioStreamWAV.new()
	return music


func test_every_mood_state_has_a_bed() -> void:
	var music := _director()
	for state in MatchMood.STATES:
		assert_true(music.track_for(state) != "", "%s has a bed to play" % state)
	assert_true(music.track_for("garage") != "", "so does the garage, which is outside a match")
	assert_eq(music.track_for("not_a_state"), "", "and an unknown state asks for nothing rather than guessing")


func test_the_beds_are_ordered_by_how_hard_they_hit() -> void:
	var music := _director()
	var lull: Dictionary = music.tracks[music.track_for("lull")]
	var battle: Dictionary = music.tracks[music.track_for("battle")]
	var last_stand: Dictionary = music.tracks[music.track_for("last_stand")]
	assert_true(float(lull["intensity"]) < float(battle["intensity"]), "a battle is heavier than a lull")
	assert_true(float(battle["intensity"]) < float(last_stand["intensity"]), "a last stand is heavier still")


func test_a_bar_line_is_worked_out_from_the_tempo() -> void:
	assert_near(MusicDirector.seconds_per_bar({"bpm": 120.0, "beats_per_bar": 4}), 2.0, 0.001,
			"four beats at one hundred twenty a minute is two seconds")
	assert_near(MusicDirector.seconds_per_bar({"bpm": 110.0, "beats_per_bar": 4}), 60.0 * 4 / 110.0, 0.001,
			"and the battle bed's bar is a little longer")
	assert_eq(MusicDirector.seconds_per_bar({}), 0.0, "a track with no tempo asks the director not to wait")


func test_the_first_bed_starts_at_once() -> void:
	var music := _director()
	add_to_tree(music)
	await wait_physics_frames(1)
	music.set_state("lull")
	assert_eq(music.current_track(), music.track_for("lull"), "nothing was playing, so it does not wait for a bar")
	assert_eq(_loaded.size(), 1, "one file was loaded")
	assert_eq(music.pending, "", "and nothing is queued behind it")


func test_asking_for_the_bed_already_playing_changes_nothing() -> void:
	var music := _director()
	add_to_tree(music)
	await wait_physics_frames(1)
	music.set_state("battle")
	var loaded_once := _loaded.size()
	music.set_state("battle")
	assert_eq(_loaded.size(), loaded_once, "the bed is not reloaded or restarted")


func test_a_new_state_waits_for_a_bar_line() -> void:
	var music := _director()
	add_to_tree(music)
	await wait_physics_frames(1)
	music.set_state("lull")
	music.set_state("battle")
	assert_eq(music.pending, music.track_for("battle"), "the battle bed is queued, not cut in")
	assert_eq(music.current_track(), music.track_for("lull"), "the lull bed keeps playing until the bar ends")


func test_it_follows_a_mood_signal() -> void:
	var music := _director()
	add_to_tree(music)
	await wait_physics_frames(1)
	var mood := MatchMood.new("green")
	music.follow(mood)
	assert_eq(music.current_track(), music.track_for("lull"), "a match starts on the quiet bed")
	mood.push_event({"tick": 0, "t": 0.0, "type": "match_start", "arena": "foundry", "budget": 1000, "teams": [
		{"team": "green", "faction": "condemned", "units": [{"id": "g1", "unit": "tank"}]},
		{"team": "rust", "faction": "condemned", "units": [{"id": "r1", "unit": "tank"}]}]})
	mood.push_event({"tick": 60, "t": 1.0, "type": "first_contact", "team": "green", "unit": "tank",
			"target_unit": "tank"})
	assert_eq(music.pending, music.track_for("skirmish"), "contact queues the skirmish bed")


func test_a_stinger_plays_once_and_then_holds_off() -> void:
	var music := _director()
	add_to_tree(music)
	await wait_physics_frames(1)
	assert_true(music.play_stinger("sting.first_blood"), "the first kill gets a hit")
	assert_true(not music.play_stinger("sting.kill"), "a flurry right behind it does not pile another on top")
	assert_true(not music.play_stinger("sting.not_a_thing"), "an unknown stinger is simply ignored")


func test_missing_files_are_silence_not_a_crash() -> void:
	var music := MusicDirector.new()
	assert_true(not music.load_tracks("res://assets/music_that_is_not_there"), "no manifest, no music")
	add_to_tree(music)
	await wait_physics_frames(1)
	music.set_state("battle")
	assert_eq(music.current_track(), "", "and asking for a bed is quietly nothing")
	var broken := _director()
	broken.load_stream = func(_path: String) -> AudioStream: return null
	add_to_tree(broken)
	await wait_physics_frames(1)
	broken.set_state("battle")
	assert_eq(broken.current_track(), "", "a manifest row whose file is missing does not become the current bed")
