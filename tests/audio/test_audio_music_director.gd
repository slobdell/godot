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


func test_the_fight_builds_in_layers_instead_of_swapping_beds() -> void:
	## X5: one stem set covers lull, skirmish, battle and last stand, so the soundtrack grows with the fight.
	var music := _director()
	var fight := music.track_for("skirmish")
	assert_eq(music.track_for("battle"), fight, "a battle plays the same track as a skirmish: it tightens, not swaps")
	assert_true(music.track_for("lull") != fight, "a lull is its own track, before the fight starts")
	assert_true(music.track_for("last_stand") != fight, "and a last stand is its own, where a change of song is the point")
	var track: Dictionary = music.tracks[fight]
	assert_true(track.has("stems"), "and that track is stems")
	var opening := MusicDirector.layers_for(track, 0.05, "skirmish")
	var busy := MusicDirector.layers_for(track, 0.5, "skirmish")
	var battle := MusicDirector.layers_for(track, 0.9, "battle")
	assert_true(opening.size() >= 1, "first contact already has music")
	assert_true(opening.size() < busy.size() and busy.size() < battle.size(), "more layers as it heats up: %d, %d, %d"
			% [opening.size(), busy.size(), battle.size()])


func test_a_layer_holds_through_a_short_dip() -> void:
	var track := {"stems": [{"file": "a.ogg", "from": 0.0}, {"file": "b.ogg", "from": 0.5}]}
	var on := MusicDirector.layers_for(track, 0.55, "battle")
	assert_eq(on, [0, 1] as Array[int], "the second layer comes in at 0.5")
	assert_eq(MusicDirector.layers_for(track, 0.46, "battle", on), [0, 1] as Array[int], "and stays through a dip")
	assert_eq(MusicDirector.layers_for(track, 0.40, "battle", on), [0] as Array[int], "but not a real drop")
	assert_eq(MusicDirector.layers_for(track, 0.46, "battle"), [0] as Array[int], "coming up, it waits for 0.5")


func test_stems_play_locked_together_and_fade_on_change() -> void:
	var music := _director()
	add_to_tree(music)
	await wait_physics_frames(1)
	music.set_state("skirmish")
	var stems: Array = music.tracks[music.current_track()]["stems"]
	assert_eq(_loaded.size(), stems.size(), "every stem loaded")
	assert_eq(music.stem_db.size(), stems.size(), "one level per stem")
	music.update_layers(0.1, "skirmish")  # first contact: the quiet end of the arrangement
	var before := music.layers.size()
	assert_true(music.update_layers(0.95, "battle"), "a battle changes the arrangement")
	assert_true(music.layers.size() > before, "by adding layers")
	assert_true(not music.update_layers(0.95, "battle"), "and the same reading changes nothing")
	await wait_physics_frames(int((MusicDirector.STEM_FADE_S + 0.4) * SimClock.TICK_RATE))
	for index in music.layers:
		assert_near(music.stem_db[index], 0.0, 0.5, "layer %d faded up" % index)


func test_moving_between_fight_states_never_reloads_the_track() -> void:
	var music := _director()
	add_to_tree(music)
	await wait_physics_frames(1)
	music.set_state("skirmish")
	var loaded := _loaded.size()
	music.set_state("battle")
	assert_eq(_loaded.size(), loaded, "no crossfade, no reload: the layers do the work")
	assert_eq(music.pending, "", "nothing queued")


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
	var track: Dictionary = music.tracks[music.current_track()]
	assert_eq(_loaded.size(), (track["stems"] as Array).size() if track.has("stems") else 1, "its files were loaded once")
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
	music.set_state("victory")
	assert_eq(music.pending, music.track_for("victory"), "the victory bed is queued, not cut in")
	assert_eq(music.current_track(), music.track_for("lull"), "the fight keeps playing until the bar ends")


## Round 8 (control's check on builder0): the test above failed on a loaded machine. `set_state` cut in whenever the audio
## server didn't yet report the bed it had just started as playing, which is up to the mixing thread, not the director.
## Here the player reports stopped right after the lull starts (what a busy audio thread looks like): still queued.
func test_a_bed_the_audio_server_has_not_reported_yet_still_waits_for_the_bar() -> void:
	var music := _director()
	add_to_tree(music)
	await wait_physics_frames(1)
	music.set_state("lull")
	for player in music.find_children("*", "AudioStreamPlayer", true, false):
		(player as AudioStreamPlayer).stop()
	music.set_state("victory")
	assert_eq(music.pending, music.track_for("victory"), "the victory bed is queued, not cut in")
	assert_eq(music.current_track(), music.track_for("lull"), "the lull is still the bed until the bar line")


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
	assert_eq(music.pending, music.track_for("skirmish"), "contact queues the fight track, at the next bar line")
	assert_eq(music.current_track(), music.track_for("lull"), "the lull bed plays until then")
	assert_true(music.current_intensity() > 0.0, "and the layers will read the match's intensity")


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


