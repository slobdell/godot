extends TestCase
## Round 35 extension (orders X3b, R35.17/R35.74): THE DEPLOY WAITS FOR PASSING TRAFFIC. Traced (builder2 bfcbb132b, the
## body stage s1): Hunters2's herringbone deploy put a crew in the Sirens' lane and held Sirens_1 9 s; its travel seats let
## them by. An all-in squad keeps its travel seats while another element's crew drives past, and the cap still deploys.
## Pure: ElementPlan.deploy_passing and ElementPlan._deploy_state.

var _was := ElementPlan.DEPLOY_PASS
var _was_step := ElementPlan.DEPLOY_STEP


func teardown() -> void:
	ElementPlan.DEPLOY_PASS = _was
	ElementPlan.DEPLOY_STEP = _was_step
	super.teardown()


func _passer(at: Vector3, velocity: Vector3, to: Variant) -> Dictionary:
	return {"position": at, "velocity": velocity, "to": to}


func test_a_crew_driving_past_to_somewhere_else_is_passing() -> void:
	var by := _passer(Vector3(10, 0, 5), Vector3(-6, 0, 0), Vector3(-10, 0, -50))
	assert_true(ElementPlan.deploy_passing([by], Vector3.ZERO), "near, moving, bound 51 m away: passing")


func test_not_passing_far_still_or_arriving_here() -> void:
	var far := _passer(Vector3(40, 0, 0), Vector3(-6, 0, 0), Vector3(-80, 0, 0))
	var still := _passer(Vector3(10, 0, 0), Vector3(0.2, 0, 0), Vector3(-80, 0, 0))
	var neighbour := _passer(Vector3(10, 0, 0), Vector3(-6, 0, 0), Vector3(12, 0, 4))
	var no_task := _passer(Vector3(10, 0, 0), Vector3(-6, 0, 0), null)
	assert_true(not ElementPlan.deploy_passing([far, still, neighbour], Vector3.ZERO), "40 m off, parked, or arriving beside us")
	assert_true(ElementPlan.deploy_passing([no_task], Vector3.ZERO), "a moving crew with no destination is traffic too")


func _state_at(tick: int, passers: Array) -> Dictionary:
	ElementPlan.DEPLOY_STEP = true
	var members: Array = []
	var slots := {}
	for i in 3:
		var at := Vector3(i * 8.0 - 8.0, 0.0, 0.0)
		members.append({"name": "Green_H_%d" % (i + 1), "unit": "law_ifv", "role": "tank", "position": at})
		slots["Green_H_%d" % (i + 1)] = at
	var situation := {"members": members, "tick": tick, "passers": passers, "heading": Vector3.FORWARD, "terrain": "open",
			"threat": "none", "composition": "balanced"}
	var state := {"task": {"verb": "move", "to": [0.0, 0.0]}, "issued_slots": slots, "arrived_tick": 100}
	return ElementPlan._deploy_state({"arrived": true}, situation, state, Vector3.ZERO, Vector3.ZERO, null,
			DoctrineTable.for_faction("law"))


func test_an_all_in_squad_holds_its_travel_seats_while_traffic_passes() -> void:
	ElementPlan.DEPLOY_PASS = true
	var by := [_passer(Vector3(10, 0, 5), Vector3(-6, 0, 0), Vector3(-10, 0, -50))]
	var held := _state_at(130, by)
	assert_true(not bool(held.get("deployed", false)), "held while the crew passes")
	assert_eq(int(held.get("pass_waits", 0)), 1, "counted")
	assert_true(bool(_state_at(131, []).get("deployed", false)), "deploys once the road is clear")


func test_the_cap_still_deploys_and_off_is_d1() -> void:
	ElementPlan.DEPLOY_PASS = true
	var by := [_passer(Vector3(10, 0, 5), Vector3(-6, 0, 0), Vector3(-10, 0, -50))]
	var capped := _state_at(100 + int(ElementPlan.DEPLOY_CAP_S * SimClock.TICK_RATE), by)
	assert_true(bool(capped.get("deployed", false)), "DEPLOY_CAP_S after arriving, it deploys anyway")
	ElementPlan.DEPLOY_PASS = false
	assert_true(bool(_state_at(130, by).get("deployed", false)), "switched off: D1's deploy, passers ignored")
