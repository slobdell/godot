extends TestCase
## X6: the music director picks a bed per MatchMood state, crossfades on the beat, and plays stingers. The audio
## itself can't be asserted headless, so these cover the decisions: which track, when the fade may start, and that
## a missing file is silence rather than a crash.

const MUSIC := "res://assets/music"

var _loaded: Array[String] = []


func _director() -> MusicDirector:
	var music := MusicDirector.new()
	# S5 (ship, round 18): freed at teardown whether or not the test adds it to the tree. Most tests here never do, and
	# the node -- with its loader closure, which holds this test case -- was left for the exit-leak report (131 objects).
	_owned_nodes.append(music)
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
	assert_eq(music.current_track(), music.track_for("pre_match"),
			"a match opens on the pre-match bed: the mood says lull, but nobody has fired yet")
	mood.push_event({"tick": 0, "t": 0.0, "type": "match_start", "arena": "foundry", "budget": 1000, "teams": [
		{"team": "green", "faction": "condemned", "units": [{"id": "g1", "unit": "tank"}]},
		{"team": "rust", "faction": "condemned", "units": [{"id": "r1", "unit": "tank"}]}]})
	mood.push_event({"tick": 60, "t": 1.0, "type": "first_contact", "team": "green", "unit": "tank",
			"target_unit": "tank"})
	assert_eq(music.pending, music.track_for("skirmish"), "contact queues the fight track, at the next bar line")
	assert_eq(music.current_track(), music.track_for("pre_match"), "the opening plays until then")
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
		"treadmill": {"stems": [{"file": "a.ogg", "from": 0.0}], "states": ["skirmish", "battle"], "intensity": 0.6},
		"foundry": {"stems": [{"file": "b.ogg", "from": 0.0}], "states": ["skirmish", "battle"], "intensity": 0.6},
		"bed": {"file": "c.ogg", "states": ["battle"], "intensity": 0.9},
	}
	var seen := {}
	for match_seed in 40:
		music.match_seed = match_seed
		music.forget_picks()
		seen[music.track_for("battle")] = true
		assert_eq(music.track_for("battle"), music.track_for("battle"), "one match keeps its pick")
		assert_eq(music.track_for("skirmish"), music.track_for("battle"),
				"skirmish and battle are one fight set: the fight builds, it never changes song")
	assert_eq(seen.keys().size(), 2, "both fight tracks get played across matches, the single bed never")


## Round 12 (the lead): *"I can't tell if it's playing the same music over and over on opening."* He was right: the
## match opened on `lull`, which had one bed, and the pre-match bed was never asked for by anything.
func test_every_music_state_rotates_between_at_least_two_tracks() -> void:
	var music := _director()
	for state in MusicDirector.STATES:
		assert_true(music.candidates_for(state).size() >= 2, "%s rotates between %s" % [state,
				str(music.candidates_for(state))])


func test_the_opening_is_not_the_same_track_every_match() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 12
	var openings := {}
	for match_index in 50:
		var music := _director()
		music.match_seed = dice.randi() & 0x7fffffff
		music.follow(MatchMood.new("green"))
		openings[music.pending if music.pending != "" else music.current_track()] = true
	assert_true(openings.keys().size() >= 2, "50 fresh matches open on %s" % str(openings.keys()))
	var candidates := _director().candidates_for("pre_match")
	for id in openings:
		assert_true(id in candidates, "%s is an opening bed" % id)


func test_the_opening_hands_over_and_a_later_quiet_spell_is_the_lull() -> void:
	assert_eq(MusicDirector.music_state_for("lull", false), "pre_match", "before contact the quiet is the opening")
	assert_eq(MusicDirector.music_state_for("lull", true), "lull", "after it, a quiet spell")
	assert_eq(MusicDirector.music_state_for("skirmish", true), "skirmish", "everything else passes through")
	assert_eq(MusicDirector.music_state_for("victory", true), "victory", "the result too")


func test_a_match_draws_each_state_by_its_own_seed_and_reproducibly() -> void:
	var music := _director()
	var picks_by_seed := {}
	for match_seed in [3, 4, 5, 6, 7, 8]:
		music.match_seed = match_seed
		music.forget_picks()
		var picks := []
		for state in MusicDirector.STATES:
			picks.append(music.track_for(state))
		music.forget_picks()
		var again := []
		for state in MusicDirector.STATES:
			again.append(music.track_for(state))
		assert_eq(again, picks, "seed %d draws the same soundtrack twice" % match_seed)
		picks_by_seed[match_seed] = picks
	var combinations := {}
	for match_seed in picks_by_seed:
		combinations[str(picks_by_seed[match_seed])] = true
	assert_true(combinations.size() >= 3, "six seeds give %d different evenings, not one index into every state"
			% combinations.size())
	# One index for every tie made "track 2 of everything" an evening: the states must not move in lockstep.
	var lockstep := true
	for match_seed in picks_by_seed:
		var picks: Array = picks_by_seed[match_seed]
		var first_index := music.candidates_for(MusicDirector.STATES[0]).find(picks[0])
		for i in MusicDirector.STATES.size():
			var candidates := music.candidates_for(MusicDirector.STATES[i])
			lockstep = lockstep and posmod(first_index, candidates.size()) == candidates.find(picks[i])
	assert_true(not lockstep, "each state draws for itself")


