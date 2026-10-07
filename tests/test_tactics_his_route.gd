extends TestCase
## Round 21 (orders' R2, their trace: foundry, five gang vees, his attack-move, merged P0+P1): (c) a squad of his took
## the covered route 45 m sideways (x = -101) on its way; (b) when a drill ended, the leg anchor was where it had been
## BEFORE the drill and a crew sat with no order for 5 s, 56 m short. Pure plans on hand-built situations.


func _situation(contacts: Array) -> Dictionary:
	var members: Array = []
	for i in 4:
		members.append({"name": "Green_%d" % (i + 1), "position": Vector3(i * 6.0 - 9.0, 0.0, 0.0),
				"forward": Vector3.FORWARD, "role": "tank", "unit": "law_tank", "speed": 12.0, "range": 70.0,
				"effective_range": 60.0, "sight": 78.0, "health": 1.0, "suppression": 0.0, "taking_fire": false})
	return {"tick": 1000, "team": 0, "center": Vector3.ZERO, "heading": Vector3.FORWARD, "leader": "Green_1",
			"members": members, "contacts": contacts, "terrain": "open",
			"threat": ElementSituation.threat_from(contacts, false), "composition": "heavy", "strength": 1600.0,
			"enemy_strength": 400.0, "taking_fire": false, "arrived": false}


func _table() -> DoctrineTable:
	return DoctrineTable.load_table("standard")["table"]


func test_his_attack_move_takes_his_line_and_the_computers_takes_the_covered_route() -> void:
	# Something known off to the side, 150 m out (no contact drill), and the move 120 m ahead.
	var known := [{"name": "Rust_1", "position": Vector3(-60.0, 0.0, -140.0), "visible": false, "age": 500,
			"distance": 152.0, "bearing_deg": -23.0, "strength": 400.0, "speed": 0.0}]
	var task := {"verb": "move", "to": [0.0, -120.0]}
	var his := ElementPlan.build(_situation(known), {"task": task, "player": true, "heading": Vector3.FORWARD}, _table())
	var cpu := ElementPlan.build(_situation(known), {"task": task, "player": false, "heading": Vector3.FORWARD}, _table())
	assert_eq(his["route"], [], "his: no covered route (%s)" % [his["route"]])
	assert_true(not (cpu["route"] as Array).is_empty(), "the computer's: a covered route is chosen (%s)" % [cpu["route"]])


func test_when_a_drill_ends_the_leg_restarts_from_where_the_element_is() -> void:
	var table := _table()
	var stale := Vector3(0.0, 0.0, 90.0)  # where the leg was before the drill took the element 90 m on
	var state := {"task": {"verb": "move", "to": [0.0, -120.0]}, "player": true, "heading": Vector3.FORWARD,
			"drill": "far_ambush", "drill_tick": 0, "anchor": stale, "anchor_by_drill": false}
	var plan := ElementPlan.build(_situation([]), state, table)
	assert_eq(plan["drill"], "", "the drill is over (timed out, nothing in sight)")
	assert_true(plan["anchor"] == null or (plan["anchor"] as Vector3).distance_to(stale) > 30.0,
			"the leg is no longer anchored on the old point (%s)" % [plan["anchor"]])
	for unit_name: String in plan["slots"]:
		assert_true((plan["slots"][unit_name] as Vector3).z < 20.0,
				"%s's slot is ahead of the element, not back at the old leg (%s)" % [unit_name, plan["slots"][unit_name]])
	# A drill that SET its own anchor (assault through's point past the ambush) leaves it standing: it is still to reach.
	var through := Vector3(40.0, 0.0, 10.0)
	var kept := {"task": {"verb": "move", "to": [0.0, -120.0]}, "player": true, "heading": Vector3.FORWARD,
			"drill": "react_to_contact", "drill_tick": 0, "anchor": through, "anchor_by_drill": true}
	assert_true(not ElementPlan.stale_anchor(kept), "an anchor a drill set is not stale")
