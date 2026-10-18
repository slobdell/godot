extends TestCase
## R33.35 (brains; manoeuvre's CP-F trace): THE HERRINGBONE HALT LAYS ON A HEADING THAT HOLDS. `_plan_drill`'s herringbone
## laid its seats on plan["heading"] = the members' hull forwards AVERAGED (ElementSituation), every update. As the hulls
## turned to their seats the shape re-laid rotated, the seats jumped 5-27 m and the crews were re-sent, which turned them
## again (gangs faced_attack_move s41, builder0: Guns' late drifts 12 v 103 with CP-F's turns; the Hunters swarm
## 1,046 seat moves after arrival in BOTH arms, anchor fixed, laying heading swinging 90 deg and more in seconds). Now it
## lays on the task's drawn facing when there is one, else on the heading it was first laid on while it stays in the
## herringbone. `--herring-heading=off` is main's rule.


func teardown() -> void:
	ElementPlan.HERRING_HEADING = true
	DoctrineTable.clear_cache()
	super.teardown()


func _table() -> DoctrineTable:
	DoctrineTable.clear_cache()
	return DoctrineTable.load_table("gangs")["table"]


## Four crews halted round the origin, their hulls pointing `forward` (the situation's averaged heading).
func _situation(forward: Vector3) -> Dictionary:
	var members: Array = []
	for i in 4:
		members.append({"name": "Hunters_%d" % (i + 1), "position": Vector3(i * 8.0 - 12.0, 0, 0), "forward": forward,
				"role": "ifv", "unit": "gang_ifv", "speed": 11.0, "range": 60.0, "effective_range": 45.0, "sight": 60.0,
				"health": 1.0, "suppression": 0.0, "taking_fire": false})
	return {"tick": 1000, "team": 0, "center": Vector3.ZERO, "heading": forward, "leader": "Hunters_1",
			"members": members, "contacts": [], "terrain": "open", "threat": "none", "composition": "medium",
			"strength": 800.0, "enemy_strength": 0.0, "taking_fire": false, "arrived": true}


func _plan(situation: Dictionary) -> Dictionary:
	return {"heading": situation["heading"], "formation": "swarm", "technique": "traveling", "why": "", "anchor": null,
			"slots": {}, "sectors": {}, "seats": {}, "orders": {}, "previous_seats": {}, "leader": "Hunters_1"}


func _herring(situation: Dictionary, state: Dictionary) -> Dictionary:
	var plan := _plan(situation)
	ElementPlan._plan_drill(plan, situation, state, _table(), {"drill": "herringbone", "why": "halted"})
	return plan


func _state(extra: Dictionary = {}) -> Dictionary:
	var state := {"task": {"verb": "move", "to": [0.0, 0.0]}, "drill": "", "arrived": true, "anchor": Vector3.ZERO,
			"halt_at": Vector3.ZERO, "heading": Vector3.FORWARD, "seats": {}}
	state.merge(extra, true)
	return state


func test_a_drawn_facing_lays_the_herringbone_whatever_the_hulls_point() -> void:
	var east := Vector3(1, 0, 0)
	var state := _state({"task": {"verb": "move", "to": [0.0, 0.0], "facing": [1.0, 0.0]}})
	var a := _herring(_situation(Vector3.FORWARD), state)
	var b := _herring(_situation(Vector3(0.0, 0, 1.0)), state)
	assert_true((a["heading"] as Vector3).is_equal_approx(east), "laid on the drawn facing (%s)" % a["heading"])
	assert_eq(a["slots"], b["slots"], "the hulls turning does not move a seat")


func test_in_the_herringbone_it_keeps_the_heading_it_was_laid_on() -> void:
	var kept := Vector3(0, 0, -1)
	var state := _state({"drill": "herringbone", "heading": kept})
	var a := _herring(_situation(Vector3(0.77, 0, -0.64).normalized()), state)
	var b := _herring(_situation(Vector3(-0.99, 0, -0.16).normalized()), state)
	assert_true((a["heading"] as Vector3).is_equal_approx(kept), "the kept heading (%s)" % a["heading"])
	assert_eq(a["slots"], b["slots"], "the averaged hull heading swinging 90+ degrees moves no seat")


func test_entering_the_herringbone_it_lays_on_the_current_heading() -> void:
	var now := Vector3(0.77, 0, -0.64).normalized()
	var a := _herring(_situation(now), _state({"drill": "", "heading": Vector3.FORWARD}))
	assert_true((a["heading"] as Vector3).is_equal_approx(TacticsFormation.flat(now)), "first laid on the heading now (%s)" % a["heading"])


func test_the_switch_off_is_mains_rule() -> void:
	ElementPlan.HERRING_HEADING = false
	var state := _state({"drill": "herringbone", "heading": Vector3(0, 0, -1)})
	var a := _herring(_situation(Vector3(0.77, 0, -0.64).normalized()), state)
	var b := _herring(_situation(Vector3(-0.99, 0, -0.16).normalized()), state)
	assert_true(a["slots"] != b["slots"], "--herring-heading=off: the shape re-lays on the averaged hulls")
