extends TestCase
## Round 32 (planner CP-S, C32.4): **the side gate.** `PlannerSeam.side_gate(slot, facing, unit_id, map, from)` puts
## brains' arrival gate to the SIDE of a slot (design.md §2.8: `slot + perp x R`, R the hull's turning radius) on the
## side with room, from two clearance reads; ZERO when neither side has room. Held here: each side, the no-room case,
## the `from` and clearance tie-breaks, the hulls it refuses (tracks, a null facing), and the GDScript read equal to the
## C++ read (the shared navmesh cell cache) on rectangle worlds and on the real yard_open and Terminus navmeshes, yard
## s27 t8's give-up among them (brains' trace, pair/brains-v5 e675a28a). Each navmesh fixture prints us a call each way.

const UNIT := "law_scout"
const NORTH := Vector3(0.0, 0.0, -1.0)


static func _radius(unit_id: String) -> float:
	return maxf(float(Units.stat(unit_id, "min_turn_radius_m", 0.0)), 0.5)


## A wall box of `half` metres round (x, z).
static func _world_with(boxes: Array) -> PlannerWorld:
	var world := PlannerWorld.new()
	for b: Array in boxes:
		world.add_wall_box(float(b[0]) - float(b[2]), float(b[1]) - float(b[2]), float(b[0]) + float(b[2]), float(b[1]) + float(b[2]))
	return world


func test_open_ground_takes_the_side_the_hull_comes_from() -> void:
	var r := _radius(UNIT)
	var world := _world_with([])
	# Facing north (-Z), the left is west (-X): Godot's right is +X with the nose on -Z.
	var west := PlannerSeam.side_gate_in(world, Vector3.ZERO, NORTH, UNIT, Vector3(-20.0, 0.0, 10.0), false)
	assert_near(west.x, -r, 0.001, "from the west: the west gate (x)")
	assert_near(west.z, 0.0, 0.001, "from the west: the west gate (z)")
	var east := PlannerSeam.side_gate_in(world, Vector3.ZERO, NORTH, UNIT, Vector3(20.0, 0.0, 10.0), false)
	assert_near(east.x, r, 0.001, "from the east: the east gate")
	var tie := PlannerSeam.side_gate_in(world, Vector3.ZERO, NORTH, UNIT, Vector3.INF, false)
	assert_near(tie.x, -r, 0.001, "no `from` and equal room: the left of the facing")
	var y := PlannerSeam.side_gate_in(world, Vector3(3.0, 1.25, 4.0), NORTH, UNIT, Vector3.INF, false)
	assert_near(y.y, 1.25, 0.0001, "the gate keeps the slot's height")
	assert_near(y.z, 4.0, 0.001, "never along the facing axis: level with the slot")


func test_a_blocked_side_gives_the_other() -> void:
	var r := _radius(UNIT)
	var left_walled := _world_with([[-r, 0.0, 2.0]])
	var gate := PlannerSeam.side_gate_in(left_walled, Vector3.ZERO, NORTH, UNIT, Vector3(-20.0, 0.0, 10.0), false)
	assert_near(gate.x, r, 0.001, "the left in a wall: the right, though the hull comes from the left")
	var right_walled := _world_with([[r, 0.0, 2.0]])
	gate = PlannerSeam.side_gate_in(right_walled, Vector3.ZERO, NORTH, UNIT, Vector3(20.0, 0.0, 10.0), false)
	assert_near(gate.x, -r, 0.001, "the right in a wall: the left")
	# A wall a little off the gate: the gate point has clearance, but less than half the hull + the margin.
	var width := float(Movement.hull_box(UNIT)[0])
	var tight := _world_with([[r + width * 0.5 + 0.2 + 1.0, 0.0, 1.0]])   # its face 0.2 m + slack inside the need
	gate = PlannerSeam.side_gate_in(tight, Vector3.ZERO, NORTH, UNIT, Vector3(20.0, 0.0, 10.0), false)
	assert_near(gate.x, -r, 0.001, "a right gate too close to a face for the hull's half width: the left")


func test_no_room_either_side_is_zero() -> void:
	var r := _radius(UNIT)
	var world := _world_with([[-r, 0.0, 2.0], [r, 0.0, 2.0]])
	assert_eq(PlannerSeam.side_gate_in(world, Vector3.ZERO, NORTH, UNIT, Vector3.INF, false), Vector3.ZERO,
			"both sides in walls: ZERO (brains' gate stays)")


func test_more_clearance_wins_without_from() -> void:
	var r := _radius(UNIT)
	# Walls 6 m from the left gate and 3 m from the right one (faces), both outside the need.
	var world := _world_with([[-r - 7.0, 0.0, 1.0], [r + 4.0, 0.0, 1.0]])
	var gate := PlannerSeam.side_gate_in(world, Vector3.ZERO, NORTH, UNIT, Vector3.INF, false)
	assert_near(gate.x, -r, 0.001, "the side with more clearance")
	world = _world_with([[-r - 4.0, 0.0, 1.0], [r + 7.0, 0.0, 1.0]])
	gate = PlannerSeam.side_gate_in(world, Vector3.ZERO, NORTH, UNIT, Vector3.INF, false)
	assert_near(gate.x, r, 0.001, "mirrored: the right")


func test_hulls_it_does_not_serve_are_zero() -> void:
	var world := _world_with([])
	assert_eq(PlannerSeam.side_gate_in(world, Vector3.ZERO, Vector3.ZERO, UNIT, Vector3.INF, false), Vector3.ZERO, "a null facing")
	var tracked := ""
	for id: String in Units.PROFILES:
		if String(Units.stat(id, "locomotion", "tracks")) == "tracks" and Units.PROFILES[id].has("hull_size"):
			tracked = id
			break
	assert_true(tracked != "", "the roster has a tracked hull")
	assert_eq(PlannerSeam.side_gate_in(world, Vector3.ZERO, NORTH, tracked, Vector3.INF, false), Vector3.ZERO,
			"a tracked hull pivots: no gate (%s)" % tracked)


