extends TestCase
## B9 (R34.15): THE LANE SPREAD. When a squad's route crosses the middle into a lane its side already sent a squad down
## this think, it goes `via` another lane's middle instead: a short enough detour, a lane the enemy does not hold in
## strength, fewer of its own squads there. Judged one-sided first (`--lane-spread=green|rust`), OFF by default.

const LOCKS := {"lanes": [
	{"name": "the lock", "points": [[0.0, 86.0], [0.0, 40.0], [0.0, -40.0], [0.0, -86.0]]},
	{"name": "west swing bridge", "points": [[-88.0, 70.0], [-92.0, 30.0], [-92.0, -30.0], [-88.0, -70.0]]},
	{"name": "east swing bridge", "points": [[60.0, 86.0], [92.0, 30.0], [92.0, -30.0], [70.0, -88.0]]}]}


func teardown() -> void:
	ElementCommander.LANE_SPREAD = "off"
	super.teardown()


func test_the_locks_lanes_cross_the_middle_west_to_east() -> void:
	var lanes := ElementCommander.lane_points(LOCKS)
	assert_eq(lanes.size(), 3, "three lanes")
	assert_near(lanes[0].x, -92.0, 0.01, "west")
	assert_near(lanes[1].x, 0.0, 0.01, "the lock")
	assert_near(lanes[2].x, 92.0, 0.01, "east")


func test_the_first_squad_keeps_its_lane_the_second_spreads() -> void:
	var lanes := ElementCommander.lane_points(LOCKS)
	var from := Vector3(10, 0, 80)
	var to := Vector3(0, 0, -60)
	assert_eq(ElementCommander.lane_pick(from, to, 5, lanes, {}, []), 1, "nobody in the lock yet: it goes by the lock")
	var spread := ElementCommander.lane_pick(from, to, 5, lanes, {1: 1}, [])
	assert_true(spread == 0 or spread == 2, "the lock taken: another lane (%d)" % spread)


func test_it_never_spreads_into_a_lane_the_enemy_holds_in_strength() -> void:
	var lanes := ElementCommander.lane_points(LOCKS)
	var held := []
	for i in 4:
		held.append({"position": Vector3(-92 + i, 0, 5)})  # four hulls on the west bridge's middle
	for i in 4:
		held.append({"position": Vector3(92 + i, 0, 5)})  # and four on the east
	var pick := ElementCommander.lane_pick(Vector3(10, 0, 80), Vector3(0, 0, -60), 5, lanes, {1: 1}, held)
	assert_eq(pick, 1, "both other lanes held in strength: it keeps the lock")


func test_a_detour_too_long_is_not_taken() -> void:
	var lanes := ElementCommander.lane_points(LOCKS)
	# A short hop over the lock: any other lane is far more than 1.4x + 30 m.
	assert_eq(ElementCommander.lane_pick(Vector3(0, 0, 20), Vector3(0, 0, -20), 5, lanes, {1: 1}, []), 1, "it keeps the lock")


func test_a_route_that_does_not_cross_the_middle_has_no_lane() -> void:
	var lanes := ElementCommander.lane_points(LOCKS)
	assert_eq(ElementCommander.lane_pick(Vector3(0, 0, 80), Vector3(30, 0, 40), 5, lanes, {}, []), -1, "same side: no lane")


func test_off_by_default() -> void:
	assert_eq(ElementCommander.LANE_SPREAD, "off", "judged first, off until it ships")
	assert_true(not ElementCommander.lane_spread_on(Match.Team.GREEN), "green off")


## The via leg: an element with a `via` drives there first, then plans its task as before.
func test_an_element_drives_its_via_first_then_its_task() -> void:
	DoctrineTable.clear_cache()
	var table: DoctrineTable = DoctrineTable.load_table("standard")["table"]
	var members: Array = []
	for i in 4:
		members.append({"name": "Rust_S_%d" % i, "unit": "tank", "role": "tank", "speed": 9.0, "range": 60.0,
				"effective_range": 45.0, "sight": 60.0, "health": 1.0, "suppression": 0.0, "taking_fire": false,
				"forward": Vector3.FORWARD, "position": Vector3(10 + i * 6, 0, 80)})
	var situation := {"tick": 1000, "team": 1, "center": Vector3(19, 0, 80), "heading": Vector3.FORWARD, "leader": "Rust_S_0",
			"members": members, "contacts": [], "terrain": "open", "threat": "none", "composition": "heavy",
			"strength": 800.0, "enemy_strength": 0.0, "taking_fire": false, "arrived": false}
	var task := {"verb": "move", "to": [0.0, -60.0], "via": [-92.0, 0.0]}
	assert_eq(ElementTask.validate(task), "", "a via is a valid task key")
	var state := {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "", "drill_why": "",
			"anchor": null, "bounding": 0, "arrived": false, "heading": Vector3.FORWARD, "seats": {}}
	var plan := ElementPlan.build(situation, state, table)
	assert_true((plan["anchor"] as Vector3).distance_to(Vector3(-92, 0, 0)) < 0.5, "first, the via (%s)" % plan["anchor"])
	assert_true(not bool(plan["via_done"]), "not there yet")
	var there := situation.duplicate()
	there["center"] = Vector3(-90, 0, 5)
	var after := ElementPlan.build(there, state, table)
	assert_true(bool(after["via_done"]), "within %.0f m: the via is done" % ElementPlan.VIA_REACHED_M)
	assert_true((after["anchor"] as Vector3).distance_to(Vector3(-92, 0, 0)) > 5.0, "then on to its spot (%s)" % after["anchor"])
