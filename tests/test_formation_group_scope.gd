extends TestCase
## Round 43 (R43.34) / round 44 (M1): a squad moving under one G1 group click (its task carries `group` or `halt_at`, set by the
## controls' pack) keeps today's seats, stations and shape pick: the seat bound, the bounded stations and the shape latch are for his
## single-squad orders (C43.5: the G1 v9 group column unchanged). Pure: ElementPlan.build on the Gangs table.

const CLICK := Vector3(-69.1, 0.0, 50.7)

var _bound := TacticsFormation.SEAT_BOUND  # the defaults as the command line set them
var _latch := ElementPlan.SHAPE_LATCH


func teardown() -> void:
	TacticsFormation.SEAT_BOUND = _bound  # the harness runs teardown() only (no after_each; R43.43)
	ElementPlan.SHAPE_LATCH = _latch
	super.teardown()


func _table() -> DoctrineTable:
	DoctrineTable.clear_cache()
	var loaded := DoctrineTable.load_table("gangs")
	assert_true(loaded.has("table"), "the gangs table loads: %s" % loaded.get("error", ""))
	return loaded.get("table")


func _situation(threat: String) -> Dictionary:
	var members: Array = []
	var units := ["gang_tank", "gang_tank", "gang_tank", "gang_ifv", "gang_support"]
	var center := CLICK + Vector3(26.0, 0.0, 45.0)
	for i in 5:
		members.append({"name": "Green_Guns_%d" % (i + 1), "position": center + Vector3(i * 6.5 - 13.0, 0.0, 0.0),
				"forward": Vector3(-0.5, 0.0, -0.87), "role": Units.role_of(units[i]), "unit": units[i], "speed": 12.0,
				"range": 90.0, "effective_range": 70.0, "sight": 140.0, "health": 1.0, "suppression": 0.0, "taking_fire": false})
	return {"tick": 1, "team": 0, "center": center, "heading": Vector3(-0.5, 0.0, -0.87), "leader": "Green_Guns_1",
			"members": members, "contacts": [], "terrain": "lanes", "threat": threat, "composition": "heavy",
			"strength": 1000.0, "enemy_strength": 0.0, "taking_fire": false, "arrived": false}


func _state(task: Dictionary) -> Dictionary:
	return {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "", "drill_why": "",
			"anchor": null, "bounding": 0, "arrived": false, "heading": Vector3(-0.5, 0.0, -0.87), "seats": {}, "player": true}


static func reach(slots: Dictionary, anchor: Vector3) -> float:
	var farthest := 0.0
	for name: String in slots:
		var to: Vector3 = slots[name]
		farthest = maxf(farthest, Vector2(to.x - anchor.x, to.z - anchor.z).length())
	return farthest


func test_grouped_reads_halt_at() -> void:
	assert_true(ElementPlan.grouped({"verb": "move", "to": [0.0, 0.0], "halt_at": [0.0, 0.0]}), "a packed squad's task carries halt_at")
	assert_true(ElementPlan.grouped({"verb": "move", "to": [0.0, 0.0], "group": 5}), "...and a re-laid leg of it keeps `group` (halt_at dropped)")
	# `group` as a key ElementTask.validate allows is orders' line (CP44.0: the KEYS entry lands with the pack's stamp and its test).
	assert_true(not ElementPlan.grouped({"verb": "move", "to": [0.0, 0.0]}), "his single-squad click does not")
	assert_true(not ElementPlan.grouped(null), "no task: not grouped")


func test_a_grouped_squad_keeps_todays_seats_under_the_bound() -> void:
	var gangs := _table()
	var single := {"verb": "move", "to": [CLICK.x, CLICK.z], "drills": false}
	var grouped := {"verb": "move", "to": [CLICK.x, CLICK.z], "drills": false, "halt_at": [CLICK.x, CLICK.z]}
	TacticsFormation.SEAT_BOUND = false
	var single_off: Dictionary = ElementPlan.build(_situation("none"), _state(single), gangs)["slots"]
	var grouped_off: Dictionary = ElementPlan.build(_situation("none"), _state(grouped), gangs)["slots"]
	TacticsFormation.SEAT_BOUND = true
	var single_on: Dictionary = ElementPlan.build(_situation("none"), _state(single), gangs)["slots"]
	var grouped_on: Dictionary = ElementPlan.build(_situation("none"), _state(grouped), gangs)["slots"]
	assert_true(reach(single_on, CLICK) < reach(single_off, CLICK) - 10.0,
			"his single-squad click is bounded (%.1f -> %.1f m)" % [reach(single_off, CLICK), reach(single_on, CLICK)])
	for name: String in grouped_off:
		assert_near((grouped_on[name] as Vector3).distance_to(grouped_off[name]), 0.0, 0.01, "%s: a grouped squad's seat is today's under the bound" % name)


func test_a_grouped_squad_is_not_latched() -> void:
	var gangs := _table()
	ElementPlan.SHAPE_LATCH = true
	var grouped := {"verb": "move", "to": [CLICK.x, CLICK.z], "drills": false, "halt_at": [CLICK.x, CLICK.z]}
	var plan := ElementPlan.build(_situation("none"), _state(grouped), gangs)
	assert_true((plan.get("shape_latch", {}) as Dictionary).is_empty(), "no latch for a grouped squad")
	var single := {"verb": "move", "to": [CLICK.x, CLICK.z], "drills": false}
	assert_true(not (ElementPlan.build(_situation("none"), _state(single), gangs).get("shape_latch", {}) as Dictionary).is_empty(), "his click latches")


func test_grouped_stations_and_transit_start_are_todays() -> void:
	var members: Array = _situation("none")["members"]
	var route: Array = [Vector3(-43.0, 0.0, 95.0), Vector3(-69.1, 0.0, 50.7)]
	var transit := {"route": route, "s": 30.0, "anchor": Vector3(-55.0, 0.0, 74.0), "heading": Vector3(-0.5, 0.0, -0.87)}
	TacticsFormation.SEAT_BOUND = false
	var off: Array = ElementPlan.route_seats(members, "swarm", 14.0, transit)
	var start_off := ElementPlan.transit_start_m("swarm", members, 14.0)
	TacticsFormation.SEAT_BOUND = true
	var grouped_on: Array = ElementPlan.route_seats(members, "swarm", 14.0, transit, false)
	var single_on: Array = ElementPlan.route_seats(members, "swarm", 14.0, transit, true)
	for i in off.size():
		assert_near((grouped_on[i] as Vector3).distance_to(off[i]), 0.0, 0.01, "a grouped squad's route seats are today's")
	assert_true((single_on[0] as Vector3).distance_to(off[0]) > 0.1 or (single_on[3] as Vector3).distance_to(off[3]) > 0.1, "his click's route seats are bounded")
	assert_near(ElementPlan.transit_start_m("swarm", members, 14.0, false), start_off, 0.01, "a grouped squad's transit start is today's")
	assert_true(ElementPlan.transit_start_m("swarm", members, 14.0, true) < start_off, "his click's transit start is the bounded depth's")
