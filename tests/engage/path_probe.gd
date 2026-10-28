extends SceneTree
## Round 43 (engage A1): the navmesh's own answer on Locks. For each `--from=x,z` and `--to=x,z` pair (several `;`-separated)
## prints ENGAGE_PATH with the route's waypoints, its length, and which crossing it uses (the west swing bridge at x -92,
## the lock at x 0, the far bridge at x 92: whichever the route passes within |z| < 12). Pure navmesh (Pathing.find_path):
## no units, no element, no brain.
##   godot --headless --fixed-fps 30 --path . --script res://tests/engage/path_probe.gd -- \
##         "--legs=-105,46>-89,-19;-105,46>-100,-15" [--arena=locks]

var case: TestCase


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _v(text: String) -> Vector3:
	var parts := text.split(",")
	return Vector3(float(parts[0]), 0.0, float(parts[1]))


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	var lab := TacticsLab.create(case, 56416, _flag("arena", "locks"))
	var ground := lab.unit(Match.Team.GREEN, "Green_Probe_1", Vector3(-120.0, 0.0, 120.0), 0.0, "gang_scout")
	await lab.start()
	for leg in _flag("legs", "-105,46>-89,-19").split(";"):
		if leg.strip_edges() == "":
			continue
		var ends := leg.split(">")
		var from := _v(ends[0])
		var to := _v(ends[1])
		var path := Pathing.find_path(ground, from, to)
		var points: Array = []
		var length := 0.0
		var crossing := "none"
		for i in path.size():
			var p := path[i]
			points.append([snappedf(p.x, 0.1), snappedf(p.z, 0.1)])
			if i > 0:
				var a := path[i - 1]
				var steps := maxi(1, ceili(a.distance_to(p) / 2.0))
				for k in steps + 1:
					var q := a.lerp(p, float(k) / steps)
					if absf(q.z) < 12.0:
						crossing = "west bridge" if absf(q.x + 92.0) < 12.0 else "lock" if absf(q.x) < 12.0 \
								else "far bridge" if absf(q.x - 92.0) < 12.0 else crossing
				length += Vector2(a.x - p.x, a.z - p.z).length()
		var end := path[path.size() - 1] if path.size() > 0 else Vector3.INF
		print("ENGAGE_PATH %s" % JSON.stringify({"from": [from.x, from.z], "to": [to.x, to.z], "n": path.size(),
				"length_m": snappedf(length, 0.1), "crossing": crossing, "end": [snappedf(end.x, 0.1), snappedf(end.z, 0.1)] if path.size() > 0 else null,
				"end_gap_m": snappedf(Vector2(end.x - to.x, end.z - to.z).length(), 0.1) if path.size() > 0 else null,
				"points": points.slice(0, 12)}))
	print("ENGAGE_PATH_DONE")
	lab.dispose()
	quit(0)
