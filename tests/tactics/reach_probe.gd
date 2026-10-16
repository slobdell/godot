extends SceneTree
## Round 29 (brains B5a): is a `no_path` seat the SEAT or where the crew STANDS? The navmesh asked from the stuck spots the
## two traces found (Terminus head-on B_4, Sumps arrive crew 4) to the slots they were given, and from a ring of points
## round each stuck spot: the route's end gap, whether the start snaps to the mesh far from where the crew is, and the
## route's length. A seat reachable from a few metres away but not from the spot itself is the crew's footing, not the seat.
##
##   godot --headless --path . --script res://tests/tactics/reach_probe.gd
##   REACH lines

const CASES := [
	# arena, label, stuck spot (x, z), slot (x, z)
	["terminus", "B_4 at 57 s", Vector2(-75.9, 87.8), Vector2(-58.3, 81.2)],
	["terminus", "B_4 parked at 48 s", Vector2(-59.4, 68.9), Vector2(-58.3, 81.2)],
	["sumps", "crew 4 at 58 s", Vector2(1.1, -60.8), Vector2(11.1, -73.4)],
	["sumps", "crew 4 at 48 s", Vector2(16.7, -54.3), Vector2(11.1, -73.4)],
	["sumps", "crew 3 at 66 s", Vector2(-9.3, -67.0), Vector2(11.1, -73.4)],
	["sumps", "crew 3 at 72 s (drove on)", Vector2(0.2, -50.1), Vector2(11.1, -73.4)],
	# Round 31 (brains B9): traffic-t3b's worst run (Terminus crossing s33 t1, --traffic-on=turns): B_4 north of its seat
	# 40-61 s, steering by turns straight at the seat (terrain) and to a corner at (35.3, 40.0) (no_path).
	["terminus", "B9 B_4 at 42 s", Vector2(31.4, 38.1), Vector2(35.58, 23.91)],
	["terminus", "B9 B_4 at 48 s", Vector2(37.7, 35.2), Vector2(35.58, 23.91)],
	["terminus", "B9 B_4 at 53 s", Vector2(36.7, 38.1), Vector2(35.58, 23.91)],
	["terminus", "B9 B_4 at 61 s (going round)", Vector2(28.5, 31.4), Vector2(35.58, 23.91)],
	# Round 31 (manoeuvre's trace, relayed): test_control_queued_task's shift-waypoints stage (default arena), Green_Alpha_3
	# still from frame 1140 at (-25.7, 7.3), blocked terrain/no_path, touching nothing; to each of its shift-waypoints.
	["", "B9 queued Alpha_3 to waypoint 2", Vector2(-25.7, 7.3), Vector2(-35.0, 10.0)],
	["", "B9 queued Alpha_3 to waypoint 1", Vector2(-25.7, 7.3), Vector2(-20.0, 25.0)],
]
const RING_M := [3.0, 6.0]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var case := TestCase.new()
	case.tree = self
	var by_arena := {}
	for entry: Array in CASES:
		by_arena.get_or_add(entry[0], []).append(entry)
	for arena: String in by_arena:
		# Round 32 (traffic's C32.6 finding): wait for THIS arena's own regions, the previous lab's drained first. Waiting
		# on Pathing.is_ready() alone read Terminus's mesh in the default arena's probe (the "8.2 m gap" at (-25.7, 7.3)).
		await ArenaFixture._drain_regions(case, 5.0)
		var lab := TacticsLab.create(case, 1, arena)
		var tank := lab.unit(Match.Team.GREEN, "Green_P_1", Vector3(0.0, 0.0, 0.0), 0.0, "tank")
		var ready := false
		for frame in 300:
			if TacticsLab.navigation_is_this_arenas(lab.arena):
				ready = true
				break
			await physics_frame
		if not ready:
			push_error("reach_probe: %s's own navmesh never held the map alone in 300 frames; its rows are not this arena's" % arena)
			print("REACH_ARENA_NOT_READY %s" % arena)
			continue
		print("REACH_ARENA_READY %s" % arena)
		var map := tank.get_world_3d().navigation_map
		for entry: Array in by_arena[arena]:
			var from := Vector3(entry[2].x, 0.0, entry[2].y)
			var to := Vector3(entry[3].x, 0.0, entry[3].y)
			_report(map, tank, "%s %s" % [arena, entry[1]], from, to)
			for metres: float in RING_M:
				for k in 8:
					var a := TAU * k / 8.0
					_report(map, tank, "%s %s ring %.0f m @%d" % [arena, entry[1], metres, k * 45],
							from + Vector3(cos(a), 0.0, sin(a)) * metres, to)
		lab.dispose()
	print("REACH_DONE")
	case.teardown()
	quit(0)


func _report(map: RID, node: Node3D, label: String, from: Vector3, to: Vector3) -> void:
	var route := Pathing.query(node, from, to)
	var points: PackedVector3Array = route["points"]
	var length := 0.0
	for i in range(1, points.size()):
		length += Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).length()
	var snapped := Pathing.closest_point(map, from, "probe")
	var goal_server := NavigationServer3D.map_get_closest_point(map, to)
	var goal_pathing := Pathing.closest_point(map, to, "probe")
	print("REACH_GOAL %s: server closest (%.2f, %.2f, %.2f) gap %.2f | Pathing.closest_point (%.2f, %.2f, %.2f) gap %.2f | native %s" % [
			label, goal_server.x, goal_server.y, goal_server.z, Vector2(goal_server.x - to.x, goal_server.z - to.z).length(),
			goal_pathing.x, goal_pathing.y, goal_pathing.z, Vector2(goal_pathing.x - to.x, goal_pathing.z - to.z).length(),
			NativePathing.usable()])
	var end := points[points.size() - 1] if points.size() > 0 else Vector3.INF
	print("REACH %s: reachable=%s end_gap %.1f goal_gap %.1f start snaps %.1f m | route %.1f m, %d points, ends (%.1f, %.1f)" % [
			label, route["reachable"], float(route["end_gap_m"]), float(route["goal_gap_m"]),
			Vector2(snapped.x - from.x, snapped.z - from.z).length(), length, points.size(), end.x, end.z])
	if label.contains(" B9 ") and not label.contains("ring"):
		# Round 31 (B9): the route's corners, and what a ray along each leg hits (a static body in the way of the hull).
		var space := node.get_world_3d().direct_space_state
		for i in points.size():
			var hit := ""
			if i > 0:
				# The centreline and lines beside it (a hull is ~3 m wide), low (a kerb) and at hull height.
				var along := (points[i] - points[i - 1]) * Vector3(1, 0, 1)
				var side := Vector3(-along.z, 0.0, along.x).normalized()
				for lateral: float in [0.0, -0.8, 0.8, -1.6, 1.6]:
					for height: float in [0.4, 1.0]:
						var lift := Vector3.UP * height + side * lateral
						var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(points[i - 1] + lift, points[i] + lift))
						if not r.is_empty() and not ((r["collider"] as Node) is Tank):
							hit += " | %+.1f m @%.1f m hits %s at (%.1f, %.1f)" % [lateral, height,
									String((r["collider"] as Node).name), r["position"].x, r["position"].z]
			print("REACH_POINT %s #%d (%.1f, %.1f)%s" % [label, i, points[i].x, points[i].z, hit])
