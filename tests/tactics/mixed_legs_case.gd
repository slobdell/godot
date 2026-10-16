extends TestCase
## Round 32 (C32.8 / R31.9): the stage of test_tactics_mixed_legs*.gd (split by time); no tests of its own.
## Round 18, brains D4: his attack-move (an element task `move` with drills: rts_controls sends `drills: false` only for a
## plain move) on a MIXED squad drove one leg, every crew settled into its slot, and the squad never moved on. Sized on
## his path (settle probe, 150 m, 60 s): two-scout mixes stalled in 14 of 24 runs off the Sumps, the Terminus 8 of 8;
## four tanks never. The cause: ElementPlan._cohesive judged "closed up" against a FRESH seating (no pinned leader, no
## previous seats), so the role-ranked tank was measured against the front slot while it sat in its real one at the back.

var seconds := 60.0
const METRES := 150.0


## A squad of `ids` at the Green spawn, abreast and facing the enemy, attack-moved METRES toward it. Returns
## {"arrived_s" (-1 = never), "to_go_m" (the centre's distance from the point at the end)}.
func _attack_move(ids: Array, arena: String, seed_value: int) -> Dictionary:
	var lab := TacticsLab.create(self, seed_value, arena)
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	var toward := TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-toward.z, 0.0, toward.x)
	var yaw := atan2(-toward.x, -toward.z)
	var names: Array = []
	for i in ids.size():
		var at := home + right * ((i - (ids.size() - 1) * 0.5) * 8.0)
		names.append(String(lab.unit(Match.Team.GREEN, "Green_M_%d" % (i + 1), at, yaw, String(ids[i])).name))
	await lab.start()
	var element := lab.elements.form(names, "Alpha")
	var centre := _centre(game_match, names)
	var goal := centre + toward * METRES
	element.assign({"verb": "move", "to": [goal.x, goal.z]})
	var arrived := -1
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		if element.arrived:
			arrived = tick
			break
	var result := {"arrived_s": arrived / float(SimClock.TICK_RATE) if arrived >= 0 else -1.0,
			"to_go_m": snappedf(_centre(game_match, names).distance_to(goal), 0.1), "reseats": element.reseats}
	lab.dispose()
	return result


func _centre(game_match: Match, names: Array) -> Vector3:
	var sum := Vector3.ZERO
	for unit_name: String in names:
		var t := game_match.tanks.get_node(NodePath(unit_name)) as Node3D
		sum += Vector3(t.global_position.x, 0.0, t.global_position.z)
	return sum / float(names.size())
