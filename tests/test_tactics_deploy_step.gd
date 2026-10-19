extends TestCase
## B8 (R34.14; the lead's deploy-step question): THE DEPLOY STEP, a prototype behind `--deploy-step=on`. An AUTO squad on
## a plain move keeps its TRAVEL seats until every crew is in (or DEPLOY_CAP_S), then lays its HALT once, on a heading
## fixed at the order (the task's `lay`), and those seats stand.


func teardown() -> void:
	ElementPlan.DEPLOY_STEP = false
	super.teardown()


func _members(at: Vector3, spread: float) -> Array:
	var members: Array = []
	for i in 4:
		members.append({"name": "Green_S_%d" % (i + 1), "unit": "law_tank", "role": "tank", "speed": 9.0, "range": 60.0,
				"effective_range": 45.0, "sight": 60.0, "health": 1.0, "suppression": 0.0, "taking_fire": false,
				"forward": Vector3.FORWARD, "position": at + Vector3((i - 1.5) * spread, 0, 0)})
	return members


func _situation(center: Vector3, members: Array, tick: int) -> Dictionary:
	return {"tick": tick, "team": 0, "center": center, "heading": Vector3.FORWARD, "leader": "Green_S_1",
			"members": members, "contacts": [], "terrain": "open", "threat": "none", "composition": "heavy",
			"strength": 800.0, "enemy_strength": 0.0, "taking_fire": false, "arrived": false}


## Plans an AUTO plain move to `destination` with `lay` from far, then at the spot with the crews where `crews_at` puts
## them, carrying state as the element does. Returns the plans.
func _drive(lay: Array, crews_at: Callable) -> Array:
	DoctrineTable.clear_cache()
	var table: DoctrineTable = DoctrineTable.load_table("standard")["table"]
	var destination := Vector3(0, 0, -60)
	var task := {"verb": "move", "to": [destination.x, destination.z], "drills": false, "lay": lay}
	var state := {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "", "drill_why": "",
			"anchor": null, "bounding": 0, "arrived": false, "heading": Vector3.FORWARD, "seats": {}, "arrived_tick": -1,
			"deploy": {}, "issued_slots": {}}
	var far := ElementPlan.build(_situation(Vector3(30, 0, 40), _members(Vector3(30, 0, 40), 8.0), 100), state, table)
	var plans := [far]
	var tick := 200
	for step in 3:
		state["deploy"] = plans[-1].get("deploy", {})
		state["issued_slots"] = plans[-1]["slots"]
		state["formation"] = plans[-1]["formation"]
		state["seats"] = plans[-1]["seats"]
		state["anchor"] = plans[-1]["anchor"]
		state["heading"] = plans[-1]["heading"]
		state["arrived"] = bool(plans[-1]["arrived"])
		if state["arrived"] and int(state["arrived_tick"]) < 0:
			state["arrived_tick"] = tick
		var members: Array = crews_at.call(plans[-1]["slots"])
		plans.append(ElementPlan.build(_situation(destination, members, tick), state, table))
		tick += 30
	return plans


static func _on_seats(slots: Dictionary) -> Array:
	var members: Array = []
	for n: String in slots:
		members.append({"name": n, "unit": "law_tank", "role": "tank", "speed": 9.0, "range": 60.0, "effective_range": 45.0,
				"sight": 60.0, "health": 1.0, "suppression": 0.0, "taking_fire": false, "forward": Vector3.FORWARD,
				"position": slots[n]})
	return members


func test_the_squad_keeps_its_travel_seats_until_every_crew_is_in_then_deploys_on_the_ordered_heading() -> void:
	ElementPlan.DEPLOY_STEP = true
	var lay := [1.0, 0.0]  # east: not the way it drove (north)
	var short := func(slots: Dictionary) -> Array:
		var members := _on_seats(slots)
		(members[0] as Dictionary)["position"] = (members[0]["position"] as Vector3) + Vector3(0, 0, 20)  # one crew 20 m short
		return members
	var waiting := _drive(lay, short)
	assert_true(not bool((waiting[-1]["deploy"] as Dictionary).get("deployed", false)), "a crew still out: not deployed")
	assert_eq(String(waiting[-1]["formation"]), String(waiting[1]["formation"]), "still in its travel shape")
	var all_in := _drive(lay, func(slots: Dictionary) -> Array: return _on_seats(slots))
	var deployed: Dictionary = all_in[-1]
	assert_true(bool((deployed["deploy"] as Dictionary).get("deployed", false)), "every crew in: deployed")
	assert_eq(String((deployed["deploy"] as Dictionary).get("cause", "")), "all_in", "because everyone was in")
	var halt := SelectionSquads.halt_shape(DoctrineTable.load_table("standard")["table"], "open", ["tank", "tank", "tank", "tank"])
	assert_eq(String(deployed["formation"]), halt, "in its halt, the table's hold pick (%s)" % halt)
	assert_true((deployed["heading"] as Vector3).distance_to(Vector3(1, 0, 0)) < 0.01, "on the heading fixed at the order (%s)" % deployed["heading"])


func test_once_deployed_its_seats_stand() -> void:
	ElementPlan.DEPLOY_STEP = true
	var plans := _drive([1.0, 0.0], func(slots: Dictionary) -> Array: return _on_seats(slots))
	var a: Dictionary = plans[-2]["slots"]
	var b: Dictionary = plans[-1]["slots"]
	assert_true(bool((plans[-2]["deploy"] as Dictionary).get("deployed", false)), "setup: deployed a step earlier")
	for n: String in b:
		assert_true((a[n] as Vector3).distance_to(b[n]) < 0.5, "%s's halt seat stands (%.1f m)" % [n, (a[n] as Vector3).distance_to(b[n])])


func test_off_by_default_the_travel_shape_stands() -> void:
	var plans := _drive([1.0, 0.0], func(slots: Dictionary) -> Array: return _on_seats(slots))
	assert_true((plans[-1].get("deploy", {}) as Dictionary).is_empty(), "no deploy state with the switch off")
	assert_eq(String(plans[-1]["formation"]), String(plans[1]["formation"]), "round 33's shape on the spot")


## B8b: on the Locks, a halt laid at the canal's edge steps inland until every seat is dry and on its own bank (B8's
## red squad bunched on one strip of bank there).
func test_a_halt_at_the_canal_edge_steps_inland_until_every_seat_is_dry() -> void:
	var lab := TacticsLab.create(self, 1, "locks")
	lab.unit(Match.Team.GREEN, "Green_P_1", Vector3(-34.0, 0, 40.0), 0.0)
	await lab.start()
	var edge := Vector3(-34.0, 0, 12.0)  # the north quay's edge; the canal is z -7..7
	var members := _members(edge, 8.0)
	var anchor := ElementPlan._dry_halt_anchor(edge, members, "herringbone", Vector3(1, 0, 0), 14.0)
	var wet := 0
	for entry in TacticsFormation.place(members, "herringbone", anchor, Vector3(1, 0, 0), 14.0, {"halt": true, "corridor_m": INF}):
		var seat: Vector3 = entry["to"]
		if SlotGround.over_water(seat) or seat.z < 7.0:
			wet += 1
	print("DEPLOY_INLAND edge %s -> anchor %s" % [edge, anchor])
	assert_eq(wet, 0, "every seat on the north quay (anchor %s)" % anchor)
	assert_true(anchor.z > edge.z, "stepped inland (away from the canal)")
