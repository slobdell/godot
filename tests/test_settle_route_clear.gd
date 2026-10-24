extends TestCase
## Round 39 (settle S1, C39.2): NO HALT SEAT ON A ROUTE A FRIENDLY SQUAD STILL HAS TO DRIVE, NONE INSIDE ANOTHER SQUAD'S
## PARKED HALT (ElementPlan.SEAT_ROUTE_CLEAR, DeployPassers). Pure: the geometry of the traced case, no match.
## terminus 5 route s4505 (R38.40, round 38's two-arm trace): Echo still had to drive west along the east-west street
## (z ~ 85) past Delta's halt, then south down the lane at x ~ 2. Delta's seats stood on the junction (-2.3, 79.9) and
## in the lane mouth (main's own relaid seat, (3.7, 67.8)); Echo stood stuck between them t 36-90 s.
## 1. Those two seats are blocked; a seat beside the street is not.
## 2. clear_seat moves a blocked seat out of the corridor, keeps the squad's own gap, and leaves a clear seat alone.
## 3. A seat inside another squad's parked halt is blocked and moved out of it.
## 4. The deploy's update (ElementPlan._route_clear): the ground is read once, every seat stands clear, the orders follow
##    the seats, and a later update with a crew lost clears against the same ground.

const ECHO_ROUTE := [Vector3(60, 0, 86), Vector3(21.5, 0, 85), Vector3(2.5, 0, 80), Vector3(2.8, 0, 72.1), Vector3(2.3, 0, 51.3)]

var _clear := ElementPlan.SEAT_ROUTE_CLEAR


func teardown() -> void:
	ElementPlan.SEAT_ROUTE_CLEAR = _clear
	super.teardown()


static func _same(p: Vector3) -> Vector3:
	return p


static func _anywhere(_p: Vector3) -> bool:
	return true


func _passers() -> Dictionary:
	return {"routes": [ECHO_ROUTE], "halts": []}


func test_the_traced_seats_are_on_echos_route() -> void:
	assert_true(not DeployPassers.blocking(Vector3(-2.3, 0, 79.9), _passers()).is_empty(), "the junction seat")
	assert_true(not DeployPassers.blocking(Vector3(3.7, 0, 67.8), _passers()).is_empty(), "the lane-mouth seat")
	assert_true(DeployPassers.blocking(Vector3(30, 0, 100), _passers()).is_empty(), "a seat 15 m off the street")
	assert_true(DeployPassers.blocking(Vector3(-2.3, 0, 79.9), {}).is_empty(), "nothing to keep clear of")


func test_a_blocked_seat_moves_clear_and_keeps_its_gap() -> void:
	var back := Vector3(1, 0, 0)  # Delta drove west: back is east
	var others: Array = [Vector3(10, 0, 70)]
	var moved: Variant = DeployPassers.clear_seat(Vector3(3.7, 0, 67.8), back, _passers(), others, 10.0,
			_same, _anywhere)
	print("MEASURE lane-mouth seat (3.7, 67.8) -> %s" % [moved])
	assert_true(moved is Vector3, "a clear seat found")
	assert_true(DeployPassers.blocking(moved, _passers()).is_empty(), "off the route")
	assert_true(Vector2((moved as Vector3).x - 10, (moved as Vector3).z - 70).length() >= 7.5, "the squad's own gap")
	assert_true((moved as Vector3).distance_to(Vector3(3.7, 0, 67.8)) <= DeployPassers.CLEAR_MAX_M, "near where it was")
	var kept: Variant = DeployPassers.clear_seat(Vector3(30, 0, 100), back, _passers(), [], 10.0, _same, _anywhere)
	assert_eq(kept, Vector3(30, 0, 100), "a clear seat stays")


