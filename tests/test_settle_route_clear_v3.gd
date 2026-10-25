extends TestCase
## Round 40 (settle S1 v3, `--seat-route-clear=v3`; round 39's time trace, references/round39/settle/s1-time-trace-builder0/).
## Pure: (b) DeployPassers.leg_clear, a cleared seat whose leg crosses or runs along a live corridor is not taken (cause B:
## crossing 5 route s6009, Echo_4's seat moved 25 m across the junction Delta still drove); a crew pulling out of one is;
## (c) with no fit seat the crew waits where it stood, keeps its seat, and takes it once the ground reads clear.
## Ground: an east-west street, a passer's corridor along z 0; a second one along z 12 for the wait.

var _v3 := ElementPlan.SEAT_ROUTE_CLEAR_V3
var _crew := DeployPassers.CREW_CORRIDORS


func teardown() -> void:
	ElementPlan.SEAT_ROUTE_CLEAR_V3 = _v3
	DeployPassers.CREW_CORRIDORS = _crew
	super.teardown()


const STREET := [Vector3(-100, 0, 0), Vector3(100, 0, 0)]
const SOUTH := [Vector3(-100, 0, 12), Vector3(100, 0, 12)]


func test_a_leg_across_a_live_corridor_is_not_fit() -> void:
	var passers := {"routes": [STREET], "halts": []}
	assert_true(DeployPassers.leg_clear(Vector3(0, 0, 10), Vector3(0, 0, 4), passers, 10.0), "a short leg")
	assert_true(not DeployPassers.leg_clear(Vector3(0, 0, 10), Vector3(0, 0, -9), passers, 10.0), "across the street")
	assert_true(not DeployPassers.leg_clear(Vector3(-20, 0, 3), Vector3(5, 0, 3), passers, 10.0), "down the street")
	assert_true(DeployPassers.leg_clear(Vector3(0, 0, 2), Vector3(0, 0, 20), passers, 10.0), "pulling out of it")


func _deploy_once(v3: bool, routes: Array, stands_z: float = 10.0) -> Array:
	ElementPlan.SEAT_ROUTE_CLEAR_V3 = v3
	var live := [{"routes": routes, "halts": []}]
	var passers := func() -> Dictionary: return live[0]
	var slots := {"Green_A_1": Vector3(0, 0, -1), "Green_A_2": Vector3(40, 0, 30)}
	var stood := {"Green_A_1": Vector3(0, 0, stands_z), "Green_A_2": Vector3(40, 0, 30)}
	var members: Array = []
	for n: String in slots:
		members.append({"name": n, "unit": "tank", "position": stood[n]})
	var plan := _plan(slots)
	var deploy := {"tick": 300, "heading": Vector3(1, 0, 0), "deployed": true}
	ElementPlan._route_clear(plan, deploy, {"tick": 300, "members": members, "passers": passers}, 10.0)
	return [plan, deploy, live, passers, members, slots]


func test_v2_crosses_the_street_v3_stays_its_side() -> void:
	var v2: Dictionary = _deploy_once(false, [STREET])[0]
	var v3: Dictionary = _deploy_once(true, [STREET])[0]
	var seat2: Vector3 = v2["slots"]["Green_A_1"]
	var seat3: Vector3 = v3["slots"]["Green_A_1"]
	print("MEASURE route clear v3: v2 seat %s, v3 seat %s (crew at z 10)" % [seat2, seat3])
	assert_true(seat2.z < -6.9, "counter: v2 clears it north, across the street (%s)" % [seat2])
	assert_true(seat3.z > 6.9, "v3: clear on the crew's own side (%s)" % [seat3])
	assert_true(DeployPassers.leg_clear(Vector3(0, 0, 10), seat3, {"routes": [STREET]}, 10.0), "its leg is fit")


func test_with_no_fit_seat_the_crew_waits_then_takes_its_seat() -> void:
	var r := _deploy_once(true, [STREET, SOUTH], 6.0)
	var plan: Dictionary = r[0]
	var deploy: Dictionary = r[1]
	assert_eq(plan["slots"]["Green_A_1"], Vector3(0, 0, 6), "waits where it stood")
	assert_eq(plan["orders"]["Green_A_1"]["to"], Vector3(0, 0, 6), "its order follows")
	assert_eq(int(deploy.get("waited", 0)), 1, "one crew waiting")
	assert_eq(plan["slots"]["Green_A_2"], Vector3(40, 0, 30), "a clear seat untouched")
	# Still blocked a second on: still waiting.
	var later := _plan(r[5])
	ElementPlan._route_clear(later, deploy, {"tick": 330, "members": r[4], "passers": r[3]}, 10.0)
	assert_eq(later["slots"]["Green_A_1"], Vector3(0, 0, 6), "still waiting while the passers drive")
	# The passers gone by: it takes its seat.
	(r[2] as Array)[0] = {"routes": [], "halts": []}
	var after := _plan(r[5])
	ElementPlan._route_clear(after, deploy, {"tick": 360, "members": r[4], "passers": r[3]}, 10.0)
	assert_eq(after["slots"]["Green_A_1"], Vector3(0, 0, -1), "the street clear: its own seat")
	assert_true((deploy.get("waits", {}) as Dictionary).is_empty(), "no one waiting")


func test_a_wait_ends_on_the_cap() -> void:
	var r := _deploy_once(true, [STREET, SOUTH], 6.0)
	var deploy: Dictionary = r[1]
	var late := _plan(r[5])
	ElementPlan._route_clear(late, deploy, {"tick": 300 + int(ElementPlan.WAIT_MAX_S * SimClock.TICK_RATE), "members": r[4],
			"passers": r[3]}, 10.0)
	assert_eq(late["slots"]["Green_A_1"], Vector3(0, 0, -1), "WAIT_MAX_S on: its seat whatever the ground reads")


static func _plan(slots: Dictionary) -> Dictionary:
	var orders := {}
	for n: String in slots:
		orders[n] = {"verb": "move", "to": slots[n]}
	return {"slots": slots.duplicate(), "orders": orders, "anchor": Vector3(20, 0, 20)}
