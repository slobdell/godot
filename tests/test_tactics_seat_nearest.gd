extends TestCase
## Round 25 (brains F1, C25.5): SEATS BY NEAREST. The lead, 2026-10-10: *"squads trying to get into formation should
## determine whose position is whose based on who is already closest to the position in that formation"*, and his
## option 2: while moving the nearest crew wins and "heavies in front" is only a short swap; once the squad halts the
## heavies take the front / outside spots even when that is a longer drive. One test per rule of
## `TacticsFormation.seat`, and the plain move's seats laid along its route (`ElementPlan.route_seats`).

const NORTH := Vector3(0, 0, -1)


static func _crew(name: String, at: Vector3, unit := "tank") -> Dictionary:
	return {"name": name, "position": at, "unit": unit}


func teardown() -> void:
	TacticsFormation.NEAREST_ENABLED = true
	ElementPlan.NEAREST_ON_ROUTE = true


func test_the_nearest_crew_takes_each_spot_and_a_named_leader_keeps_the_point() -> void:
	# A column moving north. With no leader named (a plain move), the crew already at the front takes the point.
	var column := TacticsFormation.centered(TacticsFormation.offsets("column", 3, 12.0))
	var members: Array = [_crew("Lead", Vector3(0, 0, 14)), _crew("B", Vector3(0, 0, 1)), _crew("C", Vector3(0, 0, -12))]
	var seating := TacticsFormation.seat(members, column, Vector3.ZERO, NORTH, {"policy": "front"})
	assert_eq(int(seating["C"]), 0, "the crew already at the front takes the point")
	assert_eq(int(seating["Lead"]), 2, "the crew at the back stays at the back")
	# A drill move names its leader, and it keeps the point (F1 measured unpinning it there: 6 behaviours broke).
	var drill := TacticsFormation.seat(members, column, Vector3.ZERO, NORTH, {"leader": "Lead", "policy": "front"})
	assert_eq(int(drill["Lead"]), 0, "a named leader keeps the point")


func test_on_the_move_a_heavy_takes_the_front_only_as_a_short_swap() -> void:
	var column := TacticsFormation.centered(TacticsFormation.offsets("column", 2, 12.0))
	# Side by side within a few metres: putting the tank in front costs the pair 4 m more driving. Worth it.
	var close: Array = [_crew("Light", Vector3(0, 0, -1), "scout"), _crew("Heavy", Vector3(0, 0, 1), "tank")]
	var near := TacticsFormation.seat(close, column, Vector3.ZERO, NORTH, {"policy": "front"})
	assert_eq(int(near["Heavy"]), 0, "a heavy a hull's length behind a light slips past it to the front")
	# The heavy 36 m back: putting it in front costs 24 m more. Not on the move.
	var far: Array = [_crew("Light", Vector3(0, 0, -6), "scout"), _crew("Heavy", Vector3(0, 0, 30), "tank")]
	var moving := TacticsFormation.seat(far, column, Vector3.ZERO, NORTH, {"policy": "front"})
	assert_eq(int(moving["Light"]), 0, "the light crew already in front keeps the front")
	assert_eq(int(moving["Heavy"]), 1, "the heavy does not drive past it to the point while the squad moves")
	assert_true(TacticsFormation.SHORT_SWAP_M < 24.0 and TacticsFormation.SHORT_SWAP_M > 4.0,
			"the threshold sits between those two swaps (%.1f m)" % TacticsFormation.SHORT_SWAP_M)


func test_once_halted_the_heavies_take_the_front_whatever_the_drive() -> void:
	# His option 2: the same far case, the squad standing on its spot.
	var column := TacticsFormation.centered(TacticsFormation.offsets("column", 2, 12.0))
	var far: Array = [_crew("Light", Vector3(0, 0, -6), "scout"), _crew("Heavy", Vector3(0, 0, 30), "tank")]
	var halted := TacticsFormation.seat(far, column, Vector3.ZERO, NORTH, {"policy": "front", "halted": true})
	assert_eq(int(halted["Heavy"]), 0, "halted, the heavy takes the front even 24 m of driving away")
	# A halt drill's sectors (`halt`) count as halted too, and "exposure" puts armour on the outside of a line.
	var line := TacticsFormation.centered(TacticsFormation.offsets("line", 3, 12.0))
	var members: Array = [_crew("Outer", Vector3(-12, 0, 0), "scout"), _crew("Middle", Vector3(0, 0, 0), "tank"),
			_crew("Other", Vector3(12, 0, 0), "scout")]
	var standing := TacticsFormation.seat(members, line, Vector3.ZERO, NORTH, {"policy": "exposure", "halt": true})
	var middle_slot := 0
	for i in line.size():
		if absf(line[i].x) < absf(line[middle_slot].x):
			middle_slot = i
	assert_true(int(standing["Middle"]) != middle_slot, "halted, the tank leaves the inside of the line for an end")
	var on_the_move := TacticsFormation.seat(members, line, Vector3.ZERO, NORTH, {"policy": "exposure"})
	assert_eq(int(on_the_move["Middle"]), middle_slot, "moving, it keeps the middle: a 12 m swap is not a short one")


