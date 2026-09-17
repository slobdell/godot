extends TestCase
## Announcer N6: the booth in a live match. The adapter turns Match signals into a valid K5 timeline, the booth calls
## it, and the voice player finds the right clips and ducks the world bus.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _match() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var green := {"name": "Us", "squads": [{"name": "Alpha", "units": [{"unit": "tank"}, {"unit": "scout"}]},
			{"name": "Bravo", "units": [{"unit": "ifv"}]}]}
	var rust := {"name": "Them", "squads": [{"name": "X", "units": [{"unit": "tank"}, {"unit": "tank"}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, green), "", "setup: green doctrine")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, rust), "", "setup: rust doctrine")
	game_match.elimination = true
	return game_match


func _kill(game_match: Match, victim_name: String, killer_name: String) -> void:
	var victim := game_match.tanks.get_node(victim_name) as Tank
	victim.apply_damage(100000)
	var killer := game_match.tanks.get_node_or_null(killer_name) as Tank
	if killer != null and killer.team == victim.team:
		game_match.tank_destroyed.emit(victim, killer_name)
		game_match.friendly_fire.emit(victim, killer_name, 300, true)
	elif killer != null:
		game_match._score_kill(killer.team, killer_name, victim)
	else:
		game_match.tank_destroyed.emit(victim, "hazard:fire_pit")


func test_a_live_match_becomes_a_valid_k5_timeline() -> void:
	var game_match := _match()
	var adapter := MatchEventAdapter.new(game_match, "scrapyard")
	var events: Array = []
	var step := func(frames: int) -> void:
		for i in frames:
			await wait_physics_frames(1)
			events.append_array(adapter.poll())
	await step.call(2)
	assert_eq(events[0]["type"], "match_start", "the roster comes first")
	assert_eq(events[0]["teams"][0]["units"].map(func(u: Dictionary) -> String: return u["unit"]), ["tank", "scout", "ifv"],
			"units by type, in the match's order")
	var scout := game_match.tanks.get_node("Green_Alpha_2") as Tank
	scout.apply_damage(int(scout.max_health * 0.9))
	await step.call(2)
	_kill(game_match, "Rust_X_1", "Green_Alpha_1")
	_kill(game_match, "Green_Bravo_1", "Green_Alpha_1")
	await step.call(2)
	(game_match.tanks.get_node("Green_Alpha_1") as Tank).fired.emit(Vector3.ZERO, Vector3.FORWARD)
	_kill(game_match, "Green_Alpha_2", "")
	_kill(game_match, "Rust_X_2", "Green_Alpha_1")
	await step.call(6)
	var types: Array = events.map(func(e: Dictionary) -> String: return e["type"])
	assert_eq(AnnouncerEvents.validate_timeline(events), PackedStringArray(), "the recorded timeline is valid K5: %s" % [types])
	for wanted in ["damage", "first_contact", "unit_destroyed", "squad_wiped", "match_end"]:
		assert_true(wanted in types, "a live match produces %s" % wanted)
	var deaths := events.filter(func(e: Dictionary) -> bool: return e["type"] == "unit_destroyed")
	assert_eq(deaths.map(func(e: Dictionary) -> String: return e["cause"] + (" friendly" if e["friendly"] else "")),
			["weapon", "weapon friendly", "hazard", "weapon"], "kills, a teamkill, and the arena")
	assert_eq(events.filter(func(e: Dictionary) -> bool: return e["type"] == "friendly_fire").size(), 0,
			"a fatal friendly hit is reported once, as the kill")
	assert_eq(events[-1]["winner"], "green", "Green wins by elimination")


func test_the_booth_calls_a_live_match_in_text_mode() -> void:
	var game_match := _match()
	var booth := AnnouncerBooth.new()
	booth.game_match = game_match
	booth.setup("foundry", 5)
	var said: Array = []
	booth.line_started.connect(func(cue: Dictionary) -> void: said.append(cue))
	game_match.add_child(booth)
	await wait_physics_frames(3)
	assert_true(not said.is_empty() and said[0]["moment"] == "intro", "the booth opens the match: %s" % [said])
	# Skip past the welcome (the booth's clock is the match tick), then a kill gets called within a few frames.
	game_match.tick += SimClock.TICK_RATE * 25
	await wait_physics_frames(2)
	_kill(game_match, "Rust_X_1", "Green_Alpha_1")
	for jump in 4:  # the rest of the intro is spoken first: let a few seconds pass
		game_match.tick += 90
		await wait_physics_frames(2)
	assert_true(said.any(func(cue: Dictionary) -> bool: return cue["moment"] == "kill"), "and calls the kill: %s" % [
			said.map(func(cue: Dictionary) -> String: return "%s %s" % [cue["t"], cue["moment"]])])
	assert_eq(booth.recorded[0]["type"], "match_start", "everything it heard is kept for --announcer-record")


