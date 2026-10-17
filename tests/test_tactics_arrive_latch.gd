extends TestCase
## Round 33 (R33.9, brains; manoeuvre's F1 trace on main): an element's arrival is latched for its task. It was read
## afresh every plan as `centre within ARRIVE_M`, and the two layouts it chooses between pulled the centre across that
## line and back: arrived seats the halt on the spot (his drawn heading), not arrived the travelling shape the other way,
## each seat jumping ~20 m a flip (gangs hull-rest faced_attack_move s40: the Battery flipped 67 times, 286 re-seats).
## Pure: ElementPlan.build on both of its arrival lines (a move that runs drills, and a plain form-up move).

const SPOT := Vector3(0.0, 0.0, 0.0)


func teardown() -> void:
	ElementPlan.ARRIVE_LATCH = true
	super.teardown()


func _table() -> DoctrineTable:
	DoctrineTable.clear_cache()
	var loaded := DoctrineTable.load_table("standard")
	assert_true(loaded.has("table"), "the standard table loads: %s" % loaded.get("error", ""))
	return loaded.get("table")


## Five tanks in a swarm round `center`, nobody in sight: the movement plans.
func _situation(center: Vector3, arrived: bool) -> Dictionary:
	var members: Array = []
	for i in 5:
		members.append({"name": "Green_%d" % (i + 1), "position": center + Vector3(i * 6.0 - 12.0, 0.0, 0.0),
				"forward": Vector3.FORWARD, "role": "tank", "unit": "tank", "speed": 9.0, "range": 90.0,
				"effective_range": 70.0, "sight": 140.0, "health": 1.0, "suppression": 0.0, "taking_fire": false})
	return {"tick": 1000, "team": 0, "center": center, "heading": Vector3.FORWARD, "leader": "Green_1",
			"members": members, "contacts": [], "terrain": "open", "threat": ElementSituation.threat_from([], false),
			"composition": "heavy", "strength": 1000.0, "enemy_strength": 0.0, "taking_fire": false, "arrived": arrived}


func _state(task: Dictionary, arrived: bool) -> Dictionary:
	return {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "", "drill_why": "",
			"anchor": null, "bounding": 0, "arrived": arrived, "heading": Vector3.FORWARD, "seats": {}}


func _arrived(task: Dictionary, metres: float, was: bool, table: DoctrineTable) -> bool:
	var center := SPOT + Vector3(0.0, 0.0, metres)
	return bool(ElementPlan.build(_situation(center, was), _state(task, was), table)["arrived"])


func _tasks() -> Dictionary:
	return {"drills move": {"verb": "move", "to": [SPOT.x, SPOT.z], "facing": [0.5, -0.866]},
			"form-up move": {"verb": "move", "to": [SPOT.x, SPOT.z], "drills": false}}


func test_an_arrived_element_stays_arrived_while_its_centre_swings_back_out() -> void:
	var table := _table()
	var tasks := _tasks()
	for label: String in tasks:
		var task: Dictionary = tasks[label]
		assert_true(_arrived(task, 11.0, false, table), "%s: in at 11 m" % label)
		# The re-seat to the halt pulls the centre back out past 12 m: the element has not left.
		assert_true(_arrived(task, 14.0, true, table), "%s: still arrived at 14 m" % label)
		assert_true(_arrived(task, 17.9, true, table), "%s: still arrived at 17.9 m (12 + 6)" % label)
		assert_true(not _arrived(task, 18.5, true, table), "%s: gone at 18.5 m" % label)


func test_an_element_not_yet_arrived_arrives_at_the_same_line_as_before() -> void:
	var table := _table()
	var tasks := _tasks()
	for label: String in tasks:
		var task: Dictionary = tasks[label]
		assert_true(not _arrived(task, 14.0, false, table), "%s: 14 m out, not arrived yet" % label)
		assert_true(_arrived(task, 12.0, false, table), "%s: 12 m, arrived (ARRIVE_M unchanged)" % label)


func test_the_control_arm_is_mains_rule() -> void:
	var table := _table()
	ElementPlan.ARRIVE_LATCH = false
	for label: String in _tasks():
		assert_true(not _arrived(_tasks()[label], 14.0, true, table), "%s: --arrive-latch=off reads 14 m as not arrived" % label)
