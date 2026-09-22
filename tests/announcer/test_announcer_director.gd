extends TestCase
## Announcer N2: the line library's matching and slot filling, the booth's memory, and the director's timing rules.
## Unit tests use tiny in-test libraries; the fixture tests run the real library over every fixture.

const FIXTURES := "res://tests/announcer/fixtures/"
const SCENARIOS := ["close_match", "blowout", "comeback", "friendly_fire_disaster", "scouts_vs_tanks", "control_swing",
		"gangs_vs_law", "syndicate_showcase"]
const VOCABULARY := {
	"team": {"green": "Green", "rust": "Rust"},
	"team_s": {"green": "Green's", "rust": "Rust's"},
	"unit": {"scout": "scout", "tank": "tank", "ifv": "IFV"},
	"units": {"scout": "scouts", "tank": "tanks", "ifv": "IFVs"},
}


static func tiny(lines: Array, moments: Dictionary) -> AnnouncerLibrary:
	var library := AnnouncerLibrary.new()
	library.setup({"vocabulary": VOCABULARY, "lines": lines},
			{"moments": moments, "counters": {"ifv": ["scout"], "scout": ["tank"], "tank": ["ifv"]},
			"seconds_per_word": {"caller": 0.3, "color": 0.4, "pa": 0.36}})
	return library


static func moment_of(library: AnnouncerLibrary, kind: String, tags: Array, slots: Dictionary, t: float = 10.0) -> Dictionary:
	var memory := AnnouncerMemory.new(library)
	return memory.moment(kind, t, tags, slots, "")


## Round 10 stretch: the Veteran calls something early and says so later. The prediction sets a memory flag at first
## contact (the moment that reaches the air in every match); the callback is only eligible once that flag is set, and
## only for a moment that happened AFTER it.
func test_a_callback_waits_for_the_prediction_that_earns_it() -> void:
	var library := tiny([
		{"id": "p", "speaker": "color", "act": "analysis", "tags": ["contact"], "sets": ["predicted_scouts"],
			"text": "Those scouts are the whole plan."},
		{"id": "back", "speaker": "color", "act": "analysis", "tags": ["kill", "victim_scout"],
			"needs": ["predicted_scouts"], "text": "There go the eyes, like I said."},
	], {"contact": {"beats": []}, "kill": {"beats": []}})
	var kill := moment_of(library, "kill", ["victim_scout"], {}, 30.0)
	assert_eq(library.candidates("color", ["analysis"], kill, {}, "").size(), 0,
			"without the prediction there is no callback to make")
	assert_eq(library.candidates("color", ["analysis"], kill, {"predicted_scouts": 12.0}, "")[0]["id"], "back",
			"predicted at first contact, called back on the kill")
	assert_eq(library.candidates("color", ["analysis"], kill, {"predicted_scouts": 45.0}, "").size(), 0,
			"a flag set after the moment is not a prediction, it is hindsight")


static func event(t: float, type: String, fields: Dictionary) -> Dictionary:
	var made := {"tick": roundi(t * 60), "t": t, "type": type}
	made.merge(fields)
	return made


static func start_event(green: Array, rust: Array) -> Dictionary:
	var teams: Array = []
	for pair in [["green", green], ["rust", rust]]:
		var units: Array = []
		for index in pair[1].size():
			units.append({"id": "%s_%d" % [pair[0], index], "unit": pair[1][index]})
		teams.append({"team": pair[0], "faction": "condemned", "units": units})
	return event(0.0, "match_start", {"arena": "foundry", "budget": 1000, "teams": teams})


static func kill(t: float, killer: String, victim: String, killer_unit: String, victim_unit: String) -> Dictionary:
	return event(t, "unit_destroyed", {"victim": victim, "victim_unit": victim_unit, "victim_team": victim.get_slice("_", 0),
			"killer": killer, "killer_unit": killer_unit, "killer_team": killer.get_slice("_", 0), "friendly": false})


