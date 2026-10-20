extends TestCase
## Round 35 (brains E1, C35.7 / R35.3): THE LEG GATE DOES NOT WAIT FOR A CREW THAT HAS STOPPED CLOSING. Traced (lab/cpf4
## e76f6dab6, law/faced_attack_move-614, laptop, both arms): an attack-move element stood at its anchor from t 37 to past the
## 75 s judge because one crew, wedged 30 m off its slot (plant 9.25 m/s, real 1.17), kept `_cohesive` false; every other crew
## had closed up. ElementPlan._advance now judges closed-up without a crew that has not come STRAGGLER_GAIN_M closer to its
## slot in STRAGGLER_S while the element stands at its anchor (plan["leg_wait"], kept by the Element between updates).

const HEADING := Vector3.FORWARD
const ANCHOR := Vector3(0.0, 0.0, -40.0)
const DESTINATION := Vector3(0.0, 0.0, -200.0)


func teardown() -> void:
	ElementPlan.STRAGGLER_RELEASE = true
	super.teardown()


## Four tanks: three standing in their wedge slots at ANCHOR, the fourth `off` metres behind its own.
func _members(off: float) -> Array:
	var members: Array = []
	for i in 4:
		members.append({"name": "T%d" % i, "position": Vector3.ZERO, "role": "tank", "unit": "law_tank", "speed": 9.0})
	var opts := {"policy": "exposure", "corridor_m": INF, "leader": "", "previous": {}}
	for entry in TacticsFormation.place(members, "wedge", ANCHOR, HEADING, TacticsFormation.DEFAULT_SPACING, opts):
		for member: Dictionary in members:
			if String(member["name"]) == String(entry["unit"]):
				member["position"] = entry["to"]
	members[3]["position"] = (members[3]["position"] as Vector3) - HEADING * off
	return members


## One `_advance` at `tick` with the element's anchor at ANCHOR and `leg_wait` from the update before; returns the plan.
func _step(members: Array, tick: int, leg_wait: Dictionary) -> Dictionary:
	var plan := {"technique": "traveling", "formation": "wedge"}
	var situation := {"tick": tick, "members": members}
	var state := {"anchor": ANCHOR, "leg_wait": leg_wait}
	var center := Vector3.ZERO
	for member: Dictionary in members:
		center += member["position"]
	center /= members.size()
	ElementPlan._advance(plan, situation, state, DoctrineTable.for_faction("law"), center, DESTINATION, HEADING, members,
			TacticsFormation.DEFAULT_SPACING)
	return plan


func test_a_crew_that_stopped_closing_no_longer_holds_the_leg() -> void:
	var members := _members(30.0)
	var plan := _step(members, 0, {})
	assert_eq(plan["anchor"], ANCHOR, "a crew 30 m off its slot holds the step at first")
	var waited := plan
	for second in range(1, 12):
		waited = _step(members, second * SimClock.TICK_RATE, waited.get("leg_wait", {}))
		if waited["anchor"] != ANCHOR:
			break
	assert_true(waited["anchor"] != ANCHOR, "after STRAGGLER_S without closing it no longer holds the leg")
	assert_true(int(waited.get("leg_wait", {}).get("released", 0)) == 1, "the release is counted once (%s)" % waited.get("leg_wait"))


func test_a_crew_still_closing_holds_the_leg() -> void:
	var waited := {}
	for second in 12:
		# 30 m off, coming 1 m closer every second (8 m in STRAGGLER_S, over STRAGGLER_GAIN_M): it is on its way.
		var plan := _step(_members(30.0 - float(second)), second * SimClock.TICK_RATE, waited.get("leg_wait", {}))
		assert_eq(plan["anchor"], ANCHOR, "a crew closing on its slot holds the step (t %d s)" % second)
		waited = plan


func test_the_switch_off_is_mains_gate() -> void:
	ElementPlan.STRAGGLER_RELEASE = false
	var members := _members(30.0)
	var waited := {}
	for second in 20:
		var plan := _step(members, second * SimClock.TICK_RATE, waited.get("leg_wait", {}))
		assert_eq(plan["anchor"], ANCHOR, "--straggler=off waits for every crew (t %d s)" % second)
		waited = plan


func test_a_new_anchor_restarts_the_clock() -> void:
	var members := _members(30.0)
	var stale := {"anchor": ANCHOR + HEADING * 45.0, "since": {"T3": [30.0, 0]}}
	var plan := _step(members, 20 * SimClock.TICK_RATE, stale)
	assert_eq(plan["anchor"], ANCHOR, "a clock kept for another anchor does not release anyone")


func test_closed_up_crews_step_at_once() -> void:
	var plan := _step(_members(0.0), 0, {})
	assert_true(plan["anchor"] != ANCHOR, "an element standing in its slots takes the next leg on the first update")
