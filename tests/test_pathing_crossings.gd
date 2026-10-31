extends TestCase
## Round 47 (route R2): a crew's route takes the short way across the map's crossings. The lead, his Locks match:
## *"that seems like we're not using shortest path algorithms"*. R1 (`_agents/streams/route.md`) found the route WAS the
## navmesh's shortest on every re-plan (<= 1.036x over 298) and the 230 m came from the brain's RETREAT; these hold the
## planner to it, so a future cost term that sends a crew the long way round fails here first.
##
## For each pair: the route `Pathing.query` gives is no longer than the best route forced over any one of the map's
## crossings (+1 m of string-pulling noise), and it goes over the crossing that best route uses.

const SLACK_M := 1.0
const NEAR_CROSSING_M := 14.0


static func _length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).length()
	return total


static func _passes(points: PackedVector3Array, at: Vector3) -> bool:
	for i in range(1, points.size()):
		var on := Geometry3D.get_closest_point_to_segment(at, points[i - 1], points[i])
		if Vector2(on.x - at.x, on.z - at.z).length() <= NEAR_CROSSING_M:
			return true
	return false


## The shortest route from `from` to `to` against routes forced over each of `crossings` (name -> point).
func _check(layout: String, from: Vector3, to: Vector3, crossings: Dictionary, expected: String) -> void:
	await ArenaFixture.build(self, layout)
	var probe := Node3D.new()
	add_to_tree(probe)
	await wait_physics_frames(2)
	var route := Pathing.query(probe, from, to)
	assert_true(bool(route["reachable"]), "%s: %s -> %s is reachable" % [layout, from, to])
	var points: PackedVector3Array = route["points"]
	var length := _length(points)
	var best := ""
	var best_m := INF
	var forced := {}
	for name: String in crossings:
		var via: Vector3 = crossings[name]
		var m := _length(Pathing.find_path(probe, from, via)) + _length(Pathing.find_path(probe, via, to))
		forced[name] = snappedf(m, 0.1)
		if m < best_m:
			best_m = m
			best = name
	print("ROUTE_CROSSING %s from %s to %s: route %.1f m, forced %s" % [layout, from, to, length, forced])
	assert_eq(best, expected, "%s: the shortest crossing is the one expected (%s)" % [layout, forced])
	assert_true(length <= best_m + SLACK_M, "%s: the route (%.1f m) is no longer than over the best crossing (%.1f m)" % [
			layout, length, best_m])
	assert_true(_passes(points, crossings[best]), "%s: and it goes over %s" % [layout, best])


## His case: Hunters_4 at his attack click (tick 1461) and Rust_Lances_3. The lock was the long way (145 m v 135 m).
func test_his_locks_click_takes_the_west_bridge() -> void:
	await _check("locks", Vector3(-82.7, 0.0, 62.3), Vector3(-25.8, 0.0, -20.0),
			{"lock": Vector3(0.0, 0.0, 0.0), "west_bridge": Vector3(-92.0, 0.0, 0.0), "far_bridge": Vector3(92.0, 0.0, 0.0)},
			"west_bridge")


## ...and from where the retreat left it, the lock is the shorter (the case he saw it take).
func test_locks_from_the_north_quay_east_side_takes_the_lock() -> void:
	await _check("locks", Vector3(-40.0, 0.0, 88.0), Vector3(-10.0, 0.0, -20.0),
			{"lock": Vector3(0.0, 0.0, 0.0), "west_bridge": Vector3(-92.0, 0.0, 0.0), "far_bridge": Vector3(92.0, 0.0, 0.0)},
			"lock")


const BRIDGES := {"west": Vector3(-92.0, 0.0, 14.0), "east": Vector3(92.0, 0.0, -14.0)}
const NECKS := {"west_neck": Vector3(-40.0, 0.0, 44.0), "east_neck": Vector3(40.0, 0.0, 44.0),
		"west_road": Vector3(-104.0, 0.0, 44.0), "east_road": Vector3(104.0, 0.0, 44.0)}


func test_crossing_west_side_takes_the_west_bridge() -> void:
	await _check("crossing", Vector3(-60.0, 0.0, 60.0), Vector3(-40.0, 0.0, -60.0), BRIDGES, "west")


func test_crossing_east_side_takes_the_east_bridge() -> void:
	await _check("crossing", Vector3(40.0, 0.0, 60.0), Vector3(60.0, 0.0, -60.0), BRIDGES, "east")


func test_gorge_west_takes_the_west_neck() -> void:
	await _check("gorge", Vector3(-20.0, 0.0, 80.0), Vector3(-30.0, 0.0, 10.0), NECKS, "west_neck")


func test_gorge_east_takes_the_east_neck() -> void:
	await _check("gorge", Vector3(30.0, 0.0, 80.0), Vector3(20.0, 0.0, 10.0), NECKS, "east_neck")


## A Terminus street route: from the south approach to the plaza no longer than 1.3x the straight line.
func test_terminus_street_route_is_near_straight() -> void:
	await ArenaFixture.build(self, "terminus")
	var probe := Node3D.new()
	add_to_tree(probe)
	await wait_physics_frames(2)
	var from := Vector3(0.0, 0.0, 92.0)
	var to := Vector3(0.0, 0.0, 6.0)
	var route := Pathing.query(probe, from, to)
	var length := _length(route["points"])
	print("ROUTE_STREET terminus %s -> %s: %.1f m (straight %.1f)" % [from, to, length, from.distance_to(to)])
	assert_true(bool(route["reachable"]) and length <= 1.3 * from.distance_to(to),
			"the street route (%.1f m) is within 1.3x the straight line (%.1f m)" % [length, from.distance_to(to)])
