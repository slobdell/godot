extends TestCase
## Round 28 (native N7.6): the black box's per-tick work natively (NativeRecorder -> recorder_native.cpp) against the
## LIVE GDScript, byte for byte. Two MatchRecorders on one live match (both armies by doctrine, so the hulls move and
## their Movement phases change; one hull killed on the way), fed the same orders and squad elements; each tick one
## records through the GDScript and the other natively, the census forced often. The two files must match line for
## line after the header (it names its own path). The orders and elements are stand-ins with the real fields: tasks
## carrying nested shapes, a formation as a StringName, tasks re-assigned and repeated.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const TICKS := 240


class FakeOrders:
	extends RefCounted
	var by_unit := {}

	func current(unit_name: String) -> Dictionary:
		return by_unit.get(unit_name, {})


class FakeSquad:
	extends RefCounted
	var id := 0
	var team := 0
	var element_name := ""
	var task := {}
	var formation: Variant = ""
	var reason := ""


class FakeSquads:
	extends RefCounted
	var list: Array = []

	func of_team(team: int) -> Array:
		return list.filter(func(squad: FakeSquad) -> bool: return squad.team == team)


static func _task(rng: RandomNumberGenerator) -> Dictionary:
	match rng.randi_range(0, 3):
		0:
			return {"verb": "move", "to": [snappedf(rng.randf_range(-80, 80), 0.5), snappedf(rng.randf_range(-80, 80), 0.5)]}
		1:
			return {"verb": "attack", "target": "Rust_Alpha_%d" % rng.randi_range(1, 4), "queue": rng.randf() < 0.5}
		2:
			return {"verb": "hold", "facing": rng.randf_range(-PI, PI), "drill": {"name": "overwatch", "ticks": rng.randi()}}
	return {}


func test_the_recorder_writes_the_same_bytes_natively() -> void:
	if not NativeBridge.available:
		print("native: absent, the recorder equality is not exercised in this run")
		return
	assert_true(NativeRecorder.configure(), "the native recorder takes the live constants")
	var arena: Node = ARENA.instantiate()
	arena.layout_name = "sumps"
	add_to_tree(arena)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	for team in 2:
		var faction := "law" if team == Match.Team.GREEN else "condemned"
		game_match.load_doctrine(team, Army.cpu_army("cpu", 92721 + team, Units.BASELINE_BUDGET, faction))
	await wait_physics_frames(3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2876
	var orders := FakeOrders.new()
	var squads := FakeSquads.new()
	for i in 6:
		var squad := FakeSquad.new()
		squad.id = i + 1
		squad.team = i % 2
		squad.element_name = ["Alpha", "Bravo", "Charlie"][i / 2]
		squad.formation = &"wedge" if i % 3 == 0 else "line"
		squads.list.append(squad)
	var base := OS.get_user_data_dir().path_join("test_native_recorder")
	var live := MatchRecorder.start(game_match, orders, null, squads, base.path_join("live"), "live", 1)
	var native := MatchRecorder.start(game_match, orders, null, squads, base.path_join("native"), "native", 1)
	live.set_physics_process(false)
	native.set_physics_process(false)
	var names: Array = []
	for child in game_match.tanks.get_children():
		names.append(String(child.name))
	var was := BrainSwitches.native_recorder
	for t in TICKS:
		await wait_physics_frames(1)
		for squad: FakeSquad in squads.list:
			if rng.randf() < 0.05:
				squad.task = _task(rng)
				squad.reason = ["", "contact", "ordered"][rng.randi_range(0, 2)]
		if rng.randf() < 0.3 and not names.is_empty():
			var unit := String(names[rng.randi_range(0, names.size() - 1)])
			orders.by_unit[unit] = {"verb": ["move", "attack", "hold"][rng.randi_range(0, 2)], "source": &"player"} \
					if rng.randf() < 0.8 else {}
		if t == 120:
			var victim := game_match.tanks.get_child(0) as Tank
			victim.alive = false  # the dead leave the census
		if t % 7 == 0:
			live._next_census = 0.0
			native._next_census = 0.0
		BrainSwitches.native_recorder = false
		live._physics_process(0.0)
		BrainSwitches.native_recorder = true
		native._physics_process(0.0)
		BrainSwitches.native_recorder = was
	BrainSwitches.native_recorder = was
	var live_lines := FileAccess.get_file_as_string(live.path).split("\n")
	var native_lines := FileAccess.get_file_as_string(native.path).split("\n")
	live.queue_free()
	native.queue_free()
	var kinds := {}
	var filled := {}
	var mismatches := 0
	var first := ""
	for i in range(1, maxi(live_lines.size(), native_lines.size())):
		var a: String = live_lines[i] if i < live_lines.size() else "<missing>"
		var b: String = native_lines[i] if i < native_lines.size() else "<missing>"
		if a != b:
			mismatches += 1
			if first == "":
				first = "line %d: live %s | native %s" % [i, a.left(300), b.left(300)]
		var row = JSON.parse_string(a) if a != "" and a != "<missing>" else null
		if row is Dictionary:
			kinds[row.get("t", "?")] = int(kinds.get(row.get("t", "?"), 0)) + 1
			for unit: Dictionary in row.get("units", []):
				for key in ["order", "phase", "blocked"]:
					if String(unit.get(key, "")) != "":
						filled[key] = int(filled.get(key, 0)) + 1
	print("native recorder: %d ticks, %d lines %s, census fields filled %s, %d mismatches" % [TICKS, live_lines.size(),
			kinds, filled, mismatches])
	assert_eq(mismatches, 0, "the native recorder writes the live GDScript's bytes: %s" % first)
	assert_true(int(kinds.get("census", 0)) >= 30 and int(kinds.get("task", 0)) >= 20
			and int(filled.get("order", 0)) > 0 and int(filled.get("phase", 0)) > 0, "a real sample (%s, %s)" % [kinds, filled])
