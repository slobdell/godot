extends TestCase
## Round 38 (settle, R38.17: S1 v3): A DEPLOY THE FIT DOES NOT TURN IS MAIN'S DEPLOY, BYTE FOR BYTE. S1 v2 dealt every deploy's
## seats by its own grounded Hungarian, turned or not, so runs with no turned deploy still diverged from main (crossing 5
## route s3931: squad 4 never got in, builder2 cbb2ece52). Pure: an AUTO plain move driven to its deploy and parked
## (test_settle_deploy_hold's drive), every plan compared with DEPLOY_FIT off and on; and the traced across-the-street
## squad (test_settle_deploy_fit) still turns and keeps its deal.

var _fit := ElementPlan.DEPLOY_FIT
var _step := ElementPlan.DEPLOY_STEP


func teardown() -> void:
	ElementPlan.DEPLOY_FIT = _fit
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


## Every plan of the drive (the crews on their seats after each), as text.
func _drive(fit: bool, start: Array) -> Array:
	ElementPlan.DEPLOY_STEP = true
	ElementPlan.DEPLOY_FIT = fit
	DoctrineTable.clear_cache()
	var table: DoctrineTable = DoctrineTable.load_table("standard")["table"]
	var task := {"verb": "move", "to": [0.0, -60.0], "drills": false, "lay": [1.0, 0.0]}
	var state := {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "", "drill_why": "",
			"anchor": null, "bounding": 0, "arrived": false, "heading": Vector3.FORWARD, "seats": {}, "arrived_tick": -1,
			"deploy": {}, "issued_slots": {}}
	var members: Array = []
	for i in start.size():
		members.append(_crew("Green_F_%d" % (i + 1), start[i]))
	var plans := [ElementPlan.build(_situation(members, 100), state, table)]
	var tick := 200
	for step in 6:
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
			on_seats.append(_crew(n, plans[-1]["slots"][n]))
		plans.append(ElementPlan.build(_situation(on_seats, tick), state, table))
		tick += 30
	return plans


static func _text(plan: Dictionary) -> String:
	var deploy: Dictionary = (plan.get("deploy", {}) as Dictionary).duplicate()
	deploy.erase("fit")
	return "%s|%s|%s|%s|%s|%s" % [plan["formation"], plan["slots"], plan["seats"], plan["anchor"], plan["heading"], deploy]


func test_a_deploy_not_turned_is_mains_deploy() -> void:
	# Five crews round their middle (no axis to lay along): the fit cannot turn.
	var start: Array = []
	for i in 5:
		start.append(Vector3(cos(i * TAU / 5.0) * 9.0, 0, 40.0 + sin(i * TAU / 5.0) * 9.0))
	var off := _drive(false, start)
	var on := _drive(true, start)
	var deployed := false
	for i in off.size():
		var fit: Dictionary = (on[i].get("deploy", {}) as Dictionary).get("fit", {})
		deployed = deployed or bool((on[i].get("deploy", {}) as Dictionary).get("deployed", false))
		assert_true(not bool(fit.get("turned", false)), "setup: plan %d's deploy not turned" % i)
		assert_eq(_text(on[i]), _text(off[i]), "plan %d identical to main's" % i)
	assert_true(deployed, "setup: the drive reaches its deploy")


func test_a_turned_deploy_keeps_its_deal() -> void:
	var at := {"Green_Delta_1": [7.07, 81.91], "Green_Delta_2": [44.23, 88.33], "Green_Delta_3": [27.42, 87.28],
			"Green_Delta_4": [19.77, 103.07], "Green_Delta_5": [17.54, 91.25]}
	var members: Array = []
	for n: String in at:
		members.append({"name": n, "unit": "tank", "role": "tank", "position": Vector3(float(at[n][0]), 0, float(at[n][1]))})
	var ordered := Vector3(0.0516, 0, -0.9987)
	var deploy := {"heading": ordered, "anchor": Vector3(22.22, 0, 84.5)}
	ElementPlan._deploy_fit(deploy, {"members": members, "center": Vector3(22.22, 0, 84.5), "tick": 300},
			Vector3(22.22, 0, 84.5), "herringbone", 10.0)
	assert_true(bool(deploy["fit"]["turned"]), "the traced squad turns")
	assert_eq((deploy.get("keep", {}) as Dictionary).size(), 5, "and keeps its deal")
	assert_true((deploy["heading"] as Vector3).distance_to(ordered) > 0.5, "on the squad's axis")


func test_a_deploy_not_turned_keeps_no_deal() -> void:
	var members: Array = []
	for i in 4:
		members.append({"name": "S_%d" % i, "unit": "tank", "role": "tank",
				"position": Vector3(cos(i * PI / 2.0) * 10.0, 0, sin(i * PI / 2.0) * 10.0)})
	var deploy := {"heading": Vector3.FORWARD, "anchor": Vector3.ZERO}
	ElementPlan._deploy_fit(deploy, {"members": members, "center": Vector3.ZERO, "tick": 300}, Vector3.ZERO, "coil", 14.0)
	assert_true(not bool(deploy["fit"]["turned"]), "round its middle: not turned")
	assert_true(not deploy.has("keep"), "no deal of its own: main's seating stands")
	assert_eq(deploy["heading"], Vector3.FORWARD, "main's heading")
	assert_eq(deploy["anchor"], Vector3.ZERO, "main's anchor")
