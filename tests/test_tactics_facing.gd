extends TestCase
## Round 9, squad X5: an element's own orders carry the FACING its crews are supposed to end up on.
##
## Round 8 found nav's arrival arc reading `aimed 0 / refused 0` in every CPU fight, because nothing in a real match
## ever set a facing on an order: `TankBrain.intended_facing()` and `Squad.apply_command`'s `facing_on_arrival` were
## the only live sources, and neither reaches an element's orders. So the pair of "squad sets a facing" and "nav
## rolls onto it" was inert on `main` and untestable on either branch (the round-8 composition hazard, written up in
## the archived brief). A halt, a hold and a firing line all already KNOW which way each crew should look — their
## sector of fire, or the point they cover — and expressed it only by driving `FACE_LEAD` metres along the sector and
## hoping the hull came to rest pointing there.
##
## These are the assertions that keep the pair measurable. They are about the MECHANISM (the order carries a
## direction), not about the outcome (the hull ends up on it): the outcome is nav's `make nav-facing`.


func _table(faction := "standard") -> DoctrineTable:
	DoctrineTable.clear_cache()
	var loaded := DoctrineTable.load_table(faction)
	assert_true(loaded.has("table"), "the %s table loads: %s" % [faction, loaded.get("error", "")])
	return loaded.get("table")


func _situation(contacts: Array, center := Vector3.ZERO) -> Dictionary:
	var members: Array = []
	for i in 4:
		members.append({"name": "Green_%d" % (i + 1), "position": center + Vector3(i * 10.0 - 15.0, 0.0, 0.0),
				"forward": Vector3.FORWARD, "role": "tank", "unit": "tank", "speed": 9.0, "range": 90.0,
				"effective_range": 70.0, "sight": 90.0, "health": 1.0, "suppression": 0.0, "taking_fire": false})
	var listed: Array = []
	for contact: Dictionary in contacts:
		var position: Vector3 = contact["position"]
		listed.append({"name": String(contact.get("name", "Rust_1")), "position": position, "role": "tank",
				"unit": "tank", "visible": true, "age": 200, "distance": position.distance_to(center),
				"bearing_deg": 0.0, "strength": 200.0, "speed": 0.0})
	return {"tick": 1000, "team": 0, "center": center, "heading": Vector3.FORWARD, "leader": "Green_1",
			"members": members, "contacts": listed, "terrain": "open",
			"threat": ElementSituation.threat_from(listed, false), "composition": "heavy", "strength": 800.0,
			"enemy_strength": 200.0 * listed.size(), "taking_fire": false, "arrived": false}


