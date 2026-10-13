extends TestCase
## Round 27, brains B0 (C27.3): an attack honours a drawn APPROACH.
##
## Orders' gesture (press on an enemy, drag, release) puts `task["approach"] = [x, z]` on the attack: the direction the
## squad drives IN, toward the target, so it comes from the target's side opposite to it. These tests hold the brains'
## half at the plan level:
##   - the key is an attack's only (every other verb refuses it), and must be a non-zero direction;
##   - an element already on that side plans exactly what it planned without the key (the CPU never carries one);
##   - an element on the wrong side drives ROUND the target at its guns' reach, a notch at a time, on a named move (guns
##     on the target, nobody stopping to fight from the wrong side), the shorter way, and keeps the way it chose;
##   - once round ("in"), it is an attack as before, for the life of the task.
## The live half (a real match) is test_tactics_approach_live.gd.

const TARGET := Vector3.ZERO
## Every member's effective range in _situation: the attack's band, and the radius it drives round at.
const BAND := 70.0
## Every member's weapon range in _situation: the radius it drives round at (its longest reach).
const RADIUS := 90.0


func teardown() -> void:
	ElementPlan.APPROACH_CARRY = true
	super.teardown()


func _table() -> DoctrineTable:
	DoctrineTable.clear_cache()
	var loaded := DoctrineTable.load_table("standard")
	assert_true(loaded.has("table"), "the standard table loads: %s" % loaded.get("error", ""))
	return loaded.get("table")


## Four tanks abreast round `center`, one enemy tank at TARGET, seen at 100 m: "likely", so no contact drill runs and
## the attack's movement plans (the band is 70 m).
func _situation(center: Vector3) -> Dictionary:
	var members: Array = []
	for i in 4:
		members.append({"name": "Green_%d" % (i + 1), "position": center + Vector3(i * 8.0 - 12.0, 0.0, 0.0),
				"forward": Vector3.FORWARD, "role": "tank", "unit": "tank", "speed": 9.0, "range": RADIUS,
				"effective_range": BAND, "sight": 140.0, "health": 1.0, "suppression": 0.0, "taking_fire": false})
	var listed := [{"name": "Rust_1", "position": TARGET, "role": "tank", "unit": "tank", "visible": true, "age": 200,
			"distance": TARGET.distance_to(center), "bearing_deg": 0.0, "strength": 200.0, "speed": 0.0}]
	return {"tick": 1000, "team": 0, "center": center, "heading": Vector3.FORWARD, "leader": "Green_1",
			"members": members, "contacts": listed, "terrain": "open",
			"threat": ElementSituation.threat_from(listed, false), "composition": "heavy", "strength": 800.0,
			"enemy_strength": 200.0, "taking_fire": false, "arrived": false}