func test_a_line_needs_all_its_tags_and_none_of_its_without_tags() -> void:
	var library := tiny([
		{"id": "generic", "speaker": "caller", "act": "call", "tags": ["kill"], "text": "Down!"},
		{"id": "upset", "speaker": "caller", "act": "call", "tags": ["kill", "upset"], "text": "Upset!"},
		{"id": "not_final", "speaker": "caller", "act": "call", "tags": ["kill"], "without": ["final_kill"], "text": "More to come!"},
		{"id": "no_kind", "speaker": "caller", "act": "call", "tags": ["upset"], "text": "Kindless lines never fit."},
		{"id": "anything", "speaker": "caller", "act": "call", "tags": ["any"], "text": "Wow!"},
	], {"kill": {}})
	var ids := func(found: Dictionary) -> Array:
		return library.candidates("caller", ["call"], found, {}).map(func(line: Dictionary) -> String: return line["id"])
	assert_eq(ids.call(moment_of(library, "kill", [], {})), ["generic", "not_final", "anything"], "a plain kill")
	assert_eq(ids.call(moment_of(library, "kill", ["upset"], {})), ["generic", "upset", "not_final", "anything"], "an upset")
	assert_eq(ids.call(moment_of(library, "kill", ["final_kill"], {})), ["generic", "anything"], "without excludes")
	assert_eq(library.specificity(library.by_id["upset"]), 1, "matching upset makes a line more specific")


func test_slots_are_spoken_capitalized_and_required() -> void:
	var library := tiny([
		{"id": "count", "speaker": "caller", "act": "call", "tags": ["kill"], "text": "{team_s} {unit} leaves {count}. {count} left!"},
		{"id": "arena", "speaker": "caller", "act": "call", "tags": ["kill"], "text": "Welcome to {arena}."},
	], {"kill": {}})
	var slots := {"team": "rust", "unit": "ifv", "count": 2}
	assert_eq(library.fill(library.by_id["count"], slots), "Rust's IFV leaves two. Two left!", "slots speak and sentences start capitalized")
	var found := moment_of(library, "kill", [], slots)
	var ids: Array = library.candidates("caller", ["call"], found, {}).map(func(line: Dictionary) -> String: return line["id"])
	assert_eq(ids, ["count"], "a line whose slot has no value in this moment (or no vocabulary) is not eligible")


func test_recorded_clips_set_how_long_a_line_takes() -> void:
	var library := tiny([{"id": "k", "speaker": "caller", "act": "call", "tags": ["kill"], "text": "{team} is down to {count}!"}], {"kill": {}})
	var line: Dictionary = library.by_id["k"]
	var estimated := library.line_seconds(line, {"team": "rust", "count": 2}, "Rust is down to two!")
	assert_near(estimated, library.estimate_seconds("caller", "Rust is down to two!"), 0.001, "no manifest: estimated")
	var path := ProjectSettings.globalize_path("res://build/test_announcer_manifest.json")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	# One recording per realization: the duration is that clip's, with nothing to add up.
	file.store_string(JSON.stringify({"lines": {"k": {"speaker": "caller",
			"variants": {"2.rust": "k@2.rust"}}},
			"clips": {"k@2.rust": {"duration_s": 1.6}}}))
	file.close()
	assert_true(library.load_manifest(path), "the manifest loads")
	assert_eq(AnnouncerLibrary.variant_key(line["text"], {"team": "rust", "count": 2}), "2.rust",
			"the key is the slot values in sorted base-slot order, which recording_plan.variant_key must match")
	assert_near(library.line_seconds(line, {"team": "rust", "count": 2.0}, "Rust is down to two!"), 1.6, 0.001,
			"the length of the one clip it will play")
	assert_near(library.line_seconds(line, {"team": "green", "count": 2}, "Green is down to two!"),
			library.estimate_seconds("caller", "Green is down to two!"), 0.001,
			"a realization not recorded yet: estimated")
	DirAccess.remove_absolute(path)


