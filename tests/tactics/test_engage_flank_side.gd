extends TestCase
## Round 42 (engage, R42.10): THE MANEUVER HALF GOES ROUND ON THE SIDE WITH ROOM. The suite-ON check at 57e2e7eb5 turned
## the far_ambush drill red: under --attack-shot=on a crew's firing-spot move during react to contact shifted the
## maneuver half 3 m west, `_plan_fire_and_maneuver`'s side pick (the sign of (maneuver centre - focus) . right) flipped
## west, and on that stage the lane is 17 m from the arena edge: the flank point was clamped onto the wall and the "swing"
## was 17.0 m (73.3 m east, OFF). A flank into a wall is wrong in either arm; under ATTACK_SHOT the side whose flank point
## the arena clamps gives way to the other; both clamped, the one moved less; neither, the sign as today. OFF: today.
## Pure plans on hand-built situations (the drills test's pattern); the square +-DRIVABLE_LIMIT clamp (no arena built).

const FLANK_M := 42.0  # DoctrineTable.DRILL_DEFAULTS["flank_m"], the standard table

var _arena_was: Variant = null


## Orders.clamp_to_arena with no arena built: the square +-Match.DRIVABLE_LIMIT (restored by teardown).
func _square() -> void:
	if _arena_was == null:
		_arena_was = Arena.active
	Arena.active = {}


func teardown() -> void:
	ElementPlan.ATTACK_SHOT = true  # the default since R42.13
	if _arena_was != null:
		Arena.active = _arena_was
	super.teardown()


func _table() -> DoctrineTable:
	DoctrineTable.clear_cache()
	var loaded := DoctrineTable.load_table("standard")
	assert_true(loaded.has("table"), "the standard table loads: %s" % loaded.get("error", ""))
	return loaded.get("table")


## Four tanks at `positions` (Green_1 leads; slot order is by name, so Green_1/2 are the base of fire and Green_3/4 the
## maneuver half), one visible enemy at `enemy`, fired on, a far ambush already running on a move past it.
func _situation(positions: Array, enemy: Vector3) -> Dictionary:
	var members: Array = []
	var center := Vector3.ZERO
	for i in positions.size():
		members.append({"name": "Green_%d" % (i + 1), "position": positions[i], "forward": Vector3.FORWARD,
				"role": "tank", "unit": "tank", "speed": 9.0, "range": 70.0, "sight": 90.0, "health": 1.0,
				"suppression": 0.0, "taking_fire": true})
		center += positions[i] as Vector3
	center /= float(positions.size())
	var listed := [{"name": "Rust_1", "position": enemy, "role": "tank", "unit": "tank", "visible": true, "age": 200,
			"distance": enemy.distance_to(center), "bearing_deg": 0.0, "strength": 200.0, "speed": 0.0}]
	return {"tick": 1000, "team": 0, "center": center, "heading": Vector3.FORWARD, "leader": "Green_1",
			"members": members, "contacts": listed, "terrain": "open",
			"threat": ElementSituation.threat_from(listed, true), "composition": "heavy", "strength": 800.0,
			"enemy_strength": 200.0, "taking_fire": true, "arrived": false}


func _state(past: Vector3) -> Dictionary:
	return {"task": {"verb": "move", "to": [past.x, past.z]}, "drill": "far_ambush", "drill_tick": 1000 - 60,
			"drill_point": null, "drill_target": "Rust_1", "drill_why": "", "anchor": null, "bounding": 0,
			"arrived": false, "heading": Vector3.FORWARD}


## The flank point the maneuver half is routed to: the end of the plan's route.
func _flank_of(plan: Dictionary) -> Vector3:
	var route: Array = plan.get("route", [])
	assert_true(not route.is_empty(), "the maneuver half is routed round (%s)" % plan.get("why", ""))
	assert_eq(String((plan["orders"] as Dictionary).get("Green_3", {}).get("verb", "")), "move",
			"the maneuver half moves round (%s)" % [(plan["orders"] as Dictionary).get("Green_3")])
	return route[-1] if not route.is_empty() else Vector3.ZERO


