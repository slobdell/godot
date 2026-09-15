extends TestCase
## K5 contract (announcer N0): the GDScript validator accepts every fixture and rejects the shared broken cases,
## exactly like tools/announcer/events.py.

const FIXTURES := "res://tests/announcer/fixtures/"
const CASES := "res://tests/announcer/contract_cases.json"
const SCENARIOS := ["close_match", "blowout", "comeback", "friendly_fire_disaster", "scouts_vs_tanks", "control_swing"]


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
