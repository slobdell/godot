extends TestCase
## Round 43 (manoeuvre, R43.6): a move order keeps the travel shape it started with. His Guns on Locks 56416 (2026-10-27)
## flipped swarm / vee / swarm / vee / swarm as the threat reading changed and War Rig 3's seat moved 50-95 m each time. The
## latch: the shape the move started with stands until the element arrives or its task changes; the element's OWN contact
## may re-pick it once, after a second of it; a shape he chose with G is his; OFF by default (R43.42), `--shape-latch=on` is the arm.
## Pure: ElementPlan.build with the Gangs and the standard tables; no scene.

const CLICK := Vector3(-69.1, 0.0, 50.7)


var _latch_was := false


func before_each() -> void:
	_latch_was = ElementPlan.SHAPE_LATCH
	ElementPlan.SHAPE_LATCH = true  # the arm under test; OFF by default (R43.42)


func after_each() -> void:
	ElementPlan.SHAPE_LATCH = _latch_was


func test_off_by_default() -> void:
	ElementPlan.SHAPE_LATCH = _latch_was
	assert_true(not ElementPlan.SHAPE_LATCH or OS.get_cmdline_user_args().has("--shape-latch=on") or OS.get_environment("SHAPE_LATCH") == "on",
			"the latch is off unless --shape-latch=on is on the command line (R43.42)")


func _table(name: String) -> DoctrineTable:
	DoctrineTable.clear_cache()
	var loaded := DoctrineTable.load_table(name)
	assert_true(loaded.has("table"), "the %s table loads: %s" % [name, loaded.get("error", "")])
	return loaded.get("table")


## His Guns (three War Rigs, a Gun Truck, a Tanker) 50 m north-east of the click, driving for it.
func _situation(tick: int, threat: String) -> Dictionary:
	var members: Array = []
	var units := ["gang_tank", "gang_tank", "gang_tank", "gang_ifv", "gang_support"]
	var center := CLICK + Vector3(26.0, 0.0, 45.0)
	for i in 5:
		members.append({"name": "Green_Guns_%d" % (i + 1), "position": center + Vector3(i * 6.5 - 13.0, 0.0, 0.0),
				"forward": Vector3(-0.5, 0.0, -0.87), "role": Units.role_of(units[i]), "unit": units[i], "speed": 12.0,
				"range": 90.0, "effective_range": 70.0, "sight": 140.0, "health": 1.0, "suppression": 0.0, "taking_fire": false})
	return {"tick": tick, "team": 0, "center": center, "heading": Vector3(-0.5, 0.0, -0.87), "leader": "Green_Guns_1",
			"members": members, "contacts": [], "terrain": "lanes", "threat": threat, "composition": "heavy",
			"strength": 1000.0, "enemy_strength": 0.0, "taking_fire": false, "arrived": false}


func _state(task: Dictionary, latch: Dictionary = {}, arrived := false) -> Dictionary:
	return {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "", "drill_why": "",
			"anchor": null, "bounding": 0, "arrived": arrived, "heading": Vector3(-0.5, 0.0, -0.87), "seats": {},
			"player": true, "shape_latch": latch}


func _move() -> Dictionary:
	return {"verb": "move", "to": [CLICK.x, CLICK.z], "drills": false}


## One update: the shape picked, and the latch to carry into the next (as Element does).
func _step(table: DoctrineTable, task: Dictionary, latch: Dictionary, tick: int, threat: String, arrived := false) -> Dictionary:
	var plan := ElementPlan.build(_situation(tick, threat), _state(task, latch, arrived), table)
	return {"formation": String(plan["formation"]), "why": String(plan["why"]), "latch": plan.get("shape_latch", {})}


func test_his_guns_keep_the_swarm_through_the_threat_flapping() -> void:
	var gangs := _table("gangs")
	# War Rig 3's sequence: none (swarm) -> likely (the vee, t251) -> contact-less possible (swarm, t278) -> likely (vee, t350).
	var first := _step(gangs, _move(), {}, 1, "none")
	assert_eq(first["formation"], "swarm", "the Gangs' move starts as their swarm (the table's row)")
	assert_true(not (first["latch"] as Dictionary).is_empty(), "...and the move latches it")
	var latch: Dictionary = first["latch"]
	for step in [[251, "likely"], [278, "possible"], [350, "likely"], [437, "none"]]:
		var now := _step(gangs, _move(), latch, int(step[0]), String(step[1]))
		assert_eq(now["formation"], "swarm", "t%d threat %s: the swarm the move started with stands" % [step[0], step[1]])
		latch = now["latch"]
	ElementPlan.SHAPE_LATCH = false
	assert_eq(_step(gangs, _move(), {}, 251, "likely")["formation"], "vee", "OFF (the default): today's pick (the vee) each update")
	assert_true((_step(gangs, _move(), {}, 251, "likely")["latch"] as Dictionary).is_empty(), "...and nothing latched")


