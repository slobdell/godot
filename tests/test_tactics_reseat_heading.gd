extends TestCase
## Round 32 (C32.5, brains' answer to manoeuvre's question (c)): what of a member's HEADING the element's seating reads.
## Seat matching itself (TacticsFormation.seat) reads positions only. The heading enters through the SHAPE: an
## attack-move that arrives with no drawn facing lays its halt formation along the element's heading, which
## ElementSituation.build averages from the members' hull forwards (element_situation.gd, "The element's own facing").
## That is read once, on the arrival plan; after it the element keeps the heading it arrived with (_halt), and a drawn
## facing replaces it. So a wheeled turret member turning its hull BEFORE the element arrives moves every seat; after,
## it moves none. Pinned here so a change to either half is a visible decision.


func _table() -> DoctrineTable:
	DoctrineTable.clear_cache()
	return DoctrineTable.load_table("standard").get("table")


## Four tanks abreast at the destination, every hull pointed `forward` (the situation's heading is their average).
func _situation(forward: Vector3) -> Dictionary:
	var members: Array = []
	for i in 4:
		members.append({"name": "Green_%d" % (i + 1), "position": Vector3(i * 6.0 - 9.0, 0.0, 0.0),
				"forward": forward, "role": "tank", "unit": "tank", "speed": 9.0, "range": 90.0,
				"effective_range": 70.0, "sight": 90.0, "health": 1.0, "suppression": 0.0, "taking_fire": false})
	return {"tick": 1000, "team": 0, "center": Vector3.ZERO, "heading": forward, "leader": "Green_1",
			"members": members, "contacts": [], "terrain": "open", "threat": ElementSituation.threat_from([], false),
			"composition": "heavy", "strength": 800.0, "enemy_strength": 0.0, "taking_fire": false, "arrived": false}


func _state(task: Dictionary, arrived: bool, heading: Vector3) -> Dictionary:
	return {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "", "drill_why": "",
			"anchor": null, "bounding": 0, "arrived": arrived, "heading": heading, "seats": {}}


func _angle(a: Vector3, b: Vector3) -> float:
	return rad_to_deg(TacticsFormation.flat(a).angle_to(TacticsFormation.flat(b)))


func test_arriving_with_no_facing_the_halt_is_laid_along_the_members_hulls() -> void:
	var table := _table()
	var task := {"verb": "move", "to": [0.0, 0.0]}  # an attack-move (drills on), no facing drawn
	var north := ElementPlan.build(_situation(Vector3.FORWARD), _state(task, false, Vector3.FORWARD), table)
	var east := ElementPlan.build(_situation(Vector3.RIGHT), _state(task, false, Vector3.FORWARD), table)
	assert_true(_angle(north["heading"], Vector3.FORWARD) < 1.0, "hulls north: the shape faces north")
	assert_true(_angle(east["heading"], Vector3.RIGHT) < 1.0, "hulls east: the shape faces east")
	assert_true(north["slots"] != east["slots"], "so the seats differ with the hulls' heading at arrival")


func test_once_arrived_the_element_keeps_its_heading_whatever_the_hulls_do() -> void:
	var table := _table()
	var task := {"verb": "move", "to": [0.0, 0.0]}
	var kept := ElementPlan.build(_situation(Vector3.RIGHT), _state(task, true, Vector3.FORWARD), table)
	assert_true(_angle(kept["heading"], Vector3.FORWARD) < 1.0, "arrived facing north, hulls turned east: still north")


func test_a_drawn_facing_replaces_the_hulls_heading() -> void:
	var table := _table()
	var task := {"verb": "move", "to": [0.0, 0.0], "facing": [-1.0, 0.0]}
	var plan := ElementPlan.build(_situation(Vector3.RIGHT), _state(task, false, Vector3.FORWARD), table)
	assert_true(_angle(plan["heading"], Vector3.LEFT) < 1.0, "his facing west wins over hulls pointed east")
