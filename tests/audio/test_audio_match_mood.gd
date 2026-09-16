extends TestCase
## L5: MatchMood reads the K5 event stream and says how the match feels. These name the feeling a player would
## recognise, not the arithmetic ("a lone survivor against four is a last stand", not "intensity >= 0.6").

const FIXTURES := "res://tests/announcer/fixtures/"
const SCENARIOS := ["close_match", "blowout", "comeback", "friendly_fire_disaster", "scouts_vs_tanks", "control_swing",
		"gangs_vs_law", "syndicate_showcase"]


static func event(t: float, type: String, fields: Dictionary) -> Dictionary:
	var made := {"tick": roundi(t * 60), "t": t, "type": type}
	made.merge(fields)
	return made


static func start(green: int, rust: int, t: float = 0.0) -> Dictionary:
	var teams: Array = []
	for entry in [["green", green], ["rust", rust]]:
		var units: Array = []
		for index in int(entry[1]):
			units.append({"id": "%s%d" % [entry[0], index], "unit": "tank"})
		teams.append({"team": entry[0], "faction": "condemned", "units": units})
	return event(t, "match_start", {"arena": "foundry", "teams": teams, "budget": 1000})


static func kill(t: float, victim_team: String, friendly: bool = false) -> Dictionary:
	var killer_team := victim_team if friendly else MatchMood.other(victim_team)
	return event(t, "unit_destroyed", {"victim": "v", "victim_unit": "tank", "victim_team": victim_team,
			"killer": "k", "killer_unit": "tank", "killer_team": killer_team, "friendly": friendly})


func test_before_a_shot_is_fired_the_match_is_a_lull() -> void:
	var mood := MatchMood.new("green")
	mood.push_event(start(5, 5))
	mood.advance(20.0)
	assert_eq(mood.current()["state"], "lull", "nothing has happened yet, so the arena is quiet")
	assert_true("nobody has fired yet" in mood.current()["reasons"], "and it says why")


func test_first_contact_makes_it_a_skirmish_not_a_battle() -> void:
	var mood := MatchMood.new("green")
	mood.push_event(start(5, 5))
	mood.push_event(event(30.0, "first_contact", {"team": "green", "unit": "scout", "target_unit": "tank"}))
	assert_eq(mood.current()["state"], "skirmish", "shots are being exchanged, but nobody has died")


func test_a_kill_makes_it_a_battle() -> void:
	var mood := MatchMood.new("green")
	mood.push_event(start(5, 5))
	mood.push_event(event(30.0, "first_contact", {"team": "green", "unit": "scout", "target_unit": "tank"}))
	mood.push_event(kill(31.0, "rust"))
	assert_eq(mood.current()["state"], "battle", "a unit just died")
	assert_true("one kill in the last ten seconds" in mood.current()["reasons"], "the reason is the kill")


func test_a_battle_cools_off_when_the_shooting_stops() -> void:
	var mood := MatchMood.new("green")
	mood.push_event(start(5, 5))
	mood.push_event(event(30.0, "first_contact", {"team": "green", "unit": "scout", "target_unit": "tank"}))
	mood.push_event(kill(31.0, "rust"))
	mood.advance(75.0)
	assert_eq(mood.current()["state"], "lull", "forty quiet seconds later the arena is quiet again")
	assert_true(float(mood.current()["intensity"]) < MatchMood.SKIRMISH_AT, "and the intensity fell with it")


func test_one_stray_round_does_not_flap_the_state() -> void:
	var mood := MatchMood.new("green")
	mood.push_event(start(5, 5))
	mood.push_event(event(30.0, "first_contact", {"team": "green", "unit": "scout", "target_unit": "tank"}))
	mood.push_event(kill(31.0, "rust"))
	var flaps := 0
	mood.state_changed.connect(func(_reading: Dictionary) -> void: flaps += 1)
	# Hovering right around the battle threshold: hysteresis should hold the state.
	for step in 40:
		mood.advance(31.0 + step * 0.4)
		mood.push_event(event(31.0 + step * 0.4, "damage", {"shooter": "a", "victim": "b", "unit": "tank",
				"victim_unit": "tank", "hull": 0.8, "shield": 0.0, "critical": false}))
	assert_true(flaps <= 1, "the state settled instead of flapping (%d changes)" % flaps)