## The far_ambush drill's stage, at the tick the side was picked under ON: the lane 18 m from the west edge, the
## maneuver half's centre 3 m west of the line of contact.
func _far_ambush_stage() -> Dictionary:
	var lane := -Match.DRIVABLE_LIMIT + 18.0
	return _situation([Vector3(lane, 0.0, -3.0), Vector3(lane, 0.0, 7.0), Vector3(lane - 3.0, 0.0, 12.0),
			Vector3(lane - 3.0, 0.0, 22.0)], Vector3(lane + 6.0, 0.0, -45.0))


func test_off_the_sign_picks_the_side_today_wall_or_not() -> void:
	_square()
	ElementPlan.ATTACK_SHOT = false
	var situation := _far_ambush_stage()
	var flank := _flank_of(ElementPlan.build(situation, _state(Vector3(-98.0, 0.0, -60.0)), _table()))
	var lane: float = (situation["members"][0]["position"] as Vector3).x
	assert_true(flank.x < lane - 20.0, "OFF: the maneuver half is sent west, into the arena edge (flank x %.1f, lane %.1f)"
			% [flank.x, lane])


func test_on_the_far_ambush_stage_goes_round_east_where_there_is_room() -> void:
	_square()
	ElementPlan.ATTACK_SHOT = true
	var situation := _far_ambush_stage()
	var flank := _flank_of(ElementPlan.build(situation, _state(Vector3(-98.0, 0.0, -60.0)), _table()))
	var lane: float = (situation["members"][0]["position"] as Vector3).x
	assert_true(flank.x > lane + 20.0, "ON: the maneuver half swings east, > 20 m off the lane (flank x %.1f, lane %.1f)"
			% [flank.x, lane])
	assert_true(flank.distance_to(ElementPlan.clamp_to_arena(flank)) < 0.5, "to a flank the arena does not clamp")


func test_on_both_sides_clamped_takes_the_one_moved_less() -> void:
	_square()
	ElementPlan.ATTACK_SHOT = true
	# The enemy in the south-west corner, the element north-east of it: both flanks run into a wall, the south one
	# (+side, the sign's pick with the maneuver half south-east of the line) by 18.7 m, the west one by 13.7 m.
	var enemy := Vector3(-100.0, 0.0, -105.0)
	var situation := _situation([Vector3(-75.0, 0.0, -68.0), Vector3(-68.0, 0.0, -75.0), Vector3(-55.0, 0.0, -70.0),
			Vector3(-50.0, 0.0, -75.0)], enemy)
	var flank := _flank_of(ElementPlan.build(situation, _state(Vector3(-110.0, 0.0, -110.0)), _table()))
	assert_true(flank.x < enemy.x - 20.0 and flank.z > enemy.z,
			"the west flank, clamped less (flank %s; south would be clamped 18.7 m, west 13.7 m)" % flank)
	ElementPlan.ATTACK_SHOT = false
	var today := _flank_of(ElementPlan.build(situation, _state(Vector3(-110.0, 0.0, -110.0)), _table()))
	assert_true(today.z < enemy.z - 20.0, "OFF: the sign's pick, the south flank, into the wall (%s)" % today)


func test_flank_side_is_pure_and_keeps_an_unclamped_pick() -> void:
	_square()
	var focus := Vector3.ZERO
	var right := Vector3.RIGHT
	assert_eq(ElementPlan.flank_side(focus, right, 1.0, FLANK_M), 1.0, "open ground both ways: the sign's side")
	assert_eq(ElementPlan.flank_side(focus, right, -1.0, FLANK_M), -1.0, "either sign")
	var near_east := Vector3(Match.DRIVABLE_LIMIT - 10.0, 0.0, 0.0)
	assert_eq(ElementPlan.flank_side(near_east, right, 1.0, FLANK_M), -1.0, "the east flank into the wall: west")
	assert_eq(ElementPlan.flank_side(near_east, right, -1.0, FLANK_M), -1.0, "west stays west")