func _native() -> bool:
	if not Planner.native_usable() or not Planner._impl.has_method("clearances"):
		print("native: absent, the side gate's C++ read is not exercised in this run")
		return false
	return true


## Both reads of the same world, and both gates, equal; the microseconds a call each way.
func _both(label: String, world: PlannerWorld, slot: Vector3, facing: Vector3, unit_id: String, from: Vector3) -> Vector3:
	var t0 := Time.get_ticks_usec()
	var gd := PlannerSeam.side_gate_in(world, slot, facing, unit_id, from, false)
	var t1 := Time.get_ticks_usec()
	if not _native():
		print("SIDE_GATE %s %s: %s, gdscript %d us" % [label, unit_id, gd, t1 - t0])
		return gd
	var cpp := PlannerSeam.side_gate_in(world, slot, facing, unit_id, from, true)
	var t2 := Time.get_ticks_usec()
	var cpp_again := PlannerSeam.side_gate_in(world, slot, facing, unit_id, from, true)   # warm: the cache's cells read
	var t3 := Time.get_ticks_usec()
	assert_eq(cpp, gd, "%s %s: the C++ gate is the GDScript gate" % [label, unit_id])
	assert_eq(cpp_again, cpp, "%s %s: the warm C++ read the same" % [label, unit_id])
	var r := _radius(unit_id)
	var f := Vector2(facing.x, facing.z).normalized()
	var probe := PackedFloat64Array([slot.x + f.y * r, slot.z - f.x * r, slot.x - f.y * r, slot.z + f.x * r])
	var reads_gd := Planner.clearances(world, probe, false)
	var reads_cpp := Planner.clearances(world, probe, true)
	assert_eq(reads_cpp, reads_gd, "%s %s: the two clearance reads equal bit for bit" % [label, unit_id])
	print("SIDE_GATE %s %s: %s (left %.3f right %.3f) | gdscript %d us, C++ cold %d us, warm %d us | host %s" % [
			label, unit_id, gd, reads_gd[0], reads_gd[1], t1 - t0, t2 - t1, t3 - t2, OS.get_environment("HOSTNAME")])
	return gd


func test_rectangle_worlds_read_the_same_both_ways() -> void:
	var r := _radius(UNIT)
	_both("open", _world_with([]), Vector3.ZERO, NORTH, UNIT, Vector3(-20.0, 0.0, 10.0))
	_both("left walled", _world_with([[-r, 0.0, 2.0]]), Vector3.ZERO, NORTH, UNIT, Vector3.INF)
	_both("both walled", _world_with([[-r, 0.0, 2.0], [r, 0.0, 2.0]]), Vector3.ZERO, NORTH, UNIT, Vector3.INF)
	_both("by clearance", _world_with([[-r - 7.0, 0.0, 1.0], [r + 4.0, 0.0, 1.0]]), Vector3.ZERO, Vector3(0.6, 0.0, -0.8), "ifv", Vector3.INF)


static func _nav_world(arena: Arena) -> PlannerNavWorld:
	var world := PlannerNavWorld.new()
	world.map = arena.get_world_3d().navigation_map
	world.bake_radius = Movement.bake_radius(arena)
	return world


func test_the_navmesh_fixtures_read_the_same_both_ways() -> void:
	var yard := await ArenaFixture.build(self, "yard_open")
	var world := _nav_world(yard)
	# Yard s27 t8 (brains, pair/brains-v5 e675a28a): A_5's move goal at the gate give-up, facing west, the hull at
	# (2.5, -46.1) facing away (dot -0.94) when it read reached_facing_away; the 180-degree come-round carried it 27 m
	# off onto terrain. The side gate must answer (a point with room, or ZERO) the same both ways.
	var slot := Vector3(-13.016, 0.0, -47.469)
	var facing := Vector3(-0.99995, 0.0, 0.01008)
	var from := Vector3(2.5, 0.0, -46.1)
	for unit_id: String in ["law_scout", "gang_ifv", "ifv"]:
		var gate := _both("yard s27 t8", world, slot, facing, unit_id, from)
		if gate != Vector3.ZERO:
			var reads := Planner.clearances(world, PackedFloat64Array([gate.x, gate.z]), false)
			assert_true(reads[0] > 0.0, "yard s27 t8 %s: the gate is on the navmesh (clearance %.2f)" % [unit_id, reads[0]])
			assert_near(Vector2(gate.x - slot.x, gate.z - slot.z).length(), _radius(unit_id), 0.001,
					"yard s27 t8 %s: R from the slot" % unit_id)
	# The public form (the map, the cached bake radius) answers as the world form does.
	assert_eq(PlannerSeam.side_gate(slot, facing, "law_scout", world.map, from),
			PlannerSeam.side_gate_in(world, slot, facing, "law_scout", from), "side_gate(map) = side_gate_in(world)")
	yard.free()
	await drain_navigation()
	var terminus := await ArenaFixture.build(self, "terminus")
	world = _nav_world(terminus)
	# The lab's slot180 (a scout's slot in a Terminus street) and the west street (walls both sides of a rig's turn).
	_both("terminus slot180", world, Vector3(0.0, 0.0, 51.0), Vector3(0.0, 0.0, 1.0), "law_scout", Vector3(0.0, 0.0, 60.0))
	_both("terminus west street", world, Vector3(-70.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), "gang_ifv", Vector3.INF)
	_both("terminus west street ifv", world, Vector3(-70.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), "ifv", Vector3(-70.0, 0.0, 20.0))
	terminus.free()
