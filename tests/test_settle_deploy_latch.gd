extends TestCase
## Round 38 (settle S2, latch v2): A DEPLOYED HALT KEEPS THE TERRAIN ITS SHAPE WAS DECIDED ON (ElementPlan.DEPLOY_LATCH).
## 1. R37.42's geometry first (test_tactics_scenarios_2's move, TacticsScenarios.task_posture "move", lab seed 17): four
##    tanks in a lane cross an `open` pocket the update before they stand arrived. Round 37's latch keeps that one-update
##    read and deploys a coil in the lane (the counter); the deploy latch reads at the all-in and stands in a herringbone.
## 2. The flicker it exists for: a squad parked by a plain move on open ground a few metres from a lanes edge, nudged
##    across the edge and back after it deployed. Main's centroid read flips the halt (the counter); latched, it does not.

const MAP := "locks"
const NUDGE_EVERY := SimClock.TICK_RATE * 2
const NUDGES := 6
const CLEAR_M := 16.0

var _latch := ElementPlan.DEPLOY_LATCH
var _terrain := ElementSituation.HALT_TERRAIN


func teardown() -> void:
	ElementPlan.DEPLOY_LATCH = _latch
	ElementSituation.HALT_TERRAIN = _terrain
	super.teardown()


func test_a_squad_stopping_in_a_lane_after_a_gap_stands_in_a_herringbone() -> void:
	ElementPlan.DEPLOY_LATCH = false
	ElementSituation.HALT_TERRAIN = "latch"
	var round37: Dictionary = await TacticsScenarios.task_posture(self, "move", 30.0)
	ElementSituation.HALT_TERRAIN = "centre"
	ElementPlan.DEPLOY_LATCH = true
	var latched: Dictionary = await TacticsScenarios.task_posture(self, "move", 30.0)
	print("MEASURE deploy latch: round-37 latch %s | deploy latch %s" % [round37, latched])
	assert_eq(String(round37["formation"]), "coil", "counter: round 37's latch keeps the gap's read (%s)" % round37["formation"])
	assert_eq(String(latched["formation"]), "herringbone", "the deploy's read: herringbone in the lane")
	assert_true(int(latched["orders_last_10s"]) <= 2, "and quiet (%d orders in the last 10 s)" % latched["orders_last_10s"])
	assert_true(float(latched["worst_off_slot_m"]) <= 8.0, "every vehicle in its slot (%.1f m)" % latched["worst_off_slot_m"])


## An open spot clear of cover by CLEAR_M whose terrain turns to cover a few metres away: {at, dir, r}.
func _edge() -> Dictionary:
	var features := ElementSituation._arena_features()
	var dirs: Array[Vector3] = []
	for k in 8:
		dirs.append(Vector3(cos(k * PI / 4.0), 0.0, sin(k * PI / 4.0)))
	for x in range(-120, 121, 4):
		for z in range(-120, 121, 4):
			var at := Vector3(x, 0.0, z)
			if ElementSituation.terrain_at(at) != "open" or Orders.clamp_to_arena(at).distance_to(at) > 0.1:
				continue
			var clear := true
			for feature: Dictionary in features:
				for p: Vector3 in feature.get("positions", [feature.get("position", Vector3.INF)]):
					clear = clear and Vector2(p.x - at.x, p.z - at.z).length() >= CLEAR_M
			if not clear:
				continue
			for dir: Vector3 in dirs:
				for step in range(2, 9):
					var r := step * 0.5
					if ElementSituation.terrain_at(at + dir * r) != "open":
						return {"at": at, "dir": dir, "r": r}
	return {}


func _flips(latch: bool) -> Dictionary:
	ElementSituation.HALT_TERRAIN = "centre"
	ElementPlan.DEPLOY_LATCH = latch
	var lab := TacticsLab.create(self, 7, MAP)
	ElementSituation.forget_terrain()
	var edge := _edge()
	assert_true(not edge.is_empty(), "setup: %s has an open spot within 4 m of a cover edge" % MAP)
	if edge.is_empty():
		lab.dispose()
		return {}
	var at: Vector3 = edge["at"]
	var names: Array = []
	for i in 3:
		var n := "Green_H_%d" % i
		lab.unit(Match.Team.GREEN, n, at + Vector3((i - 1) * 9.0, 0.0, 0.0), 0.0)
		names.append(n)
	var element := lab.element(names, "Alpha")
	element.assign({"verb": "move", "to": [at.x, at.z], "drills": false})
	await lab.start()
	var waited := 0
	while not bool(element.deploy.get("deployed", false)) and waited < SimClock.TICK_RATE * 20:
		await lab.step()
		waited += 1
	for tick in SimClock.TICK_RATE * 2:
		await lab.step()
	var first := element.formation
	var flips := 0
	var last := first
	var shift: Vector3 = edge["dir"] * (float(edge["r"]) + 1.0)
	for nudge in NUDGES:
		for n: String in names:
			var tank := lab.tank_of(n)
			tank.place(tank.global_position + (shift if nudge % 2 == 0 else -shift), tank.rotation.y)
		for tick in NUDGE_EVERY:
			await lab.step()
			if element.formation != last:
				flips += 1
				last = element.formation
	var out := {"flips": flips, "first": first, "deployed": bool(element.deploy.get("deployed", false)),
			"deploy_terrain": str(element.deploy.get("terrain", "")), "edge": edge}
	lab.dispose()
	return out


func test_a_deployed_halt_does_not_flip_when_its_crews_creep_across_a_terrain_edge() -> void:
	var centre := await _flips(false)
	var latched := await _flips(true)
	if centre.is_empty() or latched.is_empty():
		return
	print("MEASURE deploy latch flips: centre %s | latched %s" % [centre, latched])
	assert_true(bool(latched["deployed"]) and bool(centre["deployed"]), "setup: both squads deployed")
	assert_true(int(centre["flips"]) >= 2, "counter: main's centroid read flips the deployed halt (%s)" % centre)
	assert_eq(int(latched["flips"]), 0, "latched at the deploy the halt keeps its shape (%s)" % latched)
	assert_eq(String(latched["first"]), String(centre["first"]), "the same first shape as main's")


func test_before_the_deploy_the_live_read_stands() -> void:
	ElementPlan.DEPLOY_LATCH = true
	var situation := {"terrain": "lanes"}
	assert_eq(ElementPlan._deploy_latched(situation, {"deploy": {"deployed": false, "terrain": "open"}}), situation, "not deployed")
	assert_eq(ElementPlan._deploy_latched(situation, {}), situation, "no deploy")
	assert_eq(String(ElementPlan._deploy_latched(situation, {"deploy": {"deployed": true, "terrain": "open"}})["terrain"]), "open",
			"deployed: the deploy's read")
	assert_eq(String(situation["terrain"]), "lanes", "the element's own situation is not edited")
	ElementPlan.DEPLOY_LATCH = false
	assert_eq(ElementPlan._deploy_latched(situation, {"deploy": {"deployed": true, "terrain": "open"}}), situation, "OFF: main's")
