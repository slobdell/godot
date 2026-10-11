extends TestCase
## Round 26, brains B0 (C26.3): every ARMED task honours a facing the player drew.
##
## His words (game_design.md *Round 26 direction*): *"I was trying to get tanks oriented in a screen at a particular
## angle ... it short-circuit directly to screen and so the vehicles moved into a line abreast angle I didn't want. This
## is probably the case for all our specialized cases (attack, ambush, screen, etc)."* Orders makes the gesture put
## `task["facing"]` on the task; these tests hold the brains' half: when the key is there,
##   - a screen's line is laid ACROSS it (the line looks along the facing),
##   - support by fire stands off its point against the facing and looks along it, at the point,
##   - an ambush lies the same way (or at its `from`, looking along the facing),
##   - an attack-move (a `move` with drills on) arrives standing facing it;
## and when it is absent, every one of them does exactly what it did before (the heading each task's own geometry
## chose), so the CPU's tasks, which never carry one, are unmoved.


const EAST := Vector3(1.0, 0.0, 0.0)


func _table(faction := "standard") -> DoctrineTable:
	DoctrineTable.clear_cache()
	var loaded := DoctrineTable.load_table(faction)
	assert_true(loaded.has("table"), "the %s table loads: %s" % [faction, loaded.get("error", "")])
	return loaded.get("table")


func _situation(center := Vector3.ZERO, contacts: Array = []) -> Dictionary:
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


## The plan's next update as Element would carry it (anchor, heading, drill, arrival kept), with the crews standing on
## the slots they were given.
func _settled(task: Dictionary, situation: Dictionary, first: Dictionary) -> Dictionary:
	var moved := situation.duplicate(true)
	for member: Dictionary in moved["members"]:
		var slot: Variant = first["slots"].get(String(member["name"]))
		if slot is Vector3:
			member["position"] = slot
	var center := Vector3.ZERO
	for member: Dictionary in moved["members"]:
		center += member["position"]
	moved["center"] = center / float(moved["members"].size())
	return ElementPlan.build(moved, _state(task, {"anchor": first["anchor"], "heading": first["heading"],
			"drill": first["drill"], "arrived": first["arrived"]}), _table())


## The spread of the plan's slots, measured along `axis`: a line laid ACROSS a heading has its slots spread across it.
func _extent_along(plan: Dictionary, axis: Vector3) -> float:
	var lo := INF
	var hi := -INF
	for unit_name: String in plan["slots"]:
		var along := (plan["slots"][unit_name] as Vector3).dot(axis)
		lo = minf(lo, along)
		hi = maxf(hi, along)
	return hi - lo


func _assert_line_across(plan: Dictionary, facing: Vector3, what: String) -> void:
	assert_true((plan["heading"] as Vector3).dot(facing) > 0.999, "%s: the line looks the way he drew (heading %s)"
			% [what, plan["heading"]])
	var across := Vector3(-facing.z, 0.0, facing.x)
	assert_true(_extent_along(plan, across) > 3.0 * _extent_along(plan, facing) + 1.0,
			"%s: the line is laid across the facing (across %.1f m, along %.1f m)"
			% [what, _extent_along(plan, across), _extent_along(plan, facing)])


## Every hold order in the plan looks within `degrees` of `facing`.
func _assert_holds_look(plan: Dictionary, facing: Vector3, degrees: float, what: String) -> int:
	var holds := 0
	for unit_name: String in plan["orders"]:
		var order: Dictionary = plan["orders"][unit_name]
		if String(order["verb"]) != "hold":
			continue
		holds += 1
		assert_true(order.get("facing") is Vector3, "%s: %s's hold says which way to look" % [what, unit_name])
		if order.get("facing") is Vector3:
			assert_true(rad_to_deg((order["facing"] as Vector3).angle_to(facing)) <= degrees,
					"%s: %s looks within %.0f deg of the drawn facing (%s)" % [what, unit_name, degrees, order["facing"]])
	return holds


# ---- Screen ---------------------------------------------------------------------------------------------

