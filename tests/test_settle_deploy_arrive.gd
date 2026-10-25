extends TestCase
## Round 40 (settle T1; orders' G1 v5 trace, builder0 e7c896c8f, terminus his-5 click): A CREW HOLDING NEAR ITS SEAT COUNTS AS
## IN (ElementPlan.DEPLOY_ARRIVE_NEAR, `--deploy-arrive=near`). Pure: an AUTO plain move driven to its spot as the element
## carries state (test_tactics_deploy_step's drive), every crew on its travel seat but one. Bravo_2's case: that one HOLDS
## 3.83 m off (outside the 3.5 m all-in radius): main waits for the cap; near deploys once it has held DEPLOY_NEAR_HOLD_TICKS.
## A crew still rolling at 4 m, or holding 6 m out, does not count. Tracked crews (settle radius 0: the 3.5 m radius reads).

var _near := ElementPlan.DEPLOY_ARRIVE_NEAR
var _step := ElementPlan.DEPLOY_STEP


func teardown() -> void:
	ElementPlan.DEPLOY_ARRIVE_NEAR = _near
	ElementPlan.DEPLOY_STEP = _step
	super.teardown()


static func _crew(n: String, at: Vector3, holding: bool) -> Dictionary:
	return {"name": n, "unit": "tank", "role": "tank", "speed": 9.0, "range": 60.0, "effective_range": 45.0, "sight": 60.0,
			"health": 1.0, "suppression": 0.0, "taking_fire": false, "forward": Vector3.FORWARD, "position": at,
			"holding": holding}


func _situation(members: Array, tick: int) -> Dictionary:
	var center := Vector3.ZERO
	for m: Dictionary in members:
		center += m["position"] as Vector3
	center /= float(members.size())
	return {"tick": tick, "team": 0, "center": center, "heading": Vector3.FORWARD, "leader": String(members[0]["name"]),
			"members": members, "contacts": [], "terrain": "open", "threat": "none", "composition": "heavy",
			"strength": 800.0, "enemy_strength": 0.0, "taking_fire": false, "arrived": false}


## Drives to the spot, then `updates` plans `every` ticks apart with every crew on its travel seat except Green_S_2, `off` m
## east of its seat and `holding` (the others hold on their seats). Returns the last plan's deploy.
func _drive(near: bool, off: float, holding: bool, updates: int, every: int) -> Dictionary:
	ElementPlan.DEPLOY_STEP = true
	ElementPlan.DEPLOY_ARRIVE_NEAR = near
	DoctrineTable.clear_cache()
	var table: DoctrineTable = DoctrineTable.load_table("standard")["table"]
	var destination := Vector3(0, 0, -60)
	var task := {"verb": "move", "to": [destination.x, destination.z], "drills": false, "lay": [1.0, 0.0]}
	var state := {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "", "drill_why": "",
			"anchor": null, "bounding": 0, "arrived": false, "heading": Vector3.FORWARD, "seats": {}, "arrived_tick": -1,
			"deploy": {}, "issued_slots": {}}
	var members: Array = []
	for i in 4:
		members.append(_crew("Green_S_%d" % (i + 1), Vector3(30 + (i - 1.5) * 8.0, 0, 40), false))
	var plan := ElementPlan.build(_situation(members, 100), state, table)
	var tick := 200
	var travel := {}
	for step in updates:
		state["deploy"] = plan.get("deploy", {})
		if not bool((state["deploy"] as Dictionary).get("deployed", false)):
			state["issued_slots"] = plan["slots"]
			travel = plan["slots"]
		state["formation"] = plan["formation"]
		state["seats"] = plan["seats"]
		state["anchor"] = plan["anchor"]
		state["heading"] = plan["heading"]
		state["arrived"] = bool(plan["arrived"])
		if state["arrived"] and int(state["arrived_tick"]) < 0:
			state["arrived_tick"] = tick
		var on_seats: Array = []
		for n: String in travel:
			var short := n == "Green_S_2"
			on_seats.append(_crew(n, (travel[n] as Vector3) + (Vector3(off, 0, 0) if short else Vector3.ZERO),
					holding if short else true))
		plan = ElementPlan.build(_situation(on_seats, tick), state, table)
		tick += every
	return plan.get("deploy", {})


func test_a_crew_holding_3_83_m_off_its_seat_counts_as_in() -> void:
	var main := _drive(false, 3.83, true, 4, 30)
	var near := _drive(true, 3.83, true, 4, 30)
	print("MEASURE deploy arrive: Bravo_2's 3.83 m hold, main deployed %s, near deployed %s (cause %s, near %d)" % [
			main.get("deployed", false), near.get("deployed", false), near.get("cause", ""), int(near.get("near", 0))])
	assert_true(not bool(main.get("deployed", false)), "counter: main waits for the cap (3.83 m > 3.5 m)")
	assert_true(bool(near.get("deployed", false)), "near: the holding crew counts as in")
	assert_eq(String(near.get("cause", "")), "all_in", "deployed all in, not on the cap")
	assert_eq(int(near.get("near", 0)), 1, "one crew counted near")
	assert_true(not near.has("still"), "the hold clocks are dropped once deployed")


func test_a_crew_still_rolling_at_4_m_does_not_count() -> void:
	var rolling := _drive(true, 4.0, false, 4, 30)
	assert_true(not bool(rolling.get("deployed", false)), "a crew still driving at 4 m is not in")


func test_a_crew_holding_6_m_off_does_not_count() -> void:
	var far := _drive(true, 6.0, true, 4, 30)
	assert_true(not bool(far.get("deployed", false)), "holding beyond DEPLOY_NEAR_M is not in")


func test_a_hold_shorter_than_the_window_does_not_count_yet() -> void:
	# Updates 3 ticks apart (the element's UPDATE_TICKS): the crew must hold DEPLOY_NEAR_HOLD_TICKS without a break.
	var updates_in_window := ElementPlan.DEPLOY_NEAR_HOLD_TICKS / 3
	var brief := _drive(true, 3.83, true, updates_in_window, 3)
	var held := _drive(true, 3.83, true, updates_in_window + 3, 3)
	assert_true(not bool(brief.get("deployed", false)), "held under the window: not yet in")
	assert_true(bool(held.get("deployed", false)), "held through the window: in")


func test_off_by_default() -> void:
	assert_true(not ElementPlan.DEPLOY_ARRIVE_NEAR or OS.get_cmdline_user_args().has("--deploy-arrive=near")
			or OS.get_environment("DEPLOY_ARRIVE") == "near", "OFF until its bar passes")