func test_the_voice_plays_a_cues_clips_and_ducks_the_world() -> void:
	var world := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(world, AnnouncerVoice.WORLD_BUS)
	var voice := AnnouncerVoice.new()
	voice.clips_dir = "/clips"
	# One whole sentence per realization, chosen by the cue's variant key: nothing is joined at playback.
	voice.manifest = {"lines": {"k": {"speaker": "caller", "variants": {"law.tank": "k@law.tank", "gangs.scout": "k@gangs.scout"}}},
			"clips": {"k@law.tank": {"file": "caller/k-law-tank.ogg"}, "k@gangs.scout": {"file": "caller/k-gangs-scout.ogg"}}}
	var loaded: Array = []
	voice.load_stream = func(path: String) -> AudioStream:
		loaded.append(path)
		var silence := AudioStreamWAV.new()
		silence.data = PackedByteArray([0, 0, 0, 0])
		return silence
	add_to_tree(voice)
	var cue := {"line_id": "k", "variant_key": "law.tank"}
	assert_eq(voice.files_for(cue), PackedStringArray(["/clips/caller/k-law-tank.ogg"]),
			"the cue plays the one recording made for its slot values")
	assert_true(voice.play(cue), "a recorded cue plays")
	assert_eq(loaded, ["/clips/caller/k-law-tank.ogg"], "and only that one")
	assert_eq(voice.files_for({"line_id": "k", "variant_key": "syndicate.burner"}), PackedStringArray(),
			"a realization nobody recorded means subtitles only, never the wrong sentence")
	assert_true(AudioServer.get_bus_index(AnnouncerVoice.BUS) >= 0, "the announcer has its own bus")
	var ducked := false
	for index in AudioServer.get_bus_effect_count(world):
		var compressor := AudioServer.get_bus_effect(world, index) as AudioEffectCompressor
		ducked = ducked or (compressor != null and compressor.sidechain == AnnouncerVoice.BUS)
	assert_true(ducked, "the world bus ducks under the announcer")
	voice.free()
	AudioServer.remove_bus(AudioServer.get_bus_index(AnnouncerVoice.WORLD_BUS))
	AudioServer.remove_bus(AudioServer.get_bus_index(AnnouncerVoice.BUS))


func test_each_side_is_called_by_the_faction_it_fielded() -> void:
	## Control (round 5): from the faction menu, gangs against the Law, the booth called both sides the Condemned,
	## because the adapter gave every side one default faction. It reads the units the match actually built now.
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var gangs := Units.roster("gangs")
	var law := Units.roster("law")
	var green := {"name": "Us", "squads": [{"name": "Alpha", "units": [{"unit": gangs[0]}, {"unit": gangs[1]}]}]}
	var rust := {"name": "Them", "squads": [{"name": "X", "units": [{"unit": law[0]}, {"unit": law[1]}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, green), "", "setup: a gang army")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, rust), "", "setup: a Law army")
	var adapter := MatchEventAdapter.new(game_match, "yard")
	var events: Array = []
	for i in 3:
		await wait_physics_frames(1)
		events.append_array(adapter.poll())
	assert_true(not events.is_empty() and events[0]["type"] == "match_start", "the match started")
	assert_eq(events[0]["teams"][0]["faction"], "gangs", "green fielded the gangs, and is called that")
	assert_eq(events[0]["teams"][1]["faction"], "law", "rust fielded the Law")


func test_match_time_follows_the_physics_tick_rate() -> void:
	## Round 5's 30 Hz tick: thirty ticks must be one second to the booth, not half of one.
	var game_match := _match()
	var adapter := MatchEventAdapter.new(game_match, "yard")
	var saved := Engine.physics_ticks_per_second
	game_match.tick = 30
	Engine.physics_ticks_per_second = 30
	assert_near(adapter.seconds(), 1.0, 0.0001, "30 ticks at 30 Hz is a second")
	Engine.physics_ticks_per_second = 60
	assert_near(adapter.seconds(), 0.5, 0.0001, "and half of one at 60 Hz")
	Engine.physics_ticks_per_second = saved