func test_needs_only_sees_flags_set_before_the_moment() -> void:
	var library := tiny([{"id": "again", "speaker": "caller", "act": "call", "tags": ["friendly_fire"],
			"needs": ["said_friendly_{team}"], "text": "Again!"}], {"friendly_fire": {}})
	var line: Dictionary = library.by_id["again"]
	var tags := {"friendly_fire": true}
	assert_true(not library.eligible(line, tags, {"team": "rust"}, {}, "", 10.0), "nothing said yet")
	assert_true(not library.eligible(line, tags, {"team": "rust"}, {"said_friendly_rust": 10.5}, "", 10.0),
			"a flag set while calling this same moment doesn't count")
	assert_true(library.eligible(line, tags, {"team": "rust"}, {"said_friendly_rust": 4.0}, "", 10.0), "said earlier")
	assert_true(not library.eligible(line, tags, {"team": "green"}, {"said_friendly_rust": 4.0}, "", 10.0), "flags name the team")
	var welcome := {"id": "w", "speaker": "pa", "act": "welcome", "tags": ["friendly_fire"], "unless_flags": ["welcomed"],
			"text": "Welcome.", "slots": PackedStringArray()}
	assert_true(library.eligible(welcome, tags, {}, {}, "", 1.0), "nobody has welcomed the crowd yet")
	assert_true(not library.eligible(welcome, tags, {}, {"welcomed": 0.5}, "", 1.0), "a second welcome is skipped")


func test_memory_notices_first_blood_counters_upsets_streaks_and_last_units() -> void:
	var library := tiny([], {})
	var memory := AnnouncerMemory.new(library)
	memory.observe(start_event(["ifv", "ifv", "tank", "scout"], ["scout", "scout", "tank", "ifv"]))
	var first: Dictionary = memory.observe(kill(20.0, "green_0", "rust_0", "ifv", "scout"))[0]
	assert_true(first["tag_set"].has("first_blood") and first["tag_set"].has("counter"), "IFV beats scout, first: %s" % [first["tags"]])
	assert_eq(first["slots"]["count"], 3, "Rust has three left")
	var second: Dictionary = memory.observe(kill(25.0, "green_1", "rust_1", "ifv", "scout"))[0]
	assert_true(not second["tag_set"].has("first_blood") and not second["tag_set"].has("streak"), "two kills isn't a streak")
	var third: Dictionary = memory.observe(kill(30.0, "green_2", "rust_3", "tank", "ifv"))[0]
	assert_true(third["tag_set"].has("streak") and third["slots"]["streak"] == 3, "three unanswered: %s" % [third["tags"]])
	var upset: Dictionary = memory.observe(kill(32.0, "rust_2", "green_0", "tank", "ifv"))[0]
	assert_true(not upset["tag_set"].has("upset") and upset["tag_set"].has("counter"), "tank beats IFV is the counter")
	var surprise: Dictionary = memory.observe(kill(35.0, "rust_2", "green_3", "tank", "scout"))[0]
	assert_true(surprise["tag_set"].has("upset"), "a tank beating a scout is the upset: %s" % [surprise["tags"]])
	var last: Dictionary = memory.observe(kill(40.0, "green_1", "rust_2", "ifv", "tank"))[0]
	assert_true(last["tag_set"].has("final_kill") and not last["tag_set"].has("upset"),
			"an IFV beating a tank is an upset, but not five seconds after the last one: %s" % [last["tags"]])
	var again: Array = AnnouncerMemory.new(library).observe(start_event(["tank", "tank"], ["scout", "scout"]))
	assert_eq(again.map(func(found: Dictionary) -> String: return found["kind"]), ["intro", "army", "army", "tape", "preview"],
			"match_start opens with the intro, both armies, the tale of the tape, and the matchup")