func test_the_track_heard_last_time_waits_its_turn() -> void:
	var music := _director()
	music.history = MusicHistory.new()
	var candidates := music.candidates_for("pre_match")
	var heard := {}
	for match_index in candidates.size():
		music.forget_picks()
		music.match_seed = 99  # the same dice every match: only the memory can move the pick
		var pick := music.track_for("pre_match")
		assert_true(not heard.has(pick), "match %d opens on %s, not a repeat of %s" % [match_index, pick, str(heard.keys())])
		heard[pick] = true
		music.history.heard(pick)
	assert_eq(heard.size(), candidates.size(), "every opening is heard before any comes round again")


func test_the_music_memory_survives_a_restart_and_a_bad_file() -> void:
	var path := "user://test_music_history.json"
	var history := MusicHistory.load_from(path)
	history.heard("a")
	history.heard("b")
	assert_true(history.save(), "it saves")
	var again := MusicHistory.load_from(path)
	assert_true(again.last_heard("b") > again.last_heard("a"), "and remembers the order")
	assert_eq(again.last_heard("never"), -1, "a track never heard is the freshest")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	assert_eq(MusicHistory.load_from(path).last_heard("b"), -1, "a broken memory is no memory, not an error")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Round 13 (G2, the lead: *"Yes let's add garage music"*). The garage asks for its own state and the match's mood
## cannot take it away; FIGHT hands the director back to the mood, which is the opening (`pre_match`).
func test_the_garage_holds_its_own_bed_until_fight_hands_back_to_the_opening() -> void:
	var music := _director()
	add_to_tree(music)
	await wait_physics_frames(1)
	var mood := MatchMood.new("green")
	music.hold("garage")
	music.follow(mood)
	assert_eq(music.state, "garage", "a director that starts in the garage plays the garage, not the match's opening")
	assert_eq(music.current_track(), music.track_for("garage"), "straight away: nothing was playing")
	mood.push_event({"tick": 0, "t": 0.0, "type": "match_start", "arena": "foundry", "budget": 1000, "teams": [
		{"team": "green", "faction": "condemned", "units": [{"id": "g1", "unit": "tank"}]},
		{"team": "rust", "faction": "condemned", "units": [{"id": "r1", "unit": "tank"}]}]})
	assert_eq(music.state, "garage", "the mood moving underneath does not pull the garage's bed")
	music.release()
	assert_eq(music.state, "pre_match", "FIGHT hands over to the match's opening: nobody has fired yet")
	assert_eq(music.pending, music.track_for("pre_match"), "crossfaded on the garage bed's next bar line")
	mood.push_event({"tick": 60, "t": 1.0, "type": "first_contact", "team": "green", "unit": "tank", "target_unit": "tank"})
	assert_eq(music.state, "skirmish", "and from then on it follows the match like any other")


func test_a_released_director_with_no_match_mood_plays_the_opening() -> void:
	var music := _director()
	music.hold("garage")
	music.release()
	assert_eq(music.state, "pre_match", "with no mood yet, the hand-back is still the opening")


## The garage's pool must not be the victory's: one director follows the garage into the match (FIGHT does not reload
## the scene), and a draw is kept per set of tracks, so a shared pool played the garage's blues again on the win.
func test_the_garage_has_its_own_pool_not_the_victory_screens() -> void:
	var music := _director()
	var garage := music.candidates_for("garage")
	var victory := music.candidates_for("victory")
	assert_true(garage.size() >= 2 and victory.size() >= 2, "both rotate: garage %s, victory %s" % [garage, victory])
	for id in garage:
		assert_true(not id in victory, "%s is the garage's, not also the win's" % id)


func test_the_garage_bed_heard_last_time_waits_its_turn() -> void:
	var music := _director()
	music.history = MusicHistory.new()
	var candidates := music.candidates_for("garage")
	var heard := {}
	for visit in candidates.size():
		music.forget_picks()
		music.match_seed = 7  # the same dice every visit: only the memory can move the pick
		var pick := music.track_for("garage")
		assert_true(not heard.has(pick), "visit %d plays %s, not a repeat of %s" % [visit, pick, str(heard.keys())])
		heard[pick] = true
		music.history.heard(pick)
	assert_eq(heard.size(), candidates.size(), "every garage bed is heard before any comes round again")


# ---- Round 16 (play P4): the music carries through the loading screen ---------------------------------------------

## A stand-in for Main: MusicDirector finds and attaches through `game_match`.
class FakeMain extends Node:
	var game_match := Node.new()

	func _init() -> void:
		game_match.name = "Match"
		add_child(game_match)