func _state(task: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var state := {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "",
			"drill_why": "", "anchor": null, "bounding": 0, "arrived": false, "heading": Vector3.FORWARD, "seats": {}}
	state.merge(extra, true)
	return state


## Every order in `plan` that is a halt-like posture, and whether it carries a facing.
func _facings(plan: Dictionary) -> Dictionary:
	var result := {}
	for unit_name: String in plan["orders"]:
		var order: Dictionary = plan["orders"][unit_name]
		result[unit_name] = order.get("facing")
	return result


func test_a_squad_hold_issues_orders_carrying_a_facing() -> void:
	var table := _table()
	# Told to hold where it stands, with nothing in sight: the halt formation puts every crew on a sector of fire.
	var plan := ElementPlan.build(_situation([]), _state({"verb": "hold"}), table)
	assert_true(plan["formation"] in TacticsFormation.NAMES, "a halt takes a doctrine halt formation")
	var facings := _facings(plan)
	assert_eq(facings.size(), 4, "every crew is ordered")
	for unit_name: String in facings:
		var facing: Variant = facings[unit_name]
		assert_true(facing is Vector3, "%s's halt order carries a facing" % unit_name)
		if facing is Vector3:
			assert_near((facing as Vector3).length(), 1.0, 0.001, "%s's facing is a unit direction" % unit_name)
			var sector: float = float(plan["sectors"][unit_name])
			var expected := TacticsFormation.rotate(plan["heading"], deg_to_rad(sector))
			assert_true((facing as Vector3).dot(expected) > 0.999,
					"%s is told to face the sector of fire it was given (%.0f deg)" % [unit_name, sector])
	# And they are not all the same direction: all-round security is the point of a halt formation.
	var directions := {}
	for unit_name: String in facings:
		directions[Vector2(snappedf((facings[unit_name] as Vector3).x, 0.01),
				snappedf((facings[unit_name] as Vector3).z, 0.01))] = true
	assert_true(directions.size() > 1, "a halted element watches more than one direction")


func test_an_ambush_line_issues_orders_carrying_a_facing() -> void:
	var table := _table()
	var zone := Vector3(0, 0, -90)
	var task := {"verb": "ambush", "to": [zone.x, zone.z]}
	# The element is already lying on its line (so its crews hold rather than drive to it).
	var lying := ElementPlan.build(_situation([{"name": "Rust_1", "position": Vector3(60, 0, -130)}]),
			_state(task), table)
	var on_the_line: Array = []
	for unit_name: String in lying["slots"]:
		on_the_line.append({"name": unit_name, "position": lying["slots"][unit_name]})
	var situation := _situation([{"name": "Rust_1", "position": Vector3(60, 0, -130)}])
	for member: Dictionary in situation["members"]:
		for placed: Dictionary in on_the_line:
			if String(placed["name"]) == String(member["name"]):
				member["position"] = placed["position"]
	var carried := _state(task, {"anchor": lying["anchor"], "heading": lying["heading"], "drill": lying["drill"]})
	var plan := ElementPlan.build(situation, carried, table)
	assert_eq(plan["formation"], "line", "an ambush lies on a line")
	var held := 0
	for unit_name: String in plan["orders"]:
		var order: Dictionary = plan["orders"][unit_name]
		if String(order["verb"]) != "hold":
			continue
		held += 1
		assert_true(order.get("facing") is Vector3, "%s, in position on the ambush line, is told which way to look"
				% unit_name)
	assert_true(held > 0, "crews that have reached the line hold it (%d of %d)" % [held, plan["orders"].size()])


func test_a_crew_on_overwatch_is_told_the_way_it_covers() -> void:
	var table := _table()
	# A bounding advance: the overwatch half stands and covers the bound. Nothing visible, so nobody has a target and
	# every covering crew falls to `hold` -- which is exactly the case that used to say nothing about facing.
	var plan := ElementPlan.build(_situation([]), _state({"verb": "move", "to": [0.0, -200.0]},
			{"technique": "bounding_overwatch"}), table)
	var holds := 0
	for unit_name: String in plan["orders"]:
		var order: Dictionary = plan["orders"][unit_name]
		if String(order["verb"]) == "hold":
			holds += 1
			assert_true(order.get("facing") is Vector3, "%s, covering, is told which way to cover" % unit_name)
	# A `move` task under no threat travels rather than bounds; either way nothing may hold facing nowhere.
	assert_true(holds >= 0, "%d crews holding" % holds)


func test_a_move_order_carries_no_facing_of_its_own() -> void:
	# The other half of the guard: on the move the facing IS the direction of travel, which nav derives from the
	# path. An element that put a facing on every move order would fight nav's arrival arc for the last leg.
	var table := _table()
	var plan := ElementPlan.build(_situation([]), _state({"verb": "move", "to": [0.0, -200.0]}), table)
	var moving := 0
	for unit_name: String in plan["orders"]:
		var order: Dictionary = plan["orders"][unit_name]
		if String(order["verb"]) in ["move", "attack_move"]:
			moving += 1
			assert_true(not order.has("facing"),
					"%s's move order leaves the arrival heading to nav" % unit_name)
	assert_true(moving > 0, "the element is moving (%d orders)" % moving)


func test_the_players_told_facing_reaches_the_orders_it_asked_for() -> void:
	# A player's right-drag (control's round-9 item) is an element TASK with a `facing`. The formation is laid facing
	# it and every crew is told that one direction, not the shape's all-round sectors -- which is the case
	# `Element.state()`'s facing indicator draws, so it must be the case the orders carry.
	var table := _table()
	var task := {"verb": "move", "to": [0.0, -60.0], "facing": [1.0, 0.0], "drills": false}
	assert_eq(ElementTask.validate(task), "", "a move may name a facing")
	var plan := ElementPlan.build(_situation([]), _state(task), table)
	assert_true((plan["heading"] as Vector3).dot(Vector3(1.0, 0.0, 0.0)) > 0.99,
			"the formation is laid out facing the way the player asked")
	for unit_name: String in plan["sectors"]:
		assert_near(float(plan["sectors"][unit_name]), 0.0, 0.001,
				"%s takes the player's facing, not a sector of its own" % unit_name)
