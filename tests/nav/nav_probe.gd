extends "res://tests/arena/maze_probe.gd"
## nav's view of arena's maze probe: the same run, plus where every unit that did NOT arrive ended up, what its
## Movement said about itself, and whether it is off the navmesh (NAV_WHERE lines). Diagnosis only; the headline
## numbers are arena's probe's own.


func _report(elapsed: float) -> void:
	var map := arena.get_world_3d().navigation_map
	for tank in units:
		var key := String(tank.name)
		if arrived_at.has(key):
			continue
		var p := tank.global_position
		var on_mesh := NavigationServer3D.map_get_closest_point(map, p)
		var reading := Movement.state(tank)
		print("NAV_WHERE %s at (%.1f, %.1f) goal (%.1f, %.1f) off_mesh %.1f phase %s by %s stalled %.0fs" % [key, p.x, p.z,
				goals[key].x, goals[key].z, Vector2(p.x - on_mesh.x, p.z - on_mesh.z).length(), reading.get("phase", "?"),
				reading.get("blocked_by", ""), float(reading.get("stalled_s", 0.0))])
	print("NAV_COUNTERS yields %d refused %d solved %d deflected %d" % [Movement.yields_started, Movement.asks_refused,
			Avoidance.solved, Avoidance.deflected])
	super(elapsed)