func test_the_kept_shape_says_so() -> void:
	var gangs := _table("gangs")
	var latch: Dictionary = _step(gangs, _move(), {}, 1, "none")["latch"]
	var kept := _step(gangs, _move(), latch, 251, "likely")
	assert_true(String(kept["why"]).contains("kept"), "the reason he reads names the latch: %s" % kept["why"])
	assert_true(not String(_step(gangs, _move(), latch, 2, "none")["why"]).contains("kept"), "the same pick says nothing of it")


func test_a_new_order_re_picks() -> void:
	var gangs := _table("gangs")
	var latch: Dictionary = _step(gangs, _move(), {}, 1, "none")["latch"]
	var elsewhere := {"verb": "move", "to": [CLICK.x - 30.0, CLICK.z], "drills": false}
	var now := _step(gangs, elsewhere, latch, 251, "likely")
	assert_eq(now["formation"], "vee", "his next click under a likely threat picks the table's vee afresh")
	assert_true(String((now["latch"] as Dictionary).get("key", "")) != String(latch.get("key", "")), "...and latches that order")


func test_the_elements_own_contact_re_picks_once_after_a_second() -> void:
	var standard := _table("standard")
	var task := _move()
	var start := _step(standard, task, {}, 1, "none")
	var contact_pick := String(standard.select({"task": "move", "threat": "contact", "terrain": "lanes", "composition": "heavy"})["formation"])
	var none_pick := String(start["formation"])
	assert_true(contact_pick != none_pick, "the standard table changes shape on contact (%s -> %s)" % [none_pick, contact_pick])
	var latch: Dictionary = start["latch"]
	var early := _step(standard, task, latch, 100, "contact")
	assert_eq(early["formation"], none_pick, "the first tick of contact keeps the shape (hysteresis)")
	latch = early["latch"]
	var later := _step(standard, task, latch, 100 + ElementPlan.SHAPE_LATCH_CONTACT_TICKS, "contact")
	assert_eq(later["formation"], contact_pick, "a second of the element's own contact re-picks the shape")
	latch = later["latch"]
	var after := _step(standard, task, latch, 300, "likely")
	assert_eq(after["formation"], contact_pick, "...once: the threat easing to likely does not flip it back")
	latch = after["latch"]
	var again := _step(standard, task, latch, 400, "contact")
	assert_eq(again["formation"], contact_pick, "a second contact changes nothing more")
	# A contact that does not last a second re-picks nothing.
	var fresh: Dictionary = _step(standard, task, {}, 1, "none")["latch"]
	var brief := _step(standard, task, fresh, 10, "contact")
	assert_eq(_step(standard, task, brief["latch"], 20, "none")["formation"], none_pick, "a brief contact: the shape stands")
	assert_eq(int((_step(standard, task, brief["latch"], 20, "none")["latch"] as Dictionary)["contact_since"]), -1,
			"...and the contact clock resets")


func test_a_chosen_shape_and_an_arrived_element_need_no_latch() -> void:
	var gangs := _table("gangs")
	var chosen := {"verb": "move", "to": [CLICK.x, CLICK.z], "drills": false, "formation": "column"}
	var picked := _step(gangs, chosen, {}, 1, "none")
	assert_eq(picked["formation"], "column", "a shape he chose with G is his")
	assert_true((picked["latch"] as Dictionary).is_empty(), "...and is not latched")
	var latch: Dictionary = _step(gangs, _move(), {}, 1, "none")["latch"]
	assert_true((_step(gangs, _move(), latch, 300, "none", true)["latch"] as Dictionary).is_empty(), "arrived: the latch ends")


func test_the_cpu_latches_too() -> void:
	var gangs := _table("gangs")
	var task := _move()
	var plan := ElementPlan.build(_situation(1, "none"), _state(task).merged({"player": false}, true), gangs)
	var latch: Dictionary = plan.get("shape_latch", {})
	assert_true(not latch.is_empty(), "the CPU's move latches its shape as his does")
	var next := ElementPlan.build(_situation(251, "likely"), _state(task, latch).merged({"player": false}, true), gangs)
	assert_eq(String(next["formation"]), "swarm", "...and keeps it under a likely threat")
