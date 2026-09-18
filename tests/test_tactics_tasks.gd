extends TestCase
## Round 6, squad X5 (N4): every task does what its name says, asserted as the POSTURE a player would see, on the
## leader's pure plan (ElementPlan.build). Before round 6 a support-by-fire task with nobody in sight told every crew
## to hold where it stood — the lead pressed the button and "the units definitely did not form up" — and with contact
## the react-to-contact and far-ambush drills outranked it and took the element forward and round a flank.


func _table(faction := "standard") -> DoctrineTable:
	DoctrineTable.clear_cache()
	var loaded := DoctrineTable.load_table(faction)
	assert_true(loaded.has("table"), "the %s table loads: %s" % [faction, loaded.get("error", "")])
	return loaded.get("table")


## Four tanks abreast around `center`, and the listed contacts.
func _situation(contacts: Array, center := Vector3.ZERO, extra: Dictionary = {}) -> Dictionary:
	var members: Array = []
	for i in 4:
		members.append({"name": "Green_%d" % (i + 1), "position": center + Vector3(i * 10.0 - 15.0, 0.0, 0.0),
				"forward": Vector3.FORWARD, "role": "tank", "unit": "tank", "speed": 9.0, "range": 90.0,
				"effective_range": 70.0, "sight": 90.0, "health": 1.0, "suppression": 0.0, "taking_fire": false})
	var listed: Array = []
	for contact: Dictionary in contacts:
		var position: Vector3 = contact["position"]
		listed.append({"name": String(contact.get("name", "Rust_1")), "position": position, "role": "tank",
				"unit": "tank", "visible": true, "age": int(contact.get("age", 200)),
				"distance": position.distance_to(center), "bearing_deg": 0.0, "strength": 200.0, "speed": 0.0})
	var situation := {"tick": int(extra.get("tick", 1000)), "team": 0, "center": center, "heading": Vector3.FORWARD,
			"leader": "Green_1", "members": members, "contacts": listed, "terrain": "open",
			"threat": ElementSituation.threat_from(listed, false), "composition": "heavy", "strength": 800.0,
			"enemy_strength": 200.0 * listed.size(), "taking_fire": false, "arrived": false}
	return situation