func test_a_kill_in_the_lead_swings_standings_and_comebacks() -> void:
	var memory := AnnouncerMemory.new(tiny([], {}))
	memory.observe(start_event(["tank", "tank", "tank"], ["tank", "tank", "tank"]))
	memory.observe(kill(10.0, "rust_0", "green_0", "tank", "tank"))
	memory.observe(kill(12.0, "rust_0", "green_1", "tank", "tank"))
	var back: Dictionary = memory.observe(kill(20.0, "green_2", "rust_0", "tank", "tank"))[0]
	assert_true(back["tag_set"].has("team_trailing"), "Green still trails after one back")
	var level: Dictionary = memory.observe(kill(25.0, "green_2", "rust_1", "tank", "tank"))[0]
	assert_true(level["tag_set"].has("even") and level["tag_set"].has("comeback"), "from two down to level: %s" % [level["tags"]])


static func run(library: AnnouncerLibrary, events: Array, seed_value: int = 1) -> AnnouncerDirector:
	var director := AnnouncerDirector.new(library, seed_value)
	director.run_timeline(events)
	return director


func test_cooldowns_stop_the_same_kind_of_call_repeating() -> void:
	var library := tiny([
		{"id": "hit1", "speaker": "caller", "act": "call", "tags": ["big_hit"], "text": "Big hit!"},
		{"id": "hit2", "speaker": "caller", "act": "call", "tags": ["big_hit"], "text": "Another big hit!"},
	], {"big_hit": {"priority": 25, "stale_s": 3, "cooldown_s": 9, "beats": [{"steps": [{"speaker": "caller", "act": "call"}]}]}})
	var events: Array = [start_event(["tank"], ["tank"])]
	for t in [10.0, 13.0, 21.0]:
		events.append(event(t, "damage", {"shooter": "green_0", "shooter_unit": "tank", "victim": "rust_0", "victim_unit": "tank",
				"hull": 0.2, "shield": 0.0, "critical": true, "weak_spot": true}))
	events.append(event(30.0, "match_end", {"winner": "draw", "reason": "time", "duration_seconds": 30.0,
			"units_left": {"green": 1, "rust": 1}, "kills_by_unit": {"green": {}, "rust": {}}}))
	var director := run(library, events)
	assert_eq(director.cues.map(func(cue: Dictionary) -> float: return cue["t"]), [10.0, 21.0], "the hit at 13 s is inside the cooldown")


func test_a_big_moment_cuts_off_a_long_line_and_stale_ones_are_dropped() -> void:
	var library := tiny([
		{"id": "lore", "speaker": "color", "act": "lore", "tags": ["lull"],
			"text": "Let me tell you a long story about the old days, when the floor was sand and the lights were torches and nobody wore a seatbelt."},
		{"id": "kill", "speaker": "caller", "act": "call", "tags": ["kill"], "text": "Down goes the {victim_unit}!"},
		{"id": "hit", "speaker": "caller", "act": "call", "tags": ["big_hit"], "text": "Big hit!"},
	], {
		"lull": {"priority": 5, "stale_s": 3, "beats": [{"steps": [{"speaker": "color", "act": "lore"}]}]},
		"kill": {"priority": 60, "stale_s": 5, "beats": [{"steps": [{"speaker": "caller", "act": "call"}]}]},
		"big_hit": {"priority": 25, "stale_s": 1, "beats": [{"steps": [{"speaker": "caller", "act": "call"}]}]},
	})
	var events: Array = [start_event(["tank", "tank"], ["scout", "scout"])]
	events.append(kill(14.0, "green_0", "rust_0", "tank", "scout"))
	events.append(event(14.1, "damage", {"shooter": "green_1", "shooter_unit": "tank", "victim": "rust_1", "victim_unit": "scout",
			"hull": 0.2, "shield": 0.0, "critical": true, "weak_spot": true}))
	events.append(event(40.0, "match_end", {"winner": "green", "reason": "time", "duration_seconds": 40.0,
			"units_left": {"green": 2, "rust": 1}, "kills_by_unit": {"green": {"tank": 1}, "rust": {}}}))
	var director := run(library, events)
	var lore: Dictionary = director.cues[0]
	assert_eq(lore["line_id"], "lore", "a quiet start gets the Veteran's story")
	assert_true(lore["cut"] and float(lore["end"]) <= 14.1, "the kill cuts the story off (%s)" % [lore])
	assert_eq(director.cues[1]["line_id"], "kill", "then the kill is called")
	assert_near(float(director.cues[1]["t"]), 14.1, 0.25, "straight away")
	assert_true(director.cues.all(func(cue: Dictionary) -> bool: return cue["line_id"] != "hit"), "the big hit went stale behind the kill")
	assert_true(director.decisions.any(func(note: Dictionary) -> bool: return String(note["text"]).contains("stale")),
			"and the decision log says why")