func test_the_last_survivor_against_a_squad_is_a_last_stand() -> void:
	var mood := MatchMood.new("green")
	mood.push_event(start(4, 4))
	mood.push_event(event(20.0, "first_contact", {"team": "green", "unit": "scout", "target_unit": "tank"}))
	for index in 3:
		mood.push_event(kill(25.0 + index, "green"))
	assert_eq(mood.current()["state"], "last_stand", "one green left against four")
	mood.advance(200.0)
	assert_eq(mood.current()["state"], "last_stand", "and it stays tense however quiet it gets")
	assert_true(float(mood.current()["intensity"]) >= MatchMood.LAST_STAND_FLOOR, "a last stand keeps the music up")


func test_a_last_stand_is_the_losing_side_s_word_for_it() -> void:
	var events: Array = [start(4, 4), event(20.0, "first_contact", {"team": "green", "unit": "scout", "target_unit": "tank"})]
	for index in 3:
		events.append(kill(25.0 + index, "green"))
	var theirs := MatchMood.new("rust")
	for e in events:
		theirs.push_event(e)
	assert_eq(theirs.current()["state"], "battle", "from Rust's point of view they are winning, not making a stand")


func test_the_end_is_a_victory_or_a_defeat_depending_on_who_is_watching() -> void:
	var over := event(120.0, "match_end", {"winner": "green", "reason": "elimination", "duration_seconds": 120.0,
			"units_left": {"green": 2, "rust": 0}, "kills_by_unit": {}})
	var green := MatchMood.new("green")
	green.push_event(start(4, 4))
	green.push_event(over)
	var rust := MatchMood.new("rust")
	rust.push_event(start(4, 4))
	rust.push_event(over)
	assert_eq(green.current()["state"], "victory", "green won")
	assert_eq(rust.current()["state"], "defeat", "the same match, from the other bench")
	assert_true(float(green.current()["intensity"]) > float(rust.current()["intensity"]),
			"the winner's fanfare is louder than the loser's")


func test_a_draw_is_not_a_victory() -> void:
	var mood := MatchMood.new("green")
	mood.push_event(start(4, 4))
	mood.push_event(event(120.0, "match_end", {"winner": "draw", "reason": "time", "duration_seconds": 120.0,
			"units_left": {"green": 2, "rust": 2}, "kills_by_unit": {}}))
	assert_eq(mood.current()["state"], "defeat", "nobody won, so there is no fanfare")
	assert_true("the match ended in a draw" in mood.current()["reasons"], "and the reason says so plainly")


func test_the_state_changed_signal_fires_once_per_change() -> void:
	var mood := MatchMood.new("green")
	var seen: Array = []
	mood.state_changed.connect(func(reading: Dictionary) -> void: seen.append(reading["state"]))
	mood.push_event(start(5, 5))
	mood.push_event(event(30.0, "first_contact", {"team": "green", "unit": "scout", "target_unit": "tank"}))
	mood.push_event(kill(31.0, "rust"))
	mood.advance(90.0)
	assert_eq(seen, ["skirmish", "battle", "lull"], "every change, in order, and no repeats")


func test_every_fixture_produces_a_plausible_arc() -> void:
	for name in SCENARIOS:
		var loaded := AnnouncerEvents.load_file(FIXTURES + name + ".jsonl")
		assert_eq(loaded["error"], "", "%s loads" % name)
		var mood := MatchMood.new("green")
		var seen := {}
		var peak := 0.0
		for e in loaded["events"]:
			mood.push_event(e)
			seen[mood.current()["state"]] = true
			peak = maxf(peak, float(mood.current()["intensity"]))
			mood.advance(float(e["t"]))
		assert_true(seen.has("lull"), "%s: the broadcast starts quiet" % name)
		assert_true(seen.has("battle"), "%s: at some point it is a battle" % name)
		assert_true(peak <= 1.0, "%s: the intensity stays in range (peak %.2f)" % [name, peak])
		assert_true(mood.current()["state"] in ["victory", "defeat"], "%s: it ends on the result" % name)
		assert_true(not (mood.current()["reasons"] as Array).is_empty(), "%s: the result comes with a reason" % name)


func test_the_reading_never_leaves_its_contract() -> void:
	var loaded := AnnouncerEvents.load_file(FIXTURES + "comeback.jsonl")
	var mood := MatchMood.new("green")
	for e in loaded["events"]:
		mood.push_event(e)
		var reading := mood.current()
		assert_true(reading["state"] in MatchMood.STATES, "state %s is one of L5's" % reading["state"])
		assert_true(float(reading["intensity"]) >= 0.0 and float(reading["intensity"]) <= 1.0,
				"intensity %s is a fraction" % reading["intensity"])
		assert_true(typeof(reading["reasons"]) == TYPE_ARRAY, "reasons is a list")