func test_a_layout_with_nobody_driving_keeps_the_pinned_leader_and_the_tiers() -> void:
	# An army laid out at its spawn (ArmyLayout's deploy): no positions, nothing is driven, the old precedence.
	var members: Array = [{"name": "Eyes", "unit": "scout"}, {"name": "Lead", "unit": "tank"},
			{"name": "Gun", "unit": "artillery"}]
	var column := TacticsFormation.centered(TacticsFormation.offsets("column", 3, 12.0))
	var laid := TacticsFormation.seat(members, column, Vector3.ZERO, NORTH, {"leader": "Eyes", "policy": "front"})
	assert_eq(int(laid["Eyes"]), 0, "a layout still puts the named leader on the point")
	assert_eq(int(laid["Gun"]), 2, "and the artillery at the back")


func test_the_stability_rule_still_keeps_a_seating_that_costs_little_more() -> void:
	var column := TacticsFormation.centered(TacticsFormation.offsets("column", 2, 12.0))
	var members: Array = [_crew("A", Vector3(0.5, 0, -6), "tank"), _crew("B", Vector3(-0.5, 0, 6), "tank")]
	var kept := TacticsFormation.seat(members, column, Vector3.ZERO, NORTH, {"previous": {"A": 1, "B": 0},
			"spacing": 12.0, "policy": "front"})
	assert_eq(int(kept["A"]), 0, "a swap that saves 24 m is taken...")
	var swayed: Array = [_crew("A", Vector3(0, 0, 0.5), "tank"), _crew("B", Vector3(0, 0, -0.5), "tank")]
	var stays := TacticsFormation.seat(swayed, column, Vector3.ZERO, NORTH, {"previous": {"A": 0, "B": 1},
			"spacing": 12.0, "policy": "front"})
	assert_eq(int(stays["A"]), 0, "...but two crews swaying past each other by a metre keep their seats (no swap every tick)")


func test_the_caller_can_place_the_seats_itself() -> void:
	# `at`: one world point per slot, the caller's own placing (a shape laid along a route).
	var column := TacticsFormation.centered(TacticsFormation.offsets("column", 2, 12.0))
	var members: Array = [_crew("A", Vector3(100, 0, 0)), _crew("B", Vector3(0, 0, 0))]
	var seating := TacticsFormation.seat(members, column, Vector3.ZERO, NORTH,
			{"at": [Vector3(98, 0, 0), Vector3(2, 0, 0)]})
	assert_eq(int(seating["A"]), 0, "slot 0 stands where the caller put it, beside A")
	assert_eq(int(seating["B"]), 1, "and slot 1 beside B")


func test_a_plain_move_seats_its_crews_along_its_route_not_at_the_click() -> void:
	# His east bridge in miniature: the route runs EAST along the quay, then SOUTH over the bridge to the click. A is
	# ahead along the route (east); B is behind it but nearer the click as the crow flies.
	var route: Array = [Vector3(0, 0, 0), Vector3(100, 0, 0), Vector3(100, 0, 100)]
	var to := Vector3(100, 0, 100)
	var members: Array = [_crew("A", Vector3(5, 0, -5)), _crew("B", Vector3(-10, 0, 20)), _crew("C", Vector3(-12, 0, -9))]
	assert_true(members[1]["position"].distance_to(to) < members[0]["position"].distance_to(to),
			"the stage: B is nearer the click than A")
	var shape := TacticsFormation.centered(TacticsFormation.offsets("wedge", 3, 12.0))
	var at_click := TacticsFormation.seat(members, shape, to, Vector3(0, 0, 1), {"policy": "travel"})
	assert_eq(int(at_click["B"]), 0, "matched against the slots at the click, B (from the back) took the point")
	var seats := ElementPlan.route_seats(members, "wedge", 12.0, {"route": route, "s": 0.5 * TacticsFormation.depth("wedge", 3, 12.0)})
	assert_eq(seats.size(), 3, "one point per seat")
	var on_route := TacticsFormation.seat(members, shape, to, Vector3(0, 0, 1), {"policy": "travel", "at": seats})
	assert_eq(int(on_route["A"]), 0, "matched along the route, A (already in front) takes the point")
	var point: Vector3 = seats[0]
	assert_true(point.x > 0.0 and absf(point.z) < 1.0, "the point's station is ahead on the first leg, east (%s)" % point)


