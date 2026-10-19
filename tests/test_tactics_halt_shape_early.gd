extends TestCase
## B6 (round 34; the orchestrator's item from brains' B10b diagnostic): AN ARRIVING ELEMENT DOES NOT RE-LAY ITS SEATS.
## Traced (main 9c0f4dfce, Sumps settle_probe s41 t3): the element travelled in a wedge and its final seats were wedge
## seats; the tick its centre came inside the arrival radius the plan switched to the halt, the table's hold shape (a
## herringbone), and every seat was re-laid 4-10 m away while the crews were still 15-20 m short. Under
## ElementPlan.HALT_SHAPE_EARLY a plain move's final approach (anchor on the destination, within INSET_NEAR_M, no shape
## he chose, no facing he drew) lays its destination seats in the halt's own shape already, so arriving moves nobody.
## PARKED: OFF by default (`--halt-shape-early=on` turns it on); these tests set it.


func teardown() -> void:
	ElementPlan.HALT_SHAPE_EARLY = false
	super.teardown()


func _members(at: Vector3) -> Array:
	var members: Array = []
	for i in 4:
		members.append({"name": "Green_S_%d" % (i + 1), "unit": "law_tank", "role": "tank", "speed": 9.0, "range": 60.0,
				"effective_range": 45.0, "sight": 60.0, "health": 1.0, "suppression": 0.0, "taking_fire": false,
				"forward": Vector3.FORWARD, "position": at + Vector3(i * 6.0 - 9.0, 0, 0)})
	return members


func _situation(center: Vector3, arrived: bool) -> Dictionary:
	return {"tick": 1000, "team": 0, "center": center, "heading": Vector3.FORWARD, "leader": "Green_S_1",
			"members": _members(center), "contacts": [], "terrain": "open", "threat": "none", "composition": "heavy",
			"strength": 800.0, "enemy_strength": 0.0, "taking_fire": false, "arrived": arrived}


## The seats of the last plan before the arrival tick and of the arrival tick's plan, as the element carries its state
## from one to the other (anchor, heading, formation, seats).
func _seats_across_arrival() -> Array:
	DoctrineTable.clear_cache()
	var table: DoctrineTable = DoctrineTable.load_table("standard")["table"]
	var destination := Vector3(0, 0, -60)
	var task := {"verb": "move", "to": [destination.x, destination.z]}
	var state := {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "", "drill_why": "",
			"anchor": null, "bounding": 0, "arrived": false, "heading": Vector3.FORWARD, "seats": {}}
	var before := ElementPlan.build(_situation(destination + Vector3(0, 0, ElementPlan.ARRIVE_M + 3.0), false), state, table)
	assert_true(not bool(before["arrived"]), "setup: not arrived yet")
	var carried := state.duplicate()
	carried["anchor"] = before["anchor"]
	carried["formation"] = before["formation"]
	carried["heading"] = before["heading"]
	carried["seats"] = before["seats"]
	var at := ElementPlan.build(_situation(destination + Vector3(0, 0, ElementPlan.ARRIVE_M - 3.0), false), carried, table)
	assert_true(bool(at["arrived"]), "setup: arrived")
	return [before, at]


func test_arriving_moves_no_seat() -> void:
	ElementPlan.HALT_SHAPE_EARLY = true
	var plans := _seats_across_arrival()
	var before: Dictionary = plans[0]
	var at: Dictionary = plans[1]
	assert_eq(String(before["formation"]), String(at["formation"]), "the final approach is already in the halt's shape")
	for name: String in at["slots"]:
		var moved := (before["slots"][name] as Vector3).distance_to(at["slots"][name])
		assert_true(moved <= 1.0, "%s's seat moved %.1f m at the arrival tick" % [name, moved])


func test_the_switch_off_is_mains_rule() -> void:
	ElementPlan.HALT_SHAPE_EARLY = false
	var plans := _seats_across_arrival()
	var worst := 0.0
	for name: String in plans[1]["slots"]:
		worst = maxf(worst, (plans[0]["slots"][name] as Vector3).distance_to(plans[1]["slots"][name]))
	assert_true(String(plans[0]["formation"]) != String(plans[1]["formation"]) or worst > 1.0,
			"--halt-shape-early=off: the travel shape re-lays into the halt's at arrival (worst %.1f m, %s -> %s)" % [
			worst, plans[0]["formation"], plans[1]["formation"]])