func test_a_screen_with_a_facing_lays_its_line_across_it() -> void:
	var point := Vector3(0.0, 0.0, -60.0)
	# He drew east; the element comes to the point from the south (its own heading would be north).
	var task := {"verb": "screen", "to": [point.x, point.z], "facing": [1.0, 0.0]}
	var situation := _situation(point + Vector3(0.0, 0.0, 10.0))
	var plan := ElementPlan.build(situation, _state(task), _table())
	assert_eq(plan["formation"], "line", "a screen stands in a line")
	_assert_line_across(plan, EAST, "screen")
	var again := _settled(task, situation, plan)
	_assert_line_across(again, EAST, "screen, next update")
	assert_true(_assert_holds_look(again, EAST, 61.0, "screen, on the line") > 0, "crews on the line hold it")


func test_a_screen_without_a_facing_faces_the_way_it_came() -> void:
	var point := Vector3(0.0, 0.0, -60.0)
	var task := {"verb": "screen", "to": [point.x, point.z]}
	var situation := _situation(point + Vector3(0.0, 0.0, 10.0))
	var plan := ElementPlan.build(situation, _state(task), _table())
	var came := TacticsFormation.flat(point - (situation["center"] as Vector3))
	assert_true((plan["heading"] as Vector3).dot(came) > 0.999, "no facing: the screen looks the way it came (%s)"
			% plan["heading"])


# ---- Support by fire ------------------------------------------------------------------------------------

func test_support_by_fire_with_a_facing_looks_along_it_at_its_point() -> void:
	var point := Vector3(0.0, 0.0, -90.0)
	var task := {"verb": "support_by_fire", "to": [point.x, point.z], "facing": [1.0, 0.0]}
	var situation := _situation()
	var plan := ElementPlan.build(situation, _state(task), _table())
	assert_eq(plan["drill"], "support_by_fire", "the task is its own drill")
	_assert_line_across(plan, EAST, "support by fire")
	var anchor: Vector3 = plan["anchor"]
	assert_true(TacticsFormation.flat(point - anchor).dot(EAST) > 0.99,
			"the firing line stands off its point against the facing, so it looks along it AT the point (anchor %s)"
			% anchor)
	var again := _settled(task, situation, plan)
	_assert_line_across(again, EAST, "support by fire, next update")
	assert_true((again["anchor"] as Vector3).distance_to(anchor) < 0.5, "the firing line is kept")
	assert_true(_assert_holds_look(again, EAST, 61.0, "support by fire, on the line") > 0, "crews on the line hold it")


func test_support_by_fire_without_a_facing_stands_on_its_own_side() -> void:
	var point := Vector3(0.0, 0.0, -90.0)
	var task := {"verb": "support_by_fire", "to": [point.x, point.z]}
	var situation := _situation()
	var plan := ElementPlan.build(situation, _state(task), _table())
	var anchor: Vector3 = plan["anchor"]
	assert_true(TacticsFormation.flat(anchor - point).dot(TacticsFormation.flat(situation["center"] - point)) > 0.999,
			"no facing: the firing line is on the element's side of the point (anchor %s)" % anchor)
	assert_true((plan["heading"] as Vector3).dot(TacticsFormation.flat(point - anchor)) > 0.999,
			"no facing: it faces the point")


# ---- Ambush ---------------------------------------------------------------------------------------------

func test_an_ambush_with_a_facing_lies_looking_along_it() -> void:
	var zone := Vector3(0.0, 0.0, -90.0)
	var task := {"verb": "ambush", "to": [zone.x, zone.z], "facing": [1.0, 0.0]}
	var situation := _situation()
	var plan := ElementPlan.build(situation, _state(task), _table())
	assert_eq(plan["drill"], "ambush", "an ambush task lies in wait")
	_assert_line_across(plan, EAST, "ambush")
	assert_true(TacticsFormation.flat(zone - (plan["anchor"] as Vector3)).dot(EAST) > 0.99,
			"the ambush lies off the kill zone against the facing (anchor %s)" % plan["anchor"])
	var again := _settled(task, situation, plan)
	_assert_line_across(again, EAST, "ambush, next update")
	assert_true(_assert_holds_look(again, EAST, 61.0, "ambush, lying") > 0, "crews on the line hold it")