func _state(task: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var state := {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "",
			"drill_why": "", "anchor": null, "bounding": 0, "arrived": false, "heading": Vector3.FORWARD, "seats": {}}
	state.merge(extra, true)
	return state


## The state the element carries into its next update (what Element._take keeps).
static func _carry(state: Dictionary, plan: Dictionary) -> Dictionary:
	var next := state.duplicate()
	for key in ["anchor", "heading", "bounding", "arrived", "seats"]:
		next[key] = plan[key]
	next["drill"] = plan["drill"]
	return next


func _assert_firing_line(plan: Dictionary, point: Vector3, standoff: float, why: String) -> void:
	assert_eq(plan["formation"], "line", "%s: a line" % why)
	var slots: Dictionary = plan["slots"]
	assert_eq(slots.size(), 4, "%s: every crew has a firing position" % why)
	var axis := TacticsFormation.flat(point - (plan["anchor"] as Vector3))
	for unit: String in slots:
		var spot: Vector3 = slots[unit]
		var range_to := spot.distance_to(point)
		assert_true(range_to <= 70.0, "%s: %s's position is in effective range of the point (%.0f m)" % [why, unit, range_to])
		assert_true(range_to >= standoff - 12.0, "%s: %s stands off, not on top of it (%.0f m)" % [why, unit, range_to])
		var order: Dictionary = plan["orders"][unit]
		assert_true(String(order["verb"]) in ["move", "hold"], "%s: %s goes to its place, it does not attack-move (%s)"
				% [why, unit, order["verb"]])
		assert_true(absf(float(plan["sectors"][unit])) <= 45.0, "%s: %s's sector faces the point" % [why, unit])
	# Abreast: every position the same distance along the axis to the point (within the halt's face lead).
	var along: Array = slots.values().map(func(spot: Vector3) -> float: return (spot - (plan["anchor"] as Vector3)).dot(axis))
	assert_true(along.max() - along.min() <= 2.0 * ElementPlan.FACE_LEAD, "%s: abreast (%s)" % [why, along])


func test_support_by_fire_takes_a_firing_line_with_nobody_in_sight() -> void:
	var table := _table()
	var point := Vector3(0, 0, -110)
	var state := _state({"verb": "support_by_fire", "to": [point.x, point.z]})
	var plan := ElementPlan.build(_situation([]), state, table)
	assert_eq(plan["drill"], "support_by_fire", "the task is the drill")
	_assert_firing_line(plan, point, 70.0 * ElementPlan.SBF_STANDOFF, "no contact")
	for unit: String in plan["orders"]:
		assert_eq(plan["orders"][unit]["verb"], "move", "%s is 50+ m from its place: it drives there" % unit)


func test_support_by_fire_holds_its_line_under_contact_and_never_advances() -> void:
	var table := _table()
	var point := Vector3(0, 0, -110)
	var task := {"verb": "support_by_fire", "to": [point.x, point.z]}
	var enemy := [{"name": "Rust_1", "position": Vector3(10, 0, -100)}]
	var plan := ElementPlan.build(_situation(enemy), _state(task), table)
	assert_eq(plan["drill"], "support_by_fire", "contact does not turn a base of fire into react-to-contact")
	_assert_firing_line(plan, point, 56.0, "under contact")
	# Next update the element has driven 40 m toward its line: the line stays where it was chosen.
	var later := ElementPlan.build(_situation(enemy, Vector3(0, 0, -40)), _carry(_state(task), plan), table)
	assert_eq(later["drill"], "support_by_fire", "still the base of fire")
	assert_true((later["anchor"] as Vector3).is_equal_approx(plan["anchor"]), "the firing line does not creep forward")
	# On the line: every crew holds its spot.
	var anchor: Vector3 = plan["anchor"]
	var arrived := _situation(enemy, anchor)
	for member: Dictionary in arrived["members"]:
		member["position"] = later["slots"][member["name"]]  # every crew standing on its firing position
	var on_line := ElementPlan.build(arrived, _carry(_state(task), later), table)
	var holding := 0
	for unit: String in on_line["orders"]:
		if on_line["orders"][unit]["verb"] == "hold":
			holding += 1
	assert_eq(holding, 4, "crews on their positions hold them (%d of 4)" % holding)


func test_a_screen_stands_across_the_point() -> void:
	var table := _table()
	var point := Vector3(0, 0, -100)
	var task := {"verb": "screen", "to": [point.x, point.z]}
	var enemy := [{"name": "Rust_1", "position": Vector3(0, 0, -170)}]
	var near := ElementPlan.build(_situation(enemy, Vector3(0, 0, -85)), _state(task), table)
	assert_eq(near["drill"], "", "a screen on its line runs no drill that would take it forward")
	assert_eq(near["formation"], "line", "a line")
	for unit: String in near["slots"]:
		var spot: Vector3 = near["slots"][unit]
		assert_true(absf(spot.z - point.z) <= ElementPlan.FACE_LEAD + 0.5, "%s is ON the screen line (z %.1f)" % [unit, spot.z])
	var xs: Array = near["slots"].values().map(func(spot: Vector3) -> float: return spot.x)
	assert_true(xs.max() - xs.min() >= 3.0 * table.spacing("open"), "the screen is wide (%.0f m)" % (xs.max() - xs.min()))


func test_a_move_halts_on_the_spot_it_was_sent_to_and_stays() -> void:
	var table := _table()
	var task := {"verb": "move", "to": [0, -100]}
	var arriving := ElementPlan.build(_situation([], Vector3(6, 0, -92)), _state(task), table)
	assert_true(bool(arriving["arrived"]), "within the arrive radius")
	assert_true((arriving["anchor"] as Vector3).is_equal_approx(Vector3(0, 0, -100)),
			"the halt stands on the ordered spot, not on the element's centre (%s)" % arriving["anchor"])
	var state := _carry(_state(task), arriving)
	var later := ElementPlan.build(_situation([], Vector3(3, 0, -97)), state, table)
	assert_true((later["anchor"] as Vector3).is_equal_approx(arriving["anchor"]), "and it does not creep")
	assert_eq((later["seats"] as Dictionary).size(), 4, "every crew keeps a seat")


func test_a_plain_move_runs_no_drill_even_under_fire() -> void:
	# The player's right-click (X4): go there formed up; crews shoot what they pass, the leader does not divert.
	var table := _table()
	var task := {"verb": "move", "to": [0, -100], "drills": false}
	assert_eq(ElementTask.validate(task), "", "a plain move is a valid task")
	assert_true(ElementTask.validate({"verb": "move", "to": [0, 0], "drills": "no"}) != "", "drills is a boolean")
	var enemy := [{"name": "Rust_1", "position": Vector3(20, 0, -60), "age": 0}]
	var plan := ElementPlan.build(_situation(enemy), _state(task), table)
	assert_eq(plan["drill"], "", "no react to contact, no ambush drill")
	for unit: String in plan["orders"]:
		assert_eq(plan["orders"][unit]["verb"], "move", "%s keeps driving to its slot" % unit)
	var with_drills := ElementPlan.build(_situation(enemy), _state({"verb": "move", "to": [0, -100]}), table)
	assert_true(with_drills["drill"] != "", "the same contact on an attack-move task does start a drill (%s)" % with_drills["drill"])


func test_closing_up_is_judged_in_time_not_metres() -> void:
	# X3: cohesion by the form-up estimate. Slots of a two-vehicle line at the origin, 12 m apart.
	var table := _table()
	var spots := TacticsFormation.place([{"name": "A", "position": Vector3(-6, 0, 0)}, {"name": "B", "position": Vector3(6, 0, 0)}],
			"line", Vector3.ZERO, Vector3.FORWARD, 12.0)
	var slot_of := {}
	for entry in spots:
		slot_of[entry["unit"]] = entry["to"]
	var allowed_m := table.leg("cohesion_m")
	var tank := {"name": "A", "position": (slot_of["A"] as Vector3) + Vector3(0, 0, 2), "speed": 8.0}
	var far_scout := {"name": "B", "position": (slot_of["B"] as Vector3) + Vector3(0, 0, allowed_m * 1.5), "speed": 16.0}
	assert_true(ElementPlan._cohesive([tank, far_scout], Vector3.ZERO, "line", Vector3.FORWARD, 12.0, table),
			"a scout twice the tank's speed %.0f m out is as closed up as the tank would be at %.0f m" % [allowed_m * 1.5, allowed_m * 0.75])
	var far_tank := {"name": "A", "position": (slot_of["A"] as Vector3) + Vector3(0, 0, allowed_m * 1.5), "speed": 8.0}
	assert_true(not ElementPlan._cohesive([far_tank, far_scout], Vector3.ZERO, "line", Vector3.FORWARD, 12.0, table),
			"the slow vehicle that far out holds the element up")


func test_the_feed_carries_each_units_form_up_pace() -> void:
	var fake := FakeElement.new({"id": 1, "leader": "A", "members": ["A", "B"], "pace": {"A": 0.5}})
	assert_near(float(ElementFeed.normalize(fake, "A")["pace"]), 0.5, 1e-6, "A slows to half speed to arrive with B")
	assert_near(float(ElementFeed.normalize(fake, "B")["pace"]), 1.0, 1e-6, "B, the laggard, drives flat out")


class FakeElement extends RefCounted:
	var value := {}

	func _init(p_state: Dictionary) -> void:
		value = p_state

	func state() -> Dictionary:
		return value