func test_judged_where_it_will_stand() -> void:
	# A seat asked off the route but grounded onto it (main's relaid seat) is blocked: the grounded point is judged.
	var onto := func(_p: Vector3) -> Vector3: return Vector3(3.7, 0, 67.8)
	var asked := Vector3(17.3, 0, 69.8)
	assert_true(DeployPassers.blocking(asked, _passers()).is_empty(), "asked off the route")
	var moved: Variant = DeployPassers.clear_seat(asked, Vector3(1, 0, 0), _passers(), [], 10.0, onto, _anywhere)
	assert_true(moved == null, "grounded onto the route wherever it is asked: no clear seat (%s)" % [moved])


func test_a_seat_inside_a_parked_halt_moves_out() -> void:
	var parked := {"routes": [], "halts": [[Vector3(-70, 0, 30), Vector3(-60, 0, 30)]]}
	var seat := Vector3(-65, 0, 34)
	assert_true(not DeployPassers.blocking(seat, parked).is_empty(), "inside the neighbour's halt")
	var moved: Variant = DeployPassers.clear_seat(seat, Vector3(0, 0, 1), parked, [], 10.0, _same, _anywhere)
	print("MEASURE bridge-mouth seat %s -> %s" % [seat, moved])
	assert_true(moved is Vector3 and DeployPassers.blocking(moved, parked).is_empty(), "moved out of it")


func test_the_deploys_update_clears_every_seat_once_read() -> void:
	var reads := [0]
	var passers := func() -> Dictionary:
		reads[0] += 1
		return _passers()
	var slots := {"Green_Delta_1": Vector3(-2.3, 0, 79.9), "Green_Delta_2": Vector3(9.3, 0, 95.8),
			"Green_Delta_3": Vector3(3.7, 0, 67.8), "Green_Delta_4": Vector3(25, 0, 98), "Green_Delta_5": Vector3(40, 0, 100)}
	var plan := _plan(slots)
	var deploy := {"tick": 300, "heading": Vector3(-1, 0, 0), "deployed": true}
	var members: Array = []
	for n: String in slots:
		members.append({"name": n, "unit": "tank", "position": slots[n]})
	ElementPlan._route_clear(plan, deploy, {"tick": 300, "members": members, "passers": passers, "center": Vector3(21.5, 0, 84.5)}, 10.0)
	print("MEASURE deploy cleared %d: %s" % [int(deploy.get("cleared", 0)), plan["slots"]])
	assert_eq(reads[0], 1, "the ground read once")
	for n: String in plan["slots"]:
		assert_true(DeployPassers.blocking(plan["slots"][n], _passers()).is_empty(), "%s clear" % n)
		assert_eq(plan["orders"][n]["to"], plan["slots"][n], "%s's order follows its seat" % n)
	assert_eq(plan["slots"]["Green_Delta_5"], Vector3(40, 0, 100), "a clear seat untouched")
	assert_true(int(deploy.get("cleared", 0)) >= 2, "the two traced seats moved")
	# A later update, a crew lost: the same ground, no new read.
	slots.erase("Green_Delta_2")
	var later := _plan(slots)
	ElementPlan._route_clear(later, deploy, {"tick": 330, "members": members.slice(0, 1) + members.slice(2), "passers": passers,
			"center": Vector3(21.5, 0, 84.5)}, 10.0)
	assert_eq(reads[0], 1, "still read once")
	for n: String in later["slots"]:
		assert_true(DeployPassers.blocking(later["slots"][n], _passers()).is_empty(), "%s clear after the loss" % n)


func test_route_from_starts_where_the_squad_is() -> void:
	var rest := DeployPassers.route_from(ECHO_ROUTE, 50.0)
	assert_true((rest[0] as Vector3).x < 21.5 and (rest[0] as Vector3).x > 2.5, "past the first corner (%s)" % [rest[0]])
	assert_eq(rest.size(), 4, "the point there and the three corners after it")


static func _plan(slots: Dictionary) -> Dictionary:
	var orders := {}
	for n: String in slots:
		orders[n] = {"verb": "move", "to": slots[n]}
	return {"slots": slots.duplicate(), "orders": orders, "anchor": Vector3(21.5, 0, 84.5)}
