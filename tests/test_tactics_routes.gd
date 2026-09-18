extends TestCase
## Round 6, squad X7: a flank goes round the way the enemy can see least of. Pure, on a hand-built cover map: an enemy
## to the north, a wall south of the direct line, and an annotated lane behind the wall.

const ENEMY := Vector3(0, 0, -60)


func _map() -> CoverMap:
	# A wall 80 m long, 4 m deep, 3 m tall, along z = +20 from x = -40 to +40.
	return CoverMap.from_features([{"position": [0.0, 20.0], "size": [80.0, 3.0, 4.0], "height": 3.0, "type": "wall"}])


func _lane() -> Array:
	return [{"name": "behind the wall", "points": PackedVector3Array([Vector3(-60, 0, 30), Vector3(60, 0, 30)]), "width": 12.0}]


func test_a_flank_takes_the_covered_lane_instead_of_crossing_their_front() -> void:
	var route := CoveredRoute.choose(_map(), Vector3(-50, 0, 0), Vector3(50, 0, 0), [ENEMY], 90.0, _lane())
	print("MEASURE covered_route %s" % route)
	assert_true(String(route["via"]) != "direct", "not straight across their front (%s)" % route["via"])
	assert_true(float(route["direct_exposed_m"]) > 80.0, "the direct line is in their sight nearly all the way (%.0f m)"
			% route["direct_exposed_m"])
	assert_true(float(route["exposed_m"]) < float(route["direct_exposed_m"]) * 0.4,
			"the chosen route is mostly hidden (%.0f m seen vs %.0f direct)" % [route["exposed_m"], route["direct_exposed_m"]])
	var last: Vector3 = (route["waypoints"] as Array).back()
	assert_true(last.is_equal_approx(Vector3(50, 0, 0)), "and it still ends where the flank is")


func test_with_nobody_watching_the_direct_route_wins() -> void:
	var route := CoveredRoute.choose(_map(), Vector3(-50, 0, 0), Vector3(50, 0, 0), [], 90.0, _lane())
	assert_eq(route["via"], "direct", "no threat, no detour")
	assert_eq((route["waypoints"] as Array).size(), 1, "one leg")


func test_an_element_on_a_move_task_follows_the_route_leg_by_leg() -> void:
	# ElementPlan with a known enemy: the leader's heading points at the first waypoint, not at the destination.
	DoctrineTable.clear_cache()
	var table: DoctrineTable = DoctrineTable.load_table("standard")["table"]
	var members: Array = []
	for i in 3:
		members.append({"name": "G%d" % i, "position": Vector3(-50 + i * 4.0, 0, 0), "forward": Vector3.RIGHT,
				"role": "tank", "unit": "tank", "speed": 9.0, "range": 70.0, "effective_range": 70.0, "sight": 90.0,
				"health": 1.0, "suppression": 0.0, "taking_fire": false})
	var contacts := [{"name": "R1", "position": ENEMY, "role": "tank", "unit": "tank", "visible": false, "age": 900,
			"distance": 70.0, "bearing_deg": 0.0, "strength": 100.0, "speed": 0.0}]
	var situation := {"tick": 1000, "team": 0, "center": Vector3(-46, 0, 0), "heading": Vector3.RIGHT, "leader": "G0",
			"members": members, "contacts": contacts, "terrain": "open", "threat": "likely", "composition": "heavy",
			"strength": 900.0, "enemy_strength": 100.0, "taking_fire": false, "arrived": false,
			"cover_map": _map(), "lanes": _lane(), "sight": 90.0}
	var state := {"task": {"verb": "move", "to": [50, 0]}, "drill": "", "drill_tick": 0, "drill_point": null,
			"drill_target": "", "drill_why": "", "anchor": null, "bounding": 0, "arrived": false, "heading": Vector3.RIGHT,
			"seats": {}, "route": [], "route_index": 0}
	var plan := ElementPlan.build(situation, state, table)
	assert_true((plan["route"] as Array).size() >= 2, "the leader picked a route with waypoints (%s)" % [plan["route"]])
	assert_true((plan["heading"] as Vector3).z > 0.3, "and heads for cover (south), not straight east (%s)" % plan["heading"])
	var plain := state.duplicate()
	plain["task"] = {"verb": "move", "to": [50, 0], "drills": false}
	var direct := ElementPlan.build(situation, plain, table)
	assert_true((direct["route"] as Array).is_empty(), "a plain move goes where it was sent, by the direct line")