func test_the_music_carries_through_a_scene_reload_without_restarting() -> void:
	var old := FakeMain.new()
	add_to_tree(old)
	var music := _director()
	music.name = "Music"
	old.game_match.add_child(music)
	await wait_physics_frames(1)
	var old_mood := MatchMood.new("green")
	music.follow(old_mood)
	var opening := music.current_track()
	var loaded := _loaded.size()
	assert_true(opening != "", "the menu's opening is playing")
	assert_eq(MusicDirector.carry(old), music, "carry hands back the director it moved")
	assert_eq(music.get_parent(), tree.root, "it waits on the root, outside the scene being replaced")
	old.free()
	assert_true(is_instance_valid(music), "the old scene going does not take the music with it")
	await wait_physics_frames(2)
	assert_eq(music.current_track(), opening, "through the loader: the same track, still")
	var fresh := FakeMain.new()
	add_to_tree(fresh)
	var mood := MatchMood.new("green")
	assert_eq(MusicDirector.adopt_carried(fresh, mood), music, "the new match adopts it: one director, not two")
	assert_eq(MusicDirector.find(fresh), music, "and finds it where it always looks")
	assert_eq(MusicDirector.carried(tree), null, "nothing is left waiting on the root")
	assert_eq(music.current_track(), opening, "the opening keeps playing into the match: not restarted")
	assert_eq(_loaded.size(), loaded, "its files were not loaded again")
	assert_eq(music.process_mode, Node.PROCESS_MODE_ALWAYS,
			"it plays through the planning pause: a paused Match would pause its players (seen in the launch smoke)")
	old_mood.push_event({"tick": 0, "t": 0.0, "type": "match_start", "arena": "foundry", "budget": 1000, "teams": [
		{"team": "green", "faction": "condemned", "units": [{"id": "g1", "unit": "tank"}]},
		{"team": "rust", "faction": "condemned", "units": [{"id": "r1", "unit": "tank"}]}]})
	old_mood.push_event({"tick": 60, "t": 1.0, "type": "first_contact", "team": "green", "unit": "tank", "target_unit": "tank"})
	assert_eq(music.state, "pre_match", "the old menu's mood no longer moves it")
	mood.push_event({"tick": 0, "t": 0.0, "type": "match_start", "arena": "foundry", "budget": 1000, "teams": [
		{"team": "green", "faction": "condemned", "units": [{"id": "g1", "unit": "tank"}]},
		{"team": "rust", "faction": "condemned", "units": [{"id": "r1", "unit": "tank"}]}]})
	mood.push_event({"tick": 60, "t": 1.0, "type": "first_contact", "team": "green", "unit": "tank", "target_unit": "tank"})
	assert_eq(music.state, "skirmish", "the new match's mood does")


func test_a_launch_without_music_drops_the_carried_director() -> void:
	var old := FakeMain.new()
	add_to_tree(old)
	var music := _director()
	music.name = "Music"
	old.game_match.add_child(music)
	await wait_physics_frames(1)
	MusicDirector.carry(old)
	assert_true(MusicDirector.drop_carried(tree), "a launch with --music=off or --mute lets it go")
	await wait_physics_frames(1)
	assert_true(not is_instance_valid(music), "freed, not left playing on the root")
	assert_eq(MusicDirector.carry(old), null, "carrying from a scene with no music is nothing")


# ---- Round 16 (play P8): a bed change loads nothing on the main thread ---------------------------------------------

func test_the_real_loader_prefetches_every_bed_the_match_will_draw_and_every_stinger() -> void:
	var music := MusicDirector.new()
	assert_true(music.load_tracks(MUSIC), "the manifest loads")
	assert_true(music.uses_default_loader(), "a director the game makes uses the real loader")
	var wanted := music.prefetch_draws()
	if not MusicDirector.threaded_loads():
		assert_eq(wanted.size(), 0, "no threads (the web): nothing is prefetched, the synchronous path stands")
		music.free()
		return
	for state: String in MusicDirector.STATES:
		var id := music.track_for(state)
		var track: Dictionary = music.tracks[id]
		var files: Array = (track["stems"] as Array).map(func(s: Dictionary) -> String: return s["file"]) if track.has("stems") \
				else [track["file"]]
		for file: String in files:
			assert_true(wanted.has(music.dir.path_join(file)), "%s's %s is on its way before it is asked for" % [state, file])
	for id: String in music.stingers:
		assert_true(wanted.has(music.dir.path_join(music.stingers[id]["file"])), "the stinger %s too" % id)
	var path: String = wanted[0]
	var first := music.load_stream.call(path) as AudioStream
	assert_true(first != null, "a prefetched file loads")
	assert_true(music.load_stream.call(path) == first, "and is held: the second ask is the same stream, no reload")
	music.free()


func test_a_stubbed_loader_prefetches_nothing_so_the_bar_line_tests_see_the_old_path() -> void:
	var music := _director()
	assert_true(not music.uses_default_loader(), "a test's loader is not the real one")
	assert_eq(music.prefetch_draws().size(), 0, "and nothing is fetched behind its back")