func test_kills_waiting_together_merge_into_one_trade_call() -> void:
	var library := tiny([
		{"id": "story", "speaker": "pa", "act": "welcome", "tags": ["intro"], "text": "Good evening and welcome to a very long introduction with many words in it for everyone."},
		{"id": "kill", "speaker": "caller", "act": "call", "tags": ["kill"], "text": "Down!"},
		{"id": "trade", "speaker": "caller", "act": "call", "tags": ["kill", "trade"], "text": "They're trading, {kills} down!"},
	], {
		"intro": {"priority": 90, "stale_s": 60, "beats": [{"steps": [{"speaker": "pa", "act": "welcome"}]}]},
		"kill": {"priority": 60, "stale_s": 6, "beats": [{"steps": [{"speaker": "caller", "act": "call"}]},
				{"when": ["trade"], "steps": [{"speaker": "caller", "act": "call", "require": ["trade"]}]}]},
	})
	var events: Array = [start_event(["tank", "tank"], ["tank", "tank"])]
	events.append(kill(1.0, "green_0", "rust_0", "tank", "tank"))
	events.append(kill(2.0, "rust_1", "green_0", "tank", "tank"))
	events.append(kill(2.5, "green_1", "rust_1", "tank", "tank"))
	events.append(event(30.0, "match_end", {"winner": "green", "reason": "elimination", "duration_seconds": 30.0,
			"units_left": {"green": 1, "rust": 0}, "kills_by_unit": {"green": {"tank": 2}, "rust": {"tank": 1}}}))
	var director := run(library, events)
	var texts: Array = director.cues.map(func(cue: Dictionary) -> String: return cue["text"])
	assert_eq(texts.slice(0, 2), ["Good evening and welcome to a very long introduction with many words in it for everyone.",
			"They're trading, three down!"], "three kills during the welcome become one call")


func test_answers_stay_on_the_setup_topic() -> void:
	var library := tiny([
		{"id": "q", "speaker": "caller", "act": "setup_question", "tags": ["lull"], "topic": "scouts", "text": "Scouts?"},
		{"id": "a_scouts", "speaker": "color", "act": "answer_agree", "tags": ["lull"], "topic": "scouts", "text": "Eyes."},
		{"id": "a_tanks", "speaker": "color", "act": "answer_agree", "tags": ["lull"], "topic": "tanks", "text": "Walls."},
	], {"lull": {"priority": 5, "stale_s": 3, "beats": [{"steps": [{"speaker": "caller", "act": "setup_question"},
			{"speaker": "color", "act": ["answer_agree", "answer_disagree"], "answers": true}]}]}})
	var events: Array = [start_event(["tank"], ["tank"]), event(20.0, "match_end", {"winner": "draw", "reason": "time",
			"duration_seconds": 20.0, "units_left": {"green": 1, "rust": 1}, "kills_by_unit": {"green": {}, "rust": {}}})]
	var director := run(library, events)
	assert_eq(director.cues.map(func(cue: Dictionary) -> String: return cue["line_id"]), ["q", "a_scouts"], "the answer fits the question")