func test_an_ambush_from_a_spot_with_a_facing_lies_there_looking_along_it() -> void:
	var zone := Vector3(0.0, 0.0, -90.0)
	var from := Vector3(-40.0, 0.0, -60.0)
	var task := {"verb": "ambush", "to": [zone.x, zone.z], "from": [from.x, from.z], "facing": [1.0, 0.0]}
	var plan := ElementPlan.build(_situation(), _state(task), _table())
	assert_true((plan["anchor"] as Vector3).distance_to(from) < 0.5, "it lies where it was told to")
	_assert_line_across(plan, EAST, "ambush from a spot")


func test_an_ambush_without_a_facing_faces_its_kill_zone() -> void:
	var zone := Vector3(0.0, 0.0, -90.0)
	var task := {"verb": "ambush", "to": [zone.x, zone.z]}
	var situation := _situation()
	var plan := ElementPlan.build(situation, _state(task), _table())
	var anchor: Vector3 = plan["anchor"]
	assert_true(TacticsFormation.flat(anchor - zone).dot(TacticsFormation.flat(situation["center"] - zone)) > 0.999,
			"no facing: the ambush lies on the element's side of the kill zone (anchor %s)" % anchor)
	assert_true((plan["heading"] as Vector3).dot(TacticsFormation.flat(zone - anchor)) > 0.999,
			"no facing: it faces the kill zone")


# ---- Attack-move ----------------------------------------------------------------------------------------

func test_an_attack_move_with_a_facing_arrives_facing_it() -> void:
	var to := Vector3(0.0, 0.0, -60.0)
	var task := {"verb": "move", "to": [to.x, to.z], "facing": [1.0, 0.0]}
	assert_true(ElementTask.runs_drills(task), "an attack-move is a move with its drills on")
	# Arrived: the element's centre is on the spot.
	var plan := ElementPlan.build(_situation(to), _state(task), _table())
	assert_true(bool(plan["arrived"]), "the element is on its spot")
	assert_true((plan["heading"] as Vector3).dot(EAST) > 0.999, "it stands facing the way he drew (%s)" % plan["heading"])
	assert_eq(_assert_holds_look(plan, EAST, 1.0, "attack-move, arrived"), 4, "every crew holds the drawn heading")
	for unit_name: String in plan["sectors"]:
		assert_near(float(plan["sectors"][unit_name]), 0.0, 0.001, "%s has no all-round sector" % unit_name)
	assert_true(String(plan["why"]).contains("holding the heading you drew"), "the readout says so: %s" % plan["why"])


func test_an_attack_move_with_a_facing_on_the_way_is_unchanged_until_it_arrives() -> void:
	var to := Vector3(0.0, 0.0, -200.0)
	var faced := ElementPlan.build(_situation(), _state({"verb": "move", "to": [to.x, to.z], "facing": [1.0, 0.0]}),
			_table())
	var plain := ElementPlan.build(_situation(), _state({"verb": "move", "to": [to.x, to.z]}), _table())
	assert_eq(faced["orders"], plain["orders"], "on the way, the facing changes nobody's orders")
	assert_eq(faced["heading"], plain["heading"], "on the way, it travels the way it is going")


func test_an_attack_move_without_a_facing_halts_in_all_round_security() -> void:
	var to := Vector3(0.0, 0.0, -60.0)
	var plan := ElementPlan.build(_situation(to), _state({"verb": "move", "to": [to.x, to.z]}), _table())
	assert_true(bool(plan["arrived"]), "the element is on its spot")
	var directions := {}
	for unit_name: String in plan["orders"]:
		var facing: Variant = (plan["orders"][unit_name] as Dictionary).get("facing")
		if facing is Vector3:
			directions[Vector2(snappedf(facing.x, 0.01), snappedf(facing.z, 0.01))] = true
	assert_true(directions.size() > 1, "no facing: the halt watches more than one direction (%d)" % directions.size())


func test_a_cpu_hold_with_a_facing_is_untouched() -> void:
	# The CPU's holds carry a facing (ElementCommander, ArmyPlan) with their drills on: B0 is about his armed orders,
	# and a hold is not one of them. Its halt keeps the table's shape and sectors.
	var to := Vector3(0.0, 0.0, -60.0)
	var plan := ElementPlan.build(_situation(to), _state({"verb": "hold", "to": [to.x, to.z], "facing": [1.0, 0.0]}),
			_table())
	assert_true(not String(plan["why"]).contains("holding the heading you drew"), "a hold halts as before: %s"
			% plan["why"])
