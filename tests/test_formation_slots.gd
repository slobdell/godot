extends TestCase
## N2 (round 6, squad X1): ONE formation system. TacticsFormation lays out, seats and paces every formation in the
## game, and the seating is the part the lead can see: a unit keeps its relative place (paths never cross), travel is
## minimal, armour goes where the fire comes from, and nobody swaps slots from one tick to the next.

const NORTH := Vector3(0, 0, -1)


static func _tank(name: String, at: Vector3, unit := "tank") -> Dictionary:
	return {"name": name, "position": at, "unit": unit}


static func _segments_cross(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> bool:
	return Geometry2D.segment_intersects_segment(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z),
			Vector2(d.x, d.z)) != null


func test_a_unit_keeps_its_relative_place() -> void:
	# Five identical tanks abreast, west to east, ordered 60 m north into a line: the westernmost takes the west end.
	var members: Array = []
	for i in 5:
		members.append(_tank("T%d" % i, Vector3(-40.0 + i * 20.0, 0, 60)))
	var placed := TacticsFormation.place(members, "line", Vector3.ZERO, NORTH, 12.0)
	var by_unit := {}
	for entry in placed:
		by_unit[entry["unit"]] = entry["to"]
	for i in range(1, 5):
		assert_true((by_unit["T%d" % i] as Vector3).x > (by_unit["T%d" % (i - 1)] as Vector3).x,
				"T%d stays east of T%d" % [i, i - 1])


func test_paths_never_cross() -> void:
	# A property test over seeded random starts: a minimum-travel seating has no crossing paths.
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	for trial in 25:
		var members: Array = []
		for i in 6:
			members.append(_tank("U%d" % i, Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60))))
		var shape: String = ["wedge", "line", "column", "coil", "rows"][trial % 5]
		var placed := TacticsFormation.place(members, shape, Vector3(rng.randf_range(-20, 20), 0, 0), NORTH, 12.0)
		var from := {}
		for member: Dictionary in members:
			from[member["name"]] = member["position"]
		for a in placed.size():
			for b in range(a + 1, placed.size()):
				var crossing := _segments_cross(from[placed[a]["unit"]], placed[a]["to"], from[placed[b]["unit"]],
						placed[b]["to"])
				assert_true(not crossing, "trial %d (%s): %s and %s cross" % [trial, shape, placed[a]["unit"],
						placed[b]["unit"]])


func test_the_seating_is_the_least_driving() -> void:
	# Brute force over every permutation of four: nothing drives less in total than the seating chosen.
	var members: Array = [_tank("A", Vector3(30, 0, 5)), _tank("B", Vector3(-25, 0, 40)),
			_tank("C", Vector3(2, 0, -30)), _tank("D", Vector3(-8, 0, 12))]
	var shape := TacticsFormation.centered(TacticsFormation.offsets("wedge", 4, 12.0))
	var seats := TacticsFormation.seat(members, shape, Vector3.ZERO, NORTH)
	var chosen := 0.0
	for member: Dictionary in members:
		chosen += (member["position"] as Vector3).distance_to(TacticsFormation.to_world(Vector3.ZERO, NORTH,
				shape[int(seats[member["name"]])]))
	var best := INF
	for p in _permutations([0, 1, 2, 3]):
		var total := 0.0
		for i in 4:
			total += (members[i]["position"] as Vector3).distance_to(TacticsFormation.to_world(Vector3.ZERO, NORTH,
					shape[p[i]]))
		best = minf(best, total)
	assert_near(chosen, best, 0.01, "the chosen seating drives %.1f m in total, the best possible is %.1f" % [chosen, best])


func test_nobody_swaps_slots_tick_to_tick() -> void:
	# Two tanks almost level: which is "left" flickers with a metre of drift. The last seating stands.
	var members: Array = [_tank("A", Vector3(-0.4, 0, 30)), _tank("B", Vector3(0.4, 0, 30.5))]
	var shape := TacticsFormation.centered(TacticsFormation.offsets("line", 2, 12.0))
	var first := TacticsFormation.seat(members, shape, Vector3.ZERO, NORTH)
	var swapped := {"A": 1 - int(first["A"]), "B": 1 - int(first["B"])}
	var again := TacticsFormation.seat(members, shape, Vector3.ZERO, NORTH, {"previous": swapped})
	assert_eq(again, swapped, "a seating that costs under half a spacing more is kept")
	# But a seating that is clearly wrong is replaced: A far out on the east, B on the west.
	var apart: Array = [_tank("A", Vector3(40, 0, 30)), _tank("B", Vector3(-40, 0, 30))]
	var left_first := {"A": 0, "B": 1}
	if (TacticsFormation.to_world(Vector3.ZERO, NORTH, shape[0])).x > 0.0:
		left_first = {"A": 1, "B": 0}
	var fixed := TacticsFormation.seat(apart, shape, Vector3.ZERO, NORTH, {"previous": left_first})
	assert_true(TacticsFormation.to_world(Vector3.ZERO, NORTH, shape[int(fixed["A"])]).x > 0.0,
			"a seating that sends both across the other's path is dropped")


