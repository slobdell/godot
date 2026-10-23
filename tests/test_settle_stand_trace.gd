extends TestCase
## Round 38 (settle, R38.15: S2 v3's reference terrain): THE STAND TRACE READS THE GROUND WHERE THE SQUAD STANDS, NOT THE
## SITUATION'S TERRAIN (ElementPlan._trace_stand). The latch holds the deploy's read in situation["terrain"]; the bar's
## reference must be independent of the arm, so the line takes terrain_at at the crews' centroid, once, STAND_TRACE_S after
## the deploy.


func _situation(tick: int, terrain: String, at: Vector3) -> Dictionary:
	var members: Array = []
	for i in 3:
		members.append({"name": "Green_T_%d" % i, "position": at + Vector3((i - 1) * 6.0, 0.0, 0.0)})
	return {"tick": tick, "leader": "Green_T_0", "terrain": terrain, "members": members}


func test_the_stand_line_reads_the_ground_once_after_the_deploy() -> void:
	ElementPlan._stood.clear()
	ElementSituation.forget_terrain()
	var at := Vector3(0.0, 0.0, 0.0)
	var ground := ElementSituation.terrain_at(at)
	var other := "lanes" if ground == "open" else "open"
	var deploy := {"tick": 100, "deployed": true}
	var plan := {"formation": "coil"}
	var due := 100 + int(ElementPlan.STAND_TRACE_S * SimClock.TICK_RATE)
	assert_eq(ElementPlan._trace_stand(plan, _situation(due - 1, other, at), deploy), {}, "not before STAND_TRACE_S")
	var line := ElementPlan._trace_stand(plan, _situation(due, other, at), deploy)
	assert_eq(String(line.get("terrain", "")), ground, "the ground at the centroid (%s), not the situation's %s" % [ground, other])
	assert_eq(int(line.get("deploy_tick", -1)), 100, "keyed to its deploy")
	assert_eq(String(line.get("formation", "")), "coil", "the shape standing then")
	assert_eq(ElementPlan._trace_stand(plan, _situation(due + 30, other, at), deploy), {}, "once per deploy")
	var again := ElementPlan._trace_stand(plan, _situation(due + 400, other, at), {"tick": 300, "deployed": true})
	assert_true(not again.is_empty(), "a new deploy prints its own line")
	ElementPlan._stood.clear()
