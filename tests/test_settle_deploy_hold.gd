extends TestCase
## Round 38 (settle, the stretch; S3's laptop trace): A PARKED SQUAD THAT LOSES A CREW DOES NOT RE-DEAL ITS SURVIVORS
## (ElementPlan.DEPLOY_HOLD). Pure: an AUTO plain move driven to its deploy as the element carries state
## (test_tactics_deploy_step's drive), then planned again with one crew gone and the others on their seats. Off, the halt is
## laid again at the smaller size and survivors' seats move (the counter); held, every survivor keeps its seat.

var _hold := ElementPlan.DEPLOY_HOLD
var _step := ElementPlan.DEPLOY_STEP


func teardown() -> void:
	ElementPlan.DEPLOY_HOLD = _hold
	ElementPlan.DEPLOY_STEP = _step
	super.teardown()


static func _crew(n: String, at: Vector3) -> Dictionary:
	return {"name": n, "unit": "law_tank", "role": "tank", "speed": 9.0, "range": 60.0, "effective_range": 45.0, "sight": 60.0,
			"health": 1.0, "suppression": 0.0, "taking_fire": false, "forward": Vector3.FORWARD, "position": at}


func _situation(members: Array, tick: int) -> Dictionary:
	var center := Vector3.ZERO
	for m: Dictionary in members:
		center += m["position"] as Vector3
	center /= float(members.size())
	return {"tick": tick, "team": 0, "center": center, "heading": Vector3.FORWARD, "leader": String(members[0]["name"]),
			"members": members, "contacts": [], "terrain": "open", "threat": "none", "composition": "heavy",
			"strength": 800.0, "enemy_strength": 0.0, "taking_fire": false, "arrived": false}


## The slots of the plan after the deploy and of the next plan with `lost` gone (survivors on their seats).
func _lose_one(hold: bool, lost: String) -> Array:
	ElementPlan.DEPLOY_STEP = true
	ElementPlan.DEPLOY_HOLD = hold
	DoctrineTable.clear_cache()
	var table: DoctrineTable = DoctrineTable.load_table("standard")["table"]
	var destination := Vector3(0, 0, -60)
	var task := {"verb": "move", "to": [destination.x, destination.z], "drills": false, "lay": [1.0, 0.0]}
	var state := {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "", "drill_why": "",
			"anchor": null, "bounding": 0, "arrived": false, "heading": Vector3.FORWARD, "seats": {}, "arrived_tick": -1,
			"deploy": {}, "issued_slots": {}}
	var members: Array = []
	for i in 5:
		members.append(_crew("Green_S_%d" % (i + 1), Vector3(30 + (i - 2) * 8.0, 0, 40)))
	var plans := [ElementPlan.build(_situation(members, 100), state, table)]
	var tick := 200
	for step in 5:
		state["deploy"] = plans[-1].get("deploy", {})
		state["issued_slots"] = plans[-1]["slots"]
		state["formation"] = plans[-1]["formation"]
		state["seats"] = plans[-1]["seats"]
		state["anchor"] = plans[-1]["anchor"]
		state["heading"] = plans[-1]["heading"]
		state["arrived"] = bool(plans[-1]["arrived"])
		if state["arrived"] and int(state["arrived_tick"]) < 0:
			state["arrived_tick"] = tick
		var on_seats: Array = []
		for n: String in plans[-1]["slots"]:
			if step < 4 or n != lost:
				on_seats.append(_crew(n, plans[-1]["slots"][n]))
		plans.append(ElementPlan.build(_situation(on_seats, tick), state, table))
		tick += 30
	return [plans[-2], plans[-1]]


func _moved(pair: Array) -> float:
	var worst := 0.0
	for n: String in pair[1]["slots"]:
		worst = maxf(worst, (pair[0]["slots"][n] as Vector3).distance_to(pair[1]["slots"][n]))
	return worst


func test_survivors_keep_their_seats_when_a_crew_is_lost() -> void:
	var before: Array = await _lose_one(false, "Green_S_3")
	var held: Array = await _lose_one(true, "Green_S_3")
	assert_true(bool((before[0]["deploy"] as Dictionary).get("deployed", false)), "setup: deployed before the loss")
	print("MEASURE deploy hold: survivors' worst seat move off %.1f m, held %.1f m (%s -> %s)" % [_moved(before), _moved(held),
			before[0]["formation"], held[1]["formation"]])
	assert_true(_moved(before) > 3.0, "counter: re-laid at the smaller size, a survivor's seat moves %.1f m" % _moved(before))
	assert_true(_moved(held) < 0.01, "held: no survivor's seat moves (%.2f m)" % _moved(held))
	assert_eq((held[1]["slots"] as Dictionary).size(), 4, "four survivors, four seats")
	assert_eq(String(held[1]["formation"]), String(held[0]["formation"]), "the shape keeps its name")
