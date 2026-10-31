extends TestCase
## Mapkit P5 (round 47): the booth calls the blast doors with his 21 approved lines (all kept on the looks page). The
## arena's door events (ArenaDoors.door_event) reach the booth as K5 `door` events (MatchEventAdapter), AnnouncerMemory
## turns each into a door_<kind> moment, and the lines tagged for it answer, {gate} said by the door's compass word.

const KINDS := {
	"open": {"caller": ["caller.door.open.01", "caller.door.open.02", "caller.door.open.03", "caller.door.open.04"],
			"pa": ["pa.door.open.01"]},
	"shut": {"caller": ["caller.door.shut.01", "caller.door.shut.02", "caller.door.shut.03", "caller.door.shut.04"],
			"pa": ["pa.door.shut.01"], "color": ["color.door.01", "color.door.02"]},
	"closing": {"pa": ["pa.door.closing.01", "pa.door.closing.02"]},
	"held": {"caller": ["caller.door.held.01", "caller.door.held.02", "caller.door.held.03"]},
	"caught": {"caller": ["caller.door.caught.01", "caller.door.caught.02", "caller.door.caught.03", "caller.door.caught.04"]},
}
const ACTS := {"caller": "call", "pa": "notice", "color": "analysis"}


func _memory() -> AnnouncerMemory:
	var memory := AnnouncerMemory.new(AnnouncerLibrary.load_default())
	memory.observe({"type": "match_start", "tick": 0, "t": 0.0, "arena": "foundry", "budget": 1000, "control_point": true,
			"teams": [{"team": "green", "faction": "gangs", "units": [{"id": "g1", "unit": "tank", "squad": "A"}]},
					{"team": "rust", "faction": "law", "units": [{"id": "r1", "unit": "ifv", "squad": "B"}]}]})
	return memory


func _door(kind: String, crew := false) -> Dictionary:
	var event := {"type": "door", "tick": 900, "t": 30.0, "door": "west_gate", "gate": "west", "kind": kind}
	if crew:
		event["unit"] = "ifv"
		event["team"] = "rust"
	return event


func test_a_door_event_is_valid_k5() -> void:
	for kind: String in KINDS:
		var problems := AnnouncerEvents.validate_event(_door(kind, kind in ["held", "caught"]))
		assert_eq(problems, PackedStringArray(), "a %s door event passes the event contract" % kind)


func test_every_door_kind_becomes_a_moment_his_lines_answer() -> void:
	for kind: String in KINDS:
		var memory := _memory()
		var found := memory.observe(_door(kind, kind in ["held", "caught"]))
		assert_eq(found.size(), 1, "one moment for a %s door" % kind)
		if found.is_empty():
			continue
		var moment: Dictionary = found[0]
		assert_eq(moment["kind"], "door_" + kind, "its kind")
		assert_true(memory.library.moments.has(moment["kind"]), "door_%s has a beat" % kind)
		for speaker: String in KINDS[kind]:
			var ids := memory.library.candidates(speaker, [ACTS[speaker]], moment, {}).map(
					func(line: Dictionary) -> String: return String(line["id"]))
			for id: String in KINDS[kind][speaker]:
				assert_true(ids.has(id), "%s answers a %s door" % [id, kind])


func test_the_gate_and_the_crew_are_spoken_from_recorded_words() -> void:
	var memory := _memory()
	var library := memory.library
	var moment: Dictionary = memory.observe(_door("held", true))[0]
	var line: Dictionary = library.by_id["caller.door.held.03"]
	var text := library.fill(line, moment["slots"])
	assert_true(text.contains("the west gate") and text.contains("IFV"), "said with his words: %s" % text)
	assert_true(library.load_manifest("res://assets/announcer/clips/manifest.json"), "the clip manifest loads")
	var clip := AnnouncerLibrary.variant_clip("caller.door.held.03", String(line["text"]), moment["slots"])
	var recorded: Dictionary = library.recorded_variants.get("caller.door.held.03", {})
	assert_true(recorded.values().has(clip), "this variant was recorded (%s)" % clip)


func test_the_caught_line_names_the_crews_side() -> void:
	var memory := _memory()
	var moment: Dictionary = memory.observe(_door("caught", true))[0]
	var text := memory.library.fill(memory.library.by_id["caller.door.caught.02"], moment["slots"])
	assert_true(text.contains("the Law"), "rust is the Law this match: %s" % text)
