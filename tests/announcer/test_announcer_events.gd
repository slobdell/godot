extends TestCase
## K5 contract (announcer N0): the GDScript validator accepts every fixture and rejects the shared broken cases,
## exactly like tools/announcer/events.py.

const FIXTURES := "res://tests/announcer/fixtures/"
const CASES := "res://tests/announcer/contract_cases.json"
const SCENARIOS := ["close_match", "blowout", "comeback", "friendly_fire_disaster", "scouts_vs_tanks", "control_swing",
		"gangs_vs_law", "syndicate_showcase"]


static func fixture(name: String) -> Array:
	return AnnouncerEvents.load_file(FIXTURES + name + ".jsonl")["events"]


func test_every_fixture_is_valid() -> void:
	for name in SCENARIOS:
		var loaded := AnnouncerEvents.load_file(FIXTURES + name + ".jsonl")
		assert_eq(loaded["error"], "", "%s parses" % name)
		assert_true(loaded["events"].size() > 10, "%s has a match in it" % name)
		assert_eq(AnnouncerEvents.validate_timeline(loaded["events"]), PackedStringArray(), "%s is valid" % name)


func test_shared_broken_cases_are_rejected() -> void:
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(CASES))["cases"]
	assert_true(cases.size() >= 15, "the shared cases load")
	for case in cases:
		var events := fixture(case["fixture"])
		if case.has("drop"):
			if case["drop"] == "first":
				events.pop_front()
			else:
				events.pop_back()
		else:
			var target: Dictionary = {}
			for event in events:
				if event["type"] == case["event"]:
					target = event
					break
			assert_true(not target.is_empty(), "%s: the fixture has a %s" % [case["name"], case["event"]])
			for key in case.get("set", {}):
				target[key] = case["set"][key]
			if case.has("delete"):
				target.erase(case["delete"])
		assert_true(not AnnouncerEvents.validate_timeline(events).is_empty(), "rejects: %s" % case["name"])


func test_parse_errors_name_the_line() -> void:
	var parsed := AnnouncerEvents.parse_jsonl("{\"tick\": 0}\nnot json\n")
	assert_true(String(parsed["error"]).begins_with("line 2"), "the broken line is named (%s)" % parsed["error"])


## A shell outlives the crew that fired it, so a kill can be credited to a unit that is already gone. Both
## validators must agree about this, or a real match fails `make check` on one side only.
static func _dead_shooter_start() -> Dictionary:
	return {"tick": 0, "t": 0.0, "type": "match_start", "arena": "foundry", "budget": 1000, "teams": [
			{"team": "green", "faction": "law", "units": [{"id": "g1", "unit": "tank"}]},
			{"team": "rust", "faction": "gangs", "units": [{"id": "r1", "unit": "tank"}]}]}


static func _a_kill(t: float, victim: String, victim_team: String, killer: String, killer_team: String) -> Dictionary:
	return {"tick": int(t * 60), "t": t, "type": "unit_destroyed", "victim": victim, "victim_unit": "tank",
			"victim_team": victim_team, "killer": killer, "killer_unit": "tank", "killer_team": killer_team,
			"friendly": false}


static func _an_end(winner: String, green: int, rust: int) -> Dictionary:
	return {"tick": 120, "t": 2.0, "type": "match_end", "winner": winner, "reason": "elimination",
			"duration_seconds": 2.0, "units_left": {"green": green, "rust": rust},
			"kills_by_unit": {"green": {}, "rust": {}}}


func test_a_kill_credited_to_a_dead_shooter_is_legal() -> void:
	var timeline := [_dead_shooter_start(), _a_kill(1.0, "g1", "green", "r1", "rust"),
			_a_kill(1.5, "r1", "rust", "g1", "green"), _an_end("draw", 0, 0)]
	assert_eq(AnnouncerEvents.validate_timeline(timeline), PackedStringArray(),
			"his round was already in the air when he died")


func test_relaxing_the_shooter_does_not_relax_the_victim() -> void:
	var twice := [_dead_shooter_start(), _a_kill(1.0, "g1", "green", "r1", "rust"),
			_a_kill(1.5, "g1", "green", "r1", "rust"), _an_end("rust", 0, 1)]
	assert_true(AnnouncerEvents.validate_timeline(twice).size() > 0, "a unit dying twice is still a bookkeeping bug")
	var targeted := [_dead_shooter_start(), _a_kill(1.0, "g1", "green", "r1", "rust"),
			{"tick": 90, "t": 1.5, "type": "first_contact", "team": "rust", "unit_id": "r1", "unit": "tank",
			"target_id": "g1", "target_unit": "tank"}, _an_end("rust", 0, 1)]
	assert_true(AnnouncerEvents.validate_timeline(targeted).size() > 0,
			"and you still cannot open fire on something already destroyed")