func test_on_a_bar_line_the_fight_builds_one_layer_at_a_time() -> void:
	## At thirty a side first contact takes the intensity from 0.4 to 0.9 in under a second; on bar lines that must
	## be a build over several bars, not a cut from pad to full band.
	var music := _director()
	add_to_tree(music)
	await wait_physics_frames(1)
	music.set_state("skirmish")
	music.update_layers(0.05, "skirmish")
	var quiet := music.layers.size()
	assert_true(music.update_layers(0.95, "battle", true), "a bar line in a battle changes the arrangement")
	assert_eq(music.layers.size(), quiet + 1, "by one layer")
	music.update_layers(0.95, "battle", true)
	assert_eq(music.layers.size(), quiet + 2, "and one more on the next bar line")
	music.update_layers(0.05, "lull", true)
	assert_eq(music.layers.size(), quiet + 1, "and it comes down one at a time too")


func test_a_bar_line_is_counted_once_even_if_the_position_jitters_back() -> void:
	assert_true(not MusicDirector.is_new_bar(3, 3), "the same bar is not a bar line")
	assert_true(not MusicDirector.is_new_bar(2, 3), "a position reported just before the line again is not one")
	assert_true(MusicDirector.is_new_bar(4, 3), "the next bar is")
	assert_true(MusicDirector.is_new_bar(0, 3), "the loop wrapping back to the start is")
	assert_true(MusicDirector.is_new_bar(0, -1), "the first bar of a new track is")


func test_stems_loop_by_themselves_and_keep_time_without_a_playback_position() -> void:
	## AudioStreamSynchronized reports no position, so the director can neither seek it nor read bars from it.
	var music := MusicDirector.new()
	assert_true(music.load_tracks(MUSIC), "the manifest loads")
	music.load_stream = func(path: String) -> AudioStream: return load(path) as AudioStream
	add_to_tree(music)
	await wait_physics_frames(1)
	music.set_state("skirmish")
	var synced := music._players[music._current].stream as AudioStreamSynchronized
	assert_true(synced != null, "the fight plays as one synchronized stream")
	for index in synced.stream_count:
		var part := synced.get_sync_stream(index) as AudioStreamOggVorbis
		assert_true(part != null and part.loop, "stem %d loops by itself" % index)
	var shared := load(String(music.tracks[music.current_track()]["stems"][0]["file"]).insert(0, "res://assets/music/")) as AudioStreamOggVorbis
	var first := music.position_s()
	await wait_physics_frames(30)
	assert_true(music.position_s() > first, "the director's own clock moves (%.3f → %.3f)" % [first, music.position_s()])
	assert_true(shared != null and not shared.loop, "the shared resource isn't changed")


func test_a_stem_track_waits_for_its_first_bar_line() -> void:
	var music := MusicDirector.new()
	assert_true(music.load_tracks(MUSIC), "the manifest loads")
	music.load_stream = func(path: String) -> AudioStream: return load(path) as AudioStream
	add_to_tree(music)
	await wait_physics_frames(1)
	music.set_state("skirmish")
	assert_true(not music._crossed_bar_line(), "the bar the track starts in is not a bar line")


func test_equally_fitting_tracks_rotate_by_match_not_by_moment() -> void:
	var music := _director()
	music.tracks = {
		"treadmill": {"stems": [{"file": "a.ogg", "from": 0.0}], "states": ["battle"], "intensity": 0.6},
		"foundry": {"stems": [{"file": "b.ogg", "from": 0.0}], "states": ["battle"], "intensity": 0.6},
		"bed": {"file": "c.ogg", "states": ["battle"], "intensity": 0.9},
	}
	var seen := {}
	for match_pick in 4:
		music.rotation = match_pick
		seen[music.track_for("battle")] = true
		assert_eq(music.track_for("battle"), music.track_for("battle"), "one match keeps its pick")
	assert_eq(seen.keys().size(), 2, "both fight tracks get played across matches, the single bed never")