func test_every_fixture_reads_as_a_broadcast() -> void:
	var library := AnnouncerLibrary.load_default()
	assert_eq(library.errors, PackedStringArray(), "the real library loads")
	for name in SCENARIOS:
		var events: Array = AnnouncerEvents.load_file(FIXTURES + name + ".jsonl")["events"]
		for seed_value in [1, 2, 3]:
			var director := run(library, events, seed_value)
			var label := "%s seed %d" % [name, seed_value]
			var cues := director.cues
			# Scaled to the match, not a flat number: a 33-second blowout legitimately gets fewer calls than a
			# two-and-a-half-minute control swing, and a flat floor was really asserting how long the fixtures are.
			var duration := float(events[-1].get("t", 60.0))
			var wanted := maxi(8, int(duration / 10.0))
			assert_true(cues.size() >= wanted, "%s: the booth talks (%d lines in %.0f s, wanted %d)"
					% [label, cues.size(), duration, wanted])
			assert_true(float(cues[0]["t"]) < 1.0 and cues[0]["moment"] == "intro", "%s: it opens with the intro" % label)
			assert_eq(cues[-1]["moment"], "outro", "%s: it closes with the sign-off" % label)
			assert_true(cues.any(func(cue: Dictionary) -> bool: return cue["moment"] == "result"), "%s: the result is called" % label)
			var ids := {}
			for index in cues.size():
				var cue: Dictionary = cues[index]
				assert_true(not ids.has(cue["line_id"]), "%s: %s repeats" % [label, cue["line_id"]])
				ids[cue["line_id"]] = true
				assert_true(not String(cue["text"]).contains("{"), "%s: unfilled slot in %s" % [label, cue["text"]])
				if index > 0:
					assert_true(float(cue["t"]) >= float(cues[index - 1]["end"]), "%s: %s overlaps the line before" % [label, cue["line_id"]])


func test_a_long_standoff_gets_quieter_instead_of_running_out_of_stories() -> void:
	var library := AnnouncerLibrary.load_default()
	var events: Array = [start_event(["tank", "tank"], ["tank", "tank"]),
		event(10.0, "first_contact", {"team": "green", "unit_id": "green_0", "unit": "tank", "target_id": "rust_0", "target_unit": "tank"}),
		event(310.0, "match_end", {"winner": "draw", "reason": "time", "duration_seconds": 310.0,
			"units_left": {"green": 2, "rust": 2}, "kills_by_unit": {"green": {}, "rust": {}}})]
	var director := run(library, events, 3)
	var quiet: Array = director.cues.filter(func(cue: Dictionary) -> bool: return cue["moment"] == "lull" and cue["t"] > 30.0 and cue["t"] < 310.0)
	var beats := {}
	for cue in quiet:
		beats[snappedf(cue["event_t"], 0.01)] = true
	var starts: Array = beats.keys()
	starts.sort()
	# Measured 2026-09-15: 9-10 banter beats with the backoff, 16-19 without it (seeds 1-4).
	assert_true(starts.size() >= 5 and starts.size() <= 13, "some banter across five quiet minutes, not wall-to-wall (%d beats)" % starts.size())


func test_the_same_seed_gives_the_same_broadcast_and_the_game_rng_is_untouched() -> void:
	var library := AnnouncerLibrary.load_default()
	var events: Array = AnnouncerEvents.load_file(FIXTURES + "comeback.jsonl")["events"]
	var texts := func(director: AnnouncerDirector) -> Array:
		return director.cues.map(func(cue: Dictionary) -> String: return "%s %s" % [cue["t"], cue["line_id"]])
	seed(4242)
	var expected := randi()
	seed(4242)
	var first := run(library, events, 7)
	assert_eq(randi(), expected, "the director never draws from the global random generator")
	assert_eq(texts.call(run(library, events, 7)), texts.call(first), "same seed, same broadcast")
	assert_true(texts.call(run(library, events, 8)) != texts.call(first), "another seed, another broadcast")
