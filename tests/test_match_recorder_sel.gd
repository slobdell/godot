extends TestCase
## R46.6 (round 46, native): the `sel` row. Every change of his selection is a row (camera's planner reads what he looks
## after, and a selection without an order was invisible in his recordings); the replay ignores it (tests/replay_orders.gd
## reads match / order / census only).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


class FakeControls extends Node:
	var selection := Selection.new()


class FakeSquad extends RefCounted:
	var element_name := ""
	var roster: Array = []
	func _init(p_name: String, p_roster: Array) -> void:
		element_name = p_name
		roster = p_roster
	func has(unit_name: String) -> bool:
		return roster.has(unit_name)


class FakeElements extends RefCounted:
	var squads: Array = []
	func all() -> Array:
		return squads


func _rows(recorder: MatchRecorder, kind: String) -> Array:
	var out: Array = []
	for line in FileAccess.get_file_as_string(recorder.path).split("\n"):
		var row: Variant = JSON.parse_string(line) if line.strip_edges() != "" else null
		if row is Dictionary and row["t"] == kind:
			out.append(row)
	return out


func test_every_selection_change_is_a_sel_row_with_its_squads() -> void:
	add_to_tree(ARENA.instantiate())
	var m: Match = MATCH.instantiate()
	add_to_tree(m)
	var elements := FakeElements.new()
	elements.squads = [FakeSquad.new("Spears", ["Green_Spears_1", "Green_Spears_2"]), FakeSquad.new("Hunters", ["Green_Hunters_1"])]
	var names: Array = ["Green_Spears_2", "Green_Hunters_1", "Green_Spears_1", "Green_Loose_1"]
	var controls := FakeControls.new()
	add_to_tree(controls)
	controls.selection.set_units([names[0]])
	var recorder := MatchRecorder.start(m, null, controls, elements, "user://test_recorder_sel", "sel")
	await wait_physics_frames(1)
	controls.selection.set_units(names)
	controls.selection.set_units(names)  # unchanged: Selection does not signal, so no row
	controls.selection.inspect("Rust_X_1")
	controls.selection.clear()
	recorder._exit_tree()
	var rows := _rows(recorder, "sel")
	assert_eq(rows.size(), 4, "the selection at start + three changes")
	assert_eq(rows[0]["units"], [names[0]], "what he had selected when the recording started")
	assert_eq(rows[1]["units"], ["Green_Hunters_1", "Green_Loose_1", "Green_Spears_1", "Green_Spears_2"],
			"the units as Selection keeps them (sorted)")
	assert_eq(rows[1]["squads"], ["Hunters", "", "Spears"], "each squad once, in unit order; \"\" = in none")
	assert_eq([rows[2]["units"], rows[2]["inspected"]], [[], "Rust_X_1"], "an inspected enemy")
	assert_eq([rows[3]["units"], rows[3]["squads"], rows[3]["inspected"]], [[], [], ""], "cleared")
	for row: Dictionary in rows:
		assert_true(row.has("tick") and row.has("frame"), "tick and frame")
	DirAccess.remove_absolute(recorder.path)


func test_a_swapped_selection_is_followed() -> void:
	add_to_tree(ARENA.instantiate())
	var m: Match = MATCH.instantiate()
	add_to_tree(m)
	var controls := FakeControls.new()
	add_to_tree(controls)
	var recorder := MatchRecorder.start(m, null, controls, null, "user://test_recorder_sel", "swap")
	await wait_physics_frames(1)
	var old := controls.selection
	controls.selection = Selection.new()
	await wait_physics_frames(2)
	old.set_units(["Green_A_1"])  # the old one: no longer his, no row
	controls.selection.set_units(["Green_B_1"])
	recorder._exit_tree()
	var rows := _rows(recorder, "sel")
	assert_eq(rows.size(), 1, "only the new selection's change")
	assert_eq(rows[0]["units"], ["Green_B_1"], "the new selection")
	assert_eq(rows[0]["squads"], [""], "no elements: one unnamed squad")
	DirAccess.remove_absolute(recorder.path)
