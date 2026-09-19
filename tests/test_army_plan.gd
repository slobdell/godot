extends TestCase
## X8: the army layer (ArmyPlan). Roles over a whole army, given once and kept; each role's task.

const OBJECTIVE := Vector3(0, 0, 0)
const HOME := Vector3(0, 0, 110)


func _army() -> Array:
	# Five squads the way a faction army forms them: four line elements (one weakened) and a recon element.
	return [
		{"id": 1, "class": "line", "center": Vector3(-30, 0, 100), "strength": 1.0, "size": 4},
		{"id": 2, "class": "line", "center": Vector3(-10, 0, 100), "strength": 1.0, "size": 5},
		{"id": 3, "class": "line", "center": Vector3(10, 0, 100), "strength": 0.6, "size": 4},
		{"id": 4, "class": "line", "center": Vector3(30, 0, 100), "strength": 1.0, "size": 4},
		{"id": 5, "class": "recon", "center": Vector3(50, 0, 100), "strength": 1.0, "size": 3}]


func _context(tick := 0, lanes: Array = [70.0]) -> Dictionary:
	return {"objective": OBJECTIVE, "hold_ground": true, "home": HOME, "lanes": lanes, "tick": tick}


func test_roles_split_the_army_and_stay_put() -> void:
	var first := ArmyPlan.plan(_army(), [], _context(), {})
	var roles: Dictionary = first["roles"]
	assert_eq(String(roles[2]), "main", "the strongest line element is the main effort")
	assert_eq(String(roles[5]), "shaping", "recon shapes first")
	var counts := {}
	for id in roles:
		counts[roles[id]] = int(counts.get(roles[id], 0)) + 1
	assert_eq(int(counts.get("main", 0)), 2, "a third of the line (rounded up) is the main effort (%s)" % roles)
	assert_eq(int(counts.get("shaping", 0)), 2, "one shaper per side: recon, then a line element (%s)" % roles)
	assert_eq(int(counts.get("reserve", 0)), 1, "the rest is the reserve (%s)" % roles)
	# Kept: the same army a second later, positions changed, gets the same roles.
	var moved := _army()
	for element: Dictionary in moved:
		element["center"] += Vector3(5, 0, -30)
	var again := ArmyPlan.plan(moved, [], _context(30), first)
	assert_eq(again["roles"], roles, "roles do not churn")


func test_a_lost_main_effort_is_replaced_from_the_reserve() -> void:
	var first := ArmyPlan.plan(_army(), [], _context(), {})
	var survivors: Array = []
	for element: Dictionary in _army():
		if String(first["roles"][int(element["id"])]) != "main":
			survivors.append(element)
	var reserve := -1
	for id in first["roles"]:
		if String(first["roles"][id]) == "reserve":
			reserve = int(id)
	var after := ArmyPlan.plan(survivors, [], _context(30), first)
	assert_eq(String(after["roles"][reserve]), "main", "the reserve becomes the main effort")


func test_with_nothing_known_the_main_effort_moves_on_the_objective_and_the_shapers_take_the_lanes() -> void:
	var result := ArmyPlan.plan(_army(), [], _context(), {})
	for id in result["roles"]:
		var task: Dictionary = result["tasks"][id]
		match String(result["roles"][id]):
			"main":
				assert_eq(task["verb"], "move", "main moves")
				assert_true(Vector2(task["to"][0], task["to"][1]).length() < 1.0, "on the objective (%s)" % [task["to"]])
			"shaping":
				assert_eq(task["verb"], "move", "a shaper drives its lane")
				assert_near(absf(float(task["to"][0])), 70.0, 0.5, "the lane, level with the objective (%s)" % [task["to"]])
			"reserve":
				assert_eq(task["verb"], "move", "the reserve trails")
				assert_true(float(task["to"][1]) > 50.0, "behind the main effort (%s)" % [task["to"]])
	var sides := {}
	for id in result["roles"]:
		if String(result["roles"][id]) == "shaping":
			sides[signf(float(result["tasks"][id]["to"][0]))] = true
	assert_eq(sides.size(), 2, "the shapers take opposite flanks")


func test_shapers_wait_on_the_lane_until_the_enemy_is_pinned() -> void:
	var army := _army()
	var first := ArmyPlan.plan(army, [], _context(), {})
	# Put the shapers at their lane points, and an enemy at the objective.
	for element: Dictionary in army:
		if String(first["roles"][int(element["id"])]) == "shaping":
			var to: Array = first["tasks"][int(element["id"])]["to"]
			element["center"] = Vector3(to[0], 0, to[1])
	var enemy := [{"name": "Rust_1", "position": Vector3(0, 0, -5), "pinned": false}]
	var with_base := army + [{"id": 6, "class": "support", "center": Vector3(0, 0, 90), "strength": 1.0, "size": 3}]
	var waiting := ArmyPlan.plan(with_base, enemy, _context(60), first)
	var base: Dictionary = waiting["tasks"][6]
	assert_eq(base["verb"], "support_by_fire", "the base of fire covers the main effort's objective")
	assert_eq(String(base["target"]), "Rust_1", "onto the enemy holding it")
	for id in waiting["roles"]:
		if String(waiting["roles"][id]) == "shaping":
			assert_eq(waiting["tasks"][id]["verb"], "hold", "a shaper holds its lane while the enemy's head is up")
	enemy[0]["pinned"] = true
	var going := ArmyPlan.plan(with_base, enemy, _context(90), waiting)
	for id in going["roles"]:
		if String(going["roles"][id]) == "shaping":
			assert_eq(going["tasks"][id]["verb"], "attack", "once it is pinned, the shaper goes in")


func test_the_reserve_is_committed_once_the_main_effort_has_been_fighting_a_while() -> void:
	var army := _army()
	var enemy := [{"name": "Rust_1", "position": Vector3(0, 0, 60), "pinned": false}]
	var first := ArmyPlan.plan(army, enemy, _context(0), {})
	var reserve := -1
	for id in first["roles"]:
		if String(first["roles"][id]) == "reserve":
			reserve = int(id)
	assert_eq(first["tasks"][reserve]["verb"], "move", "held back at first")
	var later := ArmyPlan.plan(army, enemy, _context(int(ArmyPlan.COMMIT_S * SimClock.TICK_RATE) + 1), first)
	assert_eq(later["tasks"][reserve]["verb"], "attack", "committed after %.0f s of contact" % ArmyPlan.COMMIT_S)


func test_every_task_is_valid() -> void:
	var enemy := [{"name": "Rust_1", "position": Vector3(0, 0, 60), "pinned": true}]
	var army := _army() + [{"id": 6, "class": "support", "center": Vector3(0, 0, 90), "strength": 1.0, "size": 3}]
	for lanes: Array in [[70.0], []]:
		for contacts: Array in [[], enemy]:
			var result := ArmyPlan.plan(army, contacts, _context(0, lanes), {})
			for id in result["tasks"]:
				assert_eq(ElementTask.validate(result["tasks"][id]), "", "%s's task %s" % [result["roles"][id], result["tasks"][id]])