func _halt_situation(at: Dictionary, tick: int) -> Dictionary:
	var members: Array = []
	for name: String in ["Left", "Middle", "Right"]:
		var unit := "tank" if name == "Middle" else "scout"
		members.append({"name": name, "position": at[name], "forward": Vector3.FORWARD, "role": Units.role_of(unit),
				"unit": unit, "speed": 9.0, "range": 90.0, "effective_range": 70.0, "sight": 90.0, "health": 1.0,
				"suppression": 0.0, "taking_fire": false})
	return {"tick": tick, "team": 0, "center": Vector3.ZERO, "heading": Vector3.FORWARD, "leader": "Left",
			"members": members, "contacts": [], "terrain": "open", "threat": "none", "composition": "mixed",
			"strength": 600.0, "enemy_strength": 0.0, "taking_fire": false, "arrived": true}


func test_a_plain_move_that_has_stood_on_its_spot_puts_its_heavy_outside() -> void:
	# His option 2: once halted (the element on its spot HALT_RESEAT_TICKS), the heavies take the outside, once.
	DoctrineTable.clear_cache()
	var table: DoctrineTable = DoctrineTable.load_table("standard").get("table")
	var task := {"verb": "move", "to": [0.0, 0.0], "drills": false, "formation": "line"}
	var state := {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "", "drill_why": "",
			"anchor": Vector3.ZERO, "bounding": 0, "arrived": true, "heading": Vector3.FORWARD, "flow_joined": true,
			"seats": {}, "arrived_tick": -1, "halt_seated": false}
	# The crews stand abreast on the spot with the tank in the middle (where the nearest rule put it on the way).
	var at := {"Left": Vector3(-12, 0, 0), "Middle": Vector3(0, 0, 0), "Right": Vector3(12, 0, 0)}
	var standing := ElementPlan.build(_halt_situation(at, 1000), state, table)
	var middle := int((standing["seats"]["Middle"] as Array)[2])
	var seated_at: Vector3 = standing["slots"]["Middle"]
	assert_true(absf(seated_at.x) < 1.0, "setup: just arrived, the tank keeps the middle (%s)" % seated_at)
	state["seats"] = standing["seats"]
	state["arrived_tick"] = 1000
	var soon := ElementPlan.build(_halt_situation(at, 1000 + ElementPlan.HALT_RESEAT_TICKS - 1), state, table)
	assert_eq(int((soon["seats"]["Middle"] as Array)[2]), middle, "a squad still settling onto its spot is not reshuffled")
	assert_true(not bool(soon.get("halt_seated", false)), "and has not taken its halt seating yet")
	var halted := ElementPlan.build(_halt_situation(at, 1000 + ElementPlan.HALT_RESEAT_TICKS), state, table)
	var outside: Vector3 = halted["slots"]["Middle"]
	assert_true(absf(outside.x) > 5.0, "halted, the tank takes an end of the line (%s)" % outside)
	assert_true(bool(halted.get("halt_seated", false)), "once")
	state["seats"] = halted["seats"]
	state["halt_seated"] = true
	var later := ElementPlan.build(_halt_situation(at, 1000 + ElementPlan.HALT_RESEAT_TICKS * 3), state, table)
	assert_eq(later["seats"], halted["seats"], "and then the seating stands")
	TacticsFormation.NEAREST_ENABLED = false
	ElementPlan.NEAREST_ON_ROUTE = false
	state["seats"] = standing["seats"]
	state["halt_seated"] = false
	var control := ElementPlan.build(_halt_situation(at, 1000 + ElementPlan.HALT_RESEAT_TICKS), state, table)
	ElementPlan.NEAREST_ON_ROUTE = true
	assert_eq(control["seats"], standing["seats"], "the control arm: round 24's plain move never re-seated on its spot")
