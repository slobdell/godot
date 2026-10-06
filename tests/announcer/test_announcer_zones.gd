extends TestCase
## Round 19 (board, S3): the booth hears every zone the match scores, and its lines that say "centre" play only where
## a map has one. The twelve dealt maps score two side rings; until now the booth heard only zone 0's captures and could
## call either of them "the center".


func _start(zones: Variant) -> AnnouncerMemory:
	var memory := AnnouncerMemory.new(AnnouncerLibrary.load_default())
	var start := {"type": "match_start", "tick": 0, "t": 0.0, "arena": "terminus", "budget": 1000, "control_point": true,
			"teams": [{"team": "green", "faction": "condemned", "units": [{"id": "g1", "unit": "tank", "squad": "A"}]},
					{"team": "rust", "faction": "law", "units": [{"id": "r1", "unit": "tank", "squad": "B"}]}]}
	if zones != null:
		start["zones"] = zones
	memory.observe(start)
	return memory


func _control(memory: AnnouncerMemory, owner: String, previous: Variant = null) -> Dictionary:
	var event := {"type": "control_changed", "tick": 600, "t": 10.0, "owner": owner}
	if previous != null:
		event["previous"] = previous
	var found := memory.observe(event)
	return found[0] if not found.is_empty() else {}


func test_two_zone_maps_keep_the_centre_lines_quiet() -> void:
	var memory := _start(2)
	var moment := _control(memory, "green", "neutral")
	assert_eq(moment.get("kind", ""), "control", "a capture is a control moment")
	assert_true(not (moment["tag_set"] as Dictionary).has("centre"), "but not a centre one")
	var library := AnnouncerLibrary.load_default()
	var said_centre := 0
	var any := 0
	for line in library.candidates("caller", ["call"], moment, {}):
		any += 1
		if String(line["text"]).to_lower().contains("center") or String(line["text"]).to_lower().contains("centre"):
			said_centre += 1
	assert_true(any > 0, "the caller still has lines for it (%d)" % any)
	assert_eq(said_centre, 0, "and none of them says centre")


func test_a_one_zone_map_and_an_old_recording_keep_them() -> void:
	for zones: Variant in [1, null]:
		var memory := _start(zones)
		var moment := _control(memory, "green")
		assert_true((moment["tag_set"] as Dictionary).has("centre"), "one zone (%s): the centre lines may play" % [zones])


func test_each_zone_has_its_own_previous_owner() -> void:
	var memory := _start(2)
	_control(memory, "green", "neutral")
	var other := _control(memory, "rust", "neutral")
	assert_true((other["tag_set"] as Dictionary).has("taken"), "Rust taking the OTHER ring is a take, not a steal")


func test_every_line_that_says_centre_is_tagged() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/announcer/lines.json"))
	var regex := RegEx.create_from_string("(?i)\\b(cent(er|re)|the middle)\\b")
	for line: Dictionary in data["lines"]:
		var tags: Array = line.get("tags", [])
		if (tags.has("control") or tags.has("control_point")) and regex.search(String(line["text"])) != null:
			assert_true(tags.has("centre"), "%s says centre: tagged" % line["id"])