func _state(task: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var state := {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "",
			"drill_why": "", "anchor": null, "bounding": 0, "arrived": false, "heading": Vector3.FORWARD, "seats": {}}
	state.merge(extra, true)
	return state


func _attack(approach: Variant = null) -> Dictionary:
	var task := {"verb": "attack", "target": "Rust_1"}
	if approach != null:
		task["approach"] = approach
	return task


## The element's centre `metres` from the target, `degrees` round from the side an approach `approach` comes from.
func _round(approach: Vector2, degrees: float, metres := 100.0) -> Vector3:
	var from := atan2(-approach.y, -approach.x) + deg_to_rad(degrees)
	return Vector3(cos(from), 0.0, sin(from)) * metres


func _without_approach_key(plan: Dictionary) -> Dictionary:
	var copy := plan.duplicate(true)
	copy.erase("approach_round")
	return copy


func test_only_an_attack_takes_an_approach() -> void:
	assert_eq(ElementTask.validate(_attack([0.0, -1.0])), "", "an attack takes an approach")
	assert_true(ElementTask.validate(_attack([0.0, 0.0])) != "", "a zero approach is refused")
	assert_true(ElementTask.validate(_attack([1.0])) != "", "a malformed approach is refused")
	for verb: String in ["move", "screen", "support_by_fire", "ambush", "hold"]:
		var task := {"verb": verb, "to": [10.0, 10.0], "approach": [1.0, 0.0]}
		assert_true(ElementTask.validate(task) != "", "%s refuses an approach (it is an attack's)" % verb)
	var approach: Variant = ElementTask.approach({"verb": "attack", "approach": [3.0, 4.0]})
	assert_true(approach is Vector3 and (approach as Vector3).is_equal_approx(Vector3(0.6, 0.0, 0.8)),
			"the approach is read as a flat unit direction (%s)" % approach)
	assert_eq(ElementTask.approach(_attack()), null, "no approach drawn: none")


func test_the_bearing_off_the_side_it_comes_from() -> void:
	var north := Vector3(0.0, 0.0, -1.0)  # driving north (-z) in: it comes from the south (+z)
	assert_near(ElementPlan.approach_off_deg(Vector3(0, 0, 80), TARGET, north), 0.0, 0.01, "south of it: on the side")
	assert_near(absf(ElementPlan.approach_off_deg(Vector3(0, 0, -80), TARGET, north)), 180.0, 0.01,
			"north of it: the far side")
	var east := ElementPlan.approach_off_deg(Vector3(80, 0, 0), TARGET, north)
	var west := ElementPlan.approach_off_deg(Vector3(-80, 0, 0), TARGET, north)
	assert_near(absf(east), 90.0, 0.01, "east of it: a quarter round")
	assert_near(east, -west, 0.01, "east and west are a quarter round either way")


func test_on_the_side_already_the_attack_is_unchanged() -> void:
	# B0's rule (round 28's B1 fights from the side once in: test_tactics_flank_carry).
	ElementPlan.APPROACH_CARRY = false
	var table := _table()
	var approach := Vector2(0.0, -1.0)
	for degrees: float in [0.0, 20.0, -25.0]:
		var situation := _situation(_round(approach, degrees))
		var with := ElementPlan.build(situation, _state(_attack([approach.x, approach.y])), table)
		var without := ElementPlan.build(situation, _state(_attack()), table)
		assert_true(bool((with.get("approach_round", {}) as Dictionary).get("in", false)),
				"%d deg round: it is on the side, so it goes in" % int(degrees))
		assert_eq(_without_approach_key(with), without, "%d deg round: the plan is the attack without an approach"
				% int(degrees))


func test_on_the_far_side_it_drives_round_at_its_guns_reach() -> void:
	var table := _table()
	var approach := Vector2(0.0, -1.0)
	var situation := _situation(_round(approach, 170.0))
	var plan := ElementPlan.build(situation, _state(_attack([approach.x, approach.y])), table)
	var kept: Dictionary = plan.get("approach_round", {})
	assert_true(not bool(kept.get("in", true)), "170 deg round: not in yet")
	assert_eq(int(kept.get("side", 0)), 1, "it goes round the shorter way (the side it is on)")
	var anchor: Vector3 = plan["anchor"]
	assert_near(anchor.distance_to(TARGET), RADIUS, 0.5, "it drives to a point at its guns' longest reach (%s)" % anchor)
	var off := ElementPlan.approach_off_deg(anchor, TARGET, Vector3(approach.x, 0.0, approach.y))
	assert_near(off, 135.0, 0.5, "the next notch round toward the side drawn (%.1f deg)" % off)
	assert_true(not bool(plan["arrived"]), "going round is not arriving")
	assert_eq((plan["orders"] as Dictionary).size(), 4, "every crew is sent")
	for unit_name: String in plan["orders"]:
		var order: Dictionary = plan["orders"][unit_name]
		assert_eq(String(order["verb"]), "move", "%s drives round (a named move, not an attack-move that stops)" % unit_name)
		assert_eq(String(order["target"]), "Rust_1", "%s keeps its gun on the target on the way" % unit_name)
	for unit_name: String in plan["slots"]:
		var slot: Vector3 = plan["slots"][unit_name]
		assert_true(slot.distance_to(TARGET) > BAND * 0.6, "%s is not sent through the target (%.1f m)"
				% [unit_name, slot.distance_to(TARGET)])
	var plain := ElementPlan.build(situation, _state(_attack()), table)
	var straight := TacticsFormation.flat(TARGET - (situation["center"] as Vector3))
	assert_true((plain["heading"] as Vector3).dot(straight) > 0.99,
			"control: without an approach the same element drives straight at it (%s)" % plain["heading"])
	assert_true((plan["heading"] as Vector3).dot(straight) < 0.9,
			"with one it does not (%s)" % plan["heading"])


func test_each_notch_comes_round_toward_the_side() -> void:
	var table := _table()
	var approach := Vector2(1.0, 0.0)  # driving east in: from the west
	var expected := {100.0: 45.0, 80.0: 45.0, 55.0: 0.0, 40.0: 0.0, -100.0: -45.0, -70.0: -45.0, -59.0: 0.0}
	for degrees: float in expected:
		var plan := ElementPlan.build(_situation(_round(approach, degrees)), _state(_attack([approach.x, approach.y])),
				table)
		var off := ElementPlan.approach_off_deg(plan["anchor"], TARGET, Vector3(approach.x, 0.0, approach.y))
		assert_near(off, float(expected[degrees]), 0.5, "from %d deg round: the notch at %d (%.1f)"
				% [int(degrees), int(expected[degrees]), off])


func test_the_way_round_is_kept() -> void:
	var table := _table()
	var approach := Vector2(0.0, -1.0)
	# Chosen the negative way round earlier; carried across the far side to +100: it carries on the same way, through
	# the far side, rather than turning back.
	var plan := ElementPlan.build(_situation(_round(approach, 100.0)),
			_state(_attack([approach.x, approach.y]), {"approach_round": {"in": false, "side": -1}}), table)
	assert_eq(int((plan["approach_round"] as Dictionary).get("side", 0)), -1, "the side is kept")
	var off := ElementPlan.approach_off_deg(plan["anchor"], TARGET, Vector3(approach.x, 0.0, approach.y))
	assert_near(off, 135.0, 0.5, "the next notch on the way it chose (%.1f deg)" % off)


func test_once_in_it_attacks_as_before() -> void:
	# B0's rule (round 28's B1 fights from the side once in: test_tactics_flank_carry).
	ElementPlan.APPROACH_CARRY = false
	var table := _table()
	var approach := Vector2(0.0, -1.0)
	# The fight swung it round to the far side after it went in: it does not drive round again.
	var situation := _situation(_round(approach, 160.0))
	var plan := ElementPlan.build(situation,
			_state(_attack([approach.x, approach.y]), {"approach_round": {"in": true, "side": 1}}), table)
	var plain := ElementPlan.build(situation, _state(_attack()), table)
	assert_eq(_without_approach_key(plan), plain, "in: the plan is the attack without an approach")
	assert_true(bool((plan["approach_round"] as Dictionary).get("in", false)), "it stays in")


func test_in_reach_on_the_side_it_forms_the_line_as_before() -> void:
	# B0's rule (round 28's B1 fights from the side once in: test_tactics_flank_carry).
	ElementPlan.APPROACH_CARRY = false
	var table := _table()
	var approach := Vector2(0.0, -1.0)
	var situation := _situation(_round(approach, 10.0, 60.0))
	situation["threat"] = "likely"
	var plan := ElementPlan.build(situation, _state(_attack([approach.x, approach.y])), table)
	assert_eq(String(plan["formation"]), "line", "in reach: the attack's line")
	assert_eq(_without_approach_key(plan), ElementPlan.build(situation, _state(_attack()), table),
			"the same line as without an approach")


func test_a_running_target_is_a_pursuit_and_has_no_side() -> void:
	var table := _table()
	var approach := Vector2(0.0, -1.0)
	var situation := _situation(_round(approach, 170.0))
	# Round 28 (B1): "running" going round is >= 6 m/s held 2 s (ElementPlan.APPROACH_RUNNING_*).
	var extra := {"pursuing": true, "pursuit": {"name": "Rust_1", "position": TARGET, "velocity": Vector3(7, 0, 0),
			"seen_tick": 1000}}
	var running := {"approach_round": {"in": false, "side": 1, "fast_since": 1000 - 2 * SimClock.TICK_RATE}}
	running.merge(extra)
	var plan := ElementPlan.build(situation, _state(_attack([approach.x, approach.y]), running), table)
	assert_true(bool(plan["pursuing"]), "a running target is a pursuit")
	var chase := plan.duplicate(true)
	chase.erase("approach_round")
	assert_eq(chase, ElementPlan.build(situation, _state(_attack(), extra), table), "the chase as without an approach")
