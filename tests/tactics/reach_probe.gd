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
		var lab := TacticsLab.create(case, 1, arena)
		var tank := lab.unit(Match.Team.GREEN, "Green_P_1", Vector3(0.0, 0.0, 0.0), 0.0, "tank")
		for frame in 300:
			if Pathing.is_ready(tank):
				break
			await physics_frame
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
	var end := points[points.size() - 1] if points.size() > 0 else Vector3.INF
	print("REACH %s: reachable=%s end_gap %.1f goal_gap %.1f start snaps %.1f m | route %.1f m, %d points, ends (%.1f, %.1f)" % [
			label, route["reachable"], float(route["end_gap_m"]), float(route["goal_gap_m"]),
			Vector2(snapped.x - from.x, snapped.z - from.z).length(), length, points.size(), end.x, end.z])
