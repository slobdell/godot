extends TestCase
## Round 47 (route R1), MEASUREMENT: his Locks match (references/round46/playtest/2026-10-30T15-49-20-locks.jsonl), the
## navmesh's own answer from where Hunters_4 stood to where Rust_Lances_3 stood: the shortest drivable route and the
## routes forced over each crossing (the lock at x 0, the west swing bridge at x -92). ROUTE_PROBE lines; asserts only
## that the routes exist (the numbers are R1's trace, not a bar).

const TARGET := Vector3(-25.8, 0.0, -20.0)  # Rust_Lances_3, ticks 1770-1890
const FROM := {"order_1461": Vector3(-82.7, 0.0, 62.3), "drove_north_1680": Vector3(-80.1, 0.0, 94.3),
		"attack_1710": Vector3(-76.9, 0.0, 95.2), "east_1890": Vector3(-61.0, 0.0, 90.9)}
const CROSSINGS := {"lock": Vector3(0.0, 0.0, 0.0), "west_bridge": Vector3(-92.0, 0.0, 0.0)}


static func _length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).length()
	return total


func test_locks_routes_from_hunters_4() -> void:
	await ArenaFixture.build(self, "locks")
	var probe := Node3D.new()
	add_to_tree(probe)
	await wait_physics_frames(2)
	for key: String in FROM:
		var from: Vector3 = FROM[key]
		var shortest := Pathing.query(probe, from, TARGET)
		assert_true(bool(shortest["reachable"]), "%s: the target is reachable" % key)
		var row := {"from": key, "straight": snappedf(Vector2(TARGET.x - from.x, TARGET.z - from.z).length(), 0.1),
				"shortest": snappedf(_length(shortest["points"]), 0.1), "via": []}
		for p: Vector3 in shortest["points"]:
			row["via"].append([snappedf(p.x, 0.1), snappedf(p.z, 0.1)])
		for crossing: String in CROSSINGS:
			var at: Vector3 = CROSSINGS[crossing]
			var a := Pathing.find_path(probe, from, at)
			var b := Pathing.find_path(probe, at, TARGET)
			row[crossing] = snappedf(_length(a) + _length(b), 0.1)
		print("ROUTE_PROBE " + JSON.stringify(row))