func test_the_leader_keeps_the_point_and_armour_leads_a_group() -> void:
	var members: Array = [_tank("Gun", Vector3(0, 0, 40), "artillery"), _tank("Eyes", Vector3(10, 0, 40), "scout"),
			_tank("Lead", Vector3(-10, 0, 40), "tank")]
	var shape := TacticsFormation.centered(TacticsFormation.offsets("wedge", 3, 12.0))
	var pinned := TacticsFormation.seat(members, shape, Vector3.ZERO, NORTH, {"leader": "Eyes"})
	assert_eq(int(pinned["Eyes"]), 0, "the named leader stands at the point, wherever it starts")
	var front := TacticsFormation.seat(members, TacticsFormation.centered(TacticsFormation.offsets("column", 3, 12.0)),
			Vector3.ZERO, NORTH, {"policy": "front"})
	assert_eq(int(front["Lead"]), 0, "a column on the move is led by the tank")
	assert_eq(int(front["Gun"]), 2, "and the artillery brings up the rear")


func test_the_contract_shape() -> void:
	var group := {"members": [_tank("A", Vector3(0, 0, 20)), _tank("B", Vector3(10, 0, 20))], "formation": "line",
			"spacing": 10.0}
	var placed := TacticsFormation.slots(group, Vector3(5, 0, -5), NORTH, 4)
	assert_eq(placed.size(), 2, "one slot per member, even when the shape has room for more")
	for entry in placed:
		for key in ["unit", "to", "facing", "role"]:
			assert_true(entry.has(key), "N2: every slot says %s" % key)
		assert_eq(entry["role"], "tank", "and the role comes from the unit")
		assert_true((entry["facing"] as Vector3).is_equal_approx(NORTH), "moving: every crew faces the heading")
	var halted := TacticsFormation.place(group["members"], "coil", Vector3.ZERO, NORTH, 10.0, {"halt": true})
	assert_true((halted[0]["facing"] as Vector3).dot(halted[1]["facing"]) < 0.5, "halted: crews face their sectors")


func test_group_shapes() -> void:
	assert_eq(TacticsFormation.auto(1, "move"), "single", "one vehicle has no formation")
	assert_eq(TacticsFormation.auto(4, "hold"), "line", "a holding group forms a line")
	assert_eq(TacticsFormation.auto(5, "move"), "wedge", "a platoon moves in a wedge")
	assert_eq(TacticsFormation.auto(12, "move"), "rows", "a company moves in rows")
	assert_eq(TacticsFormation.auto(12, "move", "column"), "rows", "a named shape too big for itself becomes rows")
	assert_eq(TacticsFormation.auto(3, "move", "vee"), "vee", "a named shape is honoured")
	assert_eq(TacticsFormation.group_offsets("line", 12, 10.0).size(), 12, "a long line wraps into rows of eight")


func test_the_assignment_is_optimal() -> void:
	# The Hungarian method against brute force on seeded random 5x5 costs.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for trial in 20:
		var cost: Array = []
		for i in 5:
			var row := PackedFloat64Array()
			for j in 5:
				row.append(rng.randf_range(0, 100))
			cost.append(row)
		var chosen := TacticsFormation._hungarian(cost)
		var total := 0.0
		for i in 5:
			total += cost[i][chosen[i]]
		var best := INF
		for p in _permutations([0, 1, 2, 3, 4]):
			var sum := 0.0
			for i in 5:
				sum += cost[i][p[i]]
			best = minf(best, sum)
		assert_near(total, best, 1e-6, "trial %d: optimal" % trial)


static func _permutations(items: Array) -> Array:
	if items.size() <= 1:
		return [items]
	var result: Array = []
	for i in items.size():
		var rest := items.duplicate()
		var head: Variant = rest.pop_at(i)
		for tail: Array in _permutations(rest):
			result.append([head] + tail)
	return result
