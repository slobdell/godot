extends TestCase
## Round 12 (nav): `_guard_steer`, the LAST word on a steering point, fell back to "the next route corner" when the
## carrot's chord left the navmesh — and the next corner can be the one the hull is standing on. Round 11 fixed exactly
## that for `_next_waypoint` (`_corner_beyond`, WAYPOINT_MIN_M), but the guard runs after that fix and undid it: a War
## Rig steered at a vertex 0.47 m from its centre for 2371 ticks (laptop, the drive test's rigs seed 3, plaza leg),
## inside the 0.5 m arrive radius, at zero throttle, and never counted as stalled.
##
## The pose is that rig's: (-68.1, 13.2) in the Terminus west street. The route handed to the guard starts with that
## vertex under the hull; the carrot is a point whose chord crosses a block. The control arm (`--nav-off=guardnear`)
## returns the vertex under the hull — the bug, reproduced — and the fix returns a corner the hull can drive at.

const MATCH := preload("res://game/match/match.tscn")
const HERE := Vector3(-68.1, 0.0, 13.2)
## The vertex the rig sat on, and the next one along its route up the street (both from the trace).
const UNDER := Vector3(-67.8, 0.0, 13.6)
const NEXT := Vector3(-64.6, 0.0, 20.9)
## A carrot across the block east of the street: its chord leaves the mesh.
const CARROT := Vector3(-40.0, 0.0, 5.0)


func _guard(near_fix: bool) -> Dictionary:
	await ArenaFixture.build(self, "terminus")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	tank.global_position = HERE
	tank.reset_physics_interpolation()
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	await wait_physics_frames(2)
	orders.set_orders({"type": "move_to", "x": NEXT.x, "z": NEXT.z}, {"type": "hold_fire"})
	await wait_physics_frames(2)
	var mover := Movement.of(tank)
	var saved := Movement._off
	Movement._off = PackedStringArray() if near_fix else PackedStringArray(["guardnear"])
	mover._path = PackedVector3Array([UNDER, NEXT, CARROT])
	mover._path_index = 0
	var here := tank.global_position
	var out := {"carrot_chord_on_mesh": mover._chord_on_mesh(here, CARROT), "next_chord_on_mesh": mover._chord_on_mesh(here, NEXT),
			"steer": mover._guard_steer(here, CARROT), "here": here}
	out["steer_m"] = Vector2(out["steer"].x - here.x, out["steer"].z - here.z).length()
	Movement._off = saved
	return out


func test_control_the_guard_hands_back_the_vertex_under_the_hull() -> void:
	var control := await _guard(false)
	assert_true(not control["carrot_chord_on_mesh"], "precondition: the carrot's chord crosses the block (%s)" % control)
	assert_true(control["steer_m"] < Movement.WAYPOINT_MIN_M,
			"control (guardnear off): the guard steers at the vertex under the hull - the deadlock, reproduced (%s)" % control)


func test_the_guard_never_steers_at_a_point_under_the_hull() -> void:
	var fixed := await _guard(true)
	assert_true(not fixed["carrot_chord_on_mesh"], "precondition: the carrot's chord crosses the block (%s)" % fixed)
	assert_true(fixed["next_chord_on_mesh"], "precondition: the next corner up the street is drivable (%s)" % fixed)
	assert_true(fixed["steer_m"] >= Movement.WAYPOINT_MIN_M, "the guard steers at a corner beyond the hull (%s)" % fixed)
	assert_true(Vector2(fixed["steer"].x - NEXT.x, fixed["steer"].z - NEXT.z).length() < 0.1, "...the next one (%s)" % fixed)
