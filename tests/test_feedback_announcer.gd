extends TestCase
## Round 37 (feedback F3): the caller says a flank hit. His three approved lines (caller.hit.flank.*) answer a big hit
## tagged `flank`; the live match tells the booth which face the round struck (MatchEventAdapter reads the K2 impact),
## so the flank, rear and weak-spot lines play in a real match, not only in the recorded fixtures. A round from above
## (artillery) reports no face: its "side" is not a flank.

const MATCH := preload("res://game/match/match.tscn")


func _memory() -> AnnouncerMemory:
	var memory := AnnouncerMemory.new(AnnouncerLibrary.load_default())
	memory.observe({"type": "match_start", "tick": 0, "t": 0.0, "arena": "terminus", "budget": 1000, "control_point": true,
			"teams": [{"team": "green", "faction": "gangs", "units": [{"id": "g1", "unit": "tank", "squad": "A"}]},
					{"team": "rust", "faction": "law", "units": [{"id": "r1", "unit": "ifv", "squad": "B"}]}]})
	return memory


func _big_hit(memory: AnnouncerMemory, extra: Dictionary) -> Dictionary:
	var event := {"type": "damage", "tick": 600, "t": 10.0, "shooter": "g1", "shooter_unit": "tank", "victim": "r1",
			"victim_unit": "ifv", "hull": 0.5, "shield": 0.0, "critical": true, "amount": 0.4}
	event.merge(extra)
	var found := memory.observe(event)
	return found[0] if not found.is_empty() else {}


func test_a_big_side_hit_is_a_flank_and_his_lines_answer_it() -> void:
	var memory := _memory()
	var hit := _big_hit(memory, {"face": "side", "weak_spot": false})
	assert_true((hit["tag_set"] as Dictionary).has("flank"), "a big hit in the side is a flank")
	var lines := memory.library.candidates("caller", ["call"], hit, {})
	var ids := lines.map(func(line: Dictionary) -> String: return String(line["id"]))
	for n in [1, 2, 3]:
		assert_true(ids.has("caller.hit.flank.%02d" % n), "caller.hit.flank.%02d is a candidate" % n)
	assert_true(not (_big_hit(_memory(), {"face": "rear"})["tag_set"] as Dictionary).has("flank"), "a rear hit is a rear")
	assert_true(not (_big_hit(_memory(), {"face": "side", "weak_spot": true})["tag_set"] as Dictionary).has("flank"),
			"a weak spot is the weak spot's line")
	assert_true(not (_big_hit(_memory(), {})["tag_set"] as Dictionary).has("flank"), "no face known: no flank")


func test_his_flank_lines_are_recorded() -> void:
	var library := AnnouncerLibrary.load_default()
	assert_true(library.load_manifest("res://assets/announcer/clips/manifest.json"), "the clip manifest loads")
	for n in [1, 2, 3]:
		var id := "caller.hit.flank.%02d" % n
		assert_true(float(library.clip_seconds.get(id, 0.0)) > 1.0, "%s has a recorded clip in the manifest" % id)
		assert_true(FileAccess.file_exists("res://assets/announcer/clips/caller/%s.ogg" % id), "%s's clip ships" % id)


func test_the_live_match_tells_the_booth_which_face_was_struck() -> void:
	var game_match: Match = add_to_tree(MATCH.instantiate())
	var adapter := MatchEventAdapter.new(game_match, "terminus")
	game_match.weapon_fired.emit({"tick": 0, "shooter": "Green_1", "weapon": "cannon", "fire_model": "shell", "projectile_id": 1})
	game_match.projectile_impact.emit({"tick": 0, "projectile_id": 1, "target": "Rust_1", "face": "side", "weak_spot": false})
	assert_eq(adapter._struck_face("Rust_1"), {"weak_spot": false, "face": "side"}, "a shell in the side: the side")
	game_match.weapon_fired.emit({"tick": 0, "shooter": "Green_2", "weapon": "mortar", "fire_model": "arc", "projectile_id": 2})
	game_match.projectile_impact.emit({"tick": 0, "projectile_id": 2, "target": "Rust_1", "face": "side", "weak_spot": false})
	assert_eq(adapter._struck_face("Rust_1"), {"weak_spot": false}, "a round from above: no face, so never a flank")
	game_match.tick += roundi((MatchEventAdapter.STRUCK_FRESH_S + 0.1) * Engine.physics_ticks_per_second)
	assert_eq(adapter._struck_face("Rust_1"), {}, "an old impact is not why the hull just dropped")
	assert_eq(adapter._struck_face("Rust_2"), {}, "nothing struck: nothing said")
