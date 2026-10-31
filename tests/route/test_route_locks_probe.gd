extends TestCase
## Round 47 (route R1), MEASUREMENT: his Locks match (references/round46/playtest/2026-10-30T15-49-20-locks.jsonl), the
## navmesh's own answer from where Hunters_4 stood to where Rust_Lances_3 stood: the shortest drivable route and the
## routes forced over each crossing (the lock at x 0, the west swing bridge at x -92). ROUTE_PROBE lines; asserts only
## that the routes exist (the numbers are R1's trace, not a bar).

const TARGET := Vector3(-25.8, 0.0, -20.0)  # Rust_Lances_3, ticks 1770-1890
const FROM := {"order_1461": Vector3(-82.7, 0.0, 62.3), "drove_north_1680": Vector3(-80.1, 0.0, 94.3),
		"attack_1710": Vector3(-76.9, 0.0, 95.2), "east_1890": Vector3(-61.0, 0.0, 90.9)}
## His census, ticks 1710-2220 (Hunters_4 on `attack` alone): [tick, its x, z, Rust_Lances_3 x, z].
const HIS_ATTACK := [[1710, -76.9, 95.2, -16.9, -20.0], [1740, -74.2, 94.8, -23.2, -20.0], [1770, -72.7, 95.1, -25.8, -20.0], [1800, -73.4, 94.8, -25.8, -20.0], [1830, -76.7, 95.2, -25.8, -20.0], [1860, -71.6, 92.8, -25.8, -20.0], [1890, -61.0, 90.9, -25.8, -20.0], [1920, -50.2, 89.3, -24.6, -20.2], [1950, -39.3, 87.5, -23.4, -19.8], [1980, -28.5, 85.6, -23.5, -19.6], [2010, -18.1, 83.6, -30.1, -19.5], [2040, -11.6, 78.3, -38.1, -20.3], [2070, -8.5, 68.3, -44.8, -19.9], [2100, -7.2, 57.6, -45.8, -19.8], [2130, -6.7, 46.7, -44.1, -18.5], [2160, -6.2, 35.7, -39.1, -18.0], [2190, -5.7, 24.7, -31.4, -17.8], [2220, -5.4, 17.1, -21.4, -18.0]]
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


## Along his attack: at each census tick, the shortest from where Hunters_4 stood to where Lances_3 stood, and over which
## crossing. A committed route that a moving target made long shows as the crossing flipping behind the crew.
func test_locks_along_his_attack() -> void:
	await ArenaFixture.build(self, "locks")
	var probe := Node3D.new()
	add_to_tree(probe)
	await wait_physics_frames(2)
	for row: Array in HIS_ATTACK:
		var from := Vector3(float(row[1]), 0.0, float(row[2]))
		var to := Vector3(float(row[3]), 0.0, float(row[4]))
		var shortest := _length(Pathing.find_path(probe, from, to))
		var over := {}
		for crossing: String in CROSSINGS:
			var at: Vector3 = CROSSINGS[crossing]
			over[crossing] = snappedf(_length(Pathing.find_path(probe, from, at)) + _length(Pathing.find_path(probe, at, to)), 0.1)
		print("ROUTE_ALONG " + JSON.stringify({"tick": row[0], "shortest": snappedf(shortest, 0.1), "over": over}))
	assert_true(true, "measurement")
