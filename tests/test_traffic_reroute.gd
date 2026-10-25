extends TestCase
## Round 40, manoeuvre M3 (R40.12; `--giveway-reroute` = `--traffic-on=reroute`, Traffic.DEFAULT_OFF until its bar is judged): a
## WEDGED wheeled asker that a friend is holding in place for is handed to the planner's seam, planned to its route's first point
## past the holder (the holder a box in the plan's world). The stage: a parked tank at the origin, a wheeled gang_artillery 12 m
## south ordered to (0, -30), straight through it; the holder's give-way and the asker's stall are written, as M1 v2's tests do.

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("reroute", Traffic.DEFAULT_OFF.has("reroute"))
	Traffic.set_off("rerouteany", Traffic.DEFAULT_OFF.has("rerouteany"))
	PlannerSeam.reset()
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## [holder mover, asker mover]: the holder giving way to the asker as `spot`, the asker stalled for `stalled_s`.
func _stage(spot: String, stalled_s: float, asker_unit := "gang_artillery") -> Array:
	_lab = TacticsLab.create(self, 7, "yard_open")
	var parked := _lab.gun(Match.Team.GREEN, "Green_Holder", Vector3.ZERO, 0.0, "tank")
	var asker := _lab.unit(Match.Team.GREEN, "Green_Asker", Vector3(0.0, 0.0, 12.0), 0.0, asker_unit)
	await _lab.start()
	for i in 3:
		await _lab.step()
	_lab.element([String(asker.name)], "Go").assign({"verb": "move", "to": [0.0, -30.0]})
	for i in 2:
		await _lab.step()
	var holder := Movement.of(parked)
	holder.yield_to = String(asker.name)
	holder.yield_spot = spot
	var mover := Movement.of(asker)
	mover.stalled_ticks = int(stalled_s * SimClock.TICK_RATE)
	return [holder, mover]


func test_off_by_default() -> void:
	assert_true(Traffic.DEFAULT_OFF.has("reroute") and Traffic.DEFAULT_OFF.has("rerouteany"), "both names opt-in until judged")
	Traffic.set_off("reroute", true)
	assert_true(not PlannerSeam.reroute_on(), "OFF: the scan does nothing")


func test_off_a_wedged_asker_is_not_taken() -> void:
	Traffic.set_off("reroute", true)
	var staged: Array = await _stage("hold", 5.0)
	PlannerSeam._reroute_scan()
	assert_true(not PlannerSeam._crews.has("Green_Asker"), "OFF: today's rules")
	assert_eq(int(PlannerSeam.reroute_report()["asks"]), 0, "no re-route asked")


func test_the_target_is_the_first_route_point_past_the_holder() -> void:
	var staged: Array = await _stage("hold", 5.0)
	var mover: Movement = staged[1]
	var target: Array = PlannerSeam._reroute_target(mover, _lab.tank_of("Green_Holder"))
	assert_true(not target.is_empty(), "a route point past the holder")
	var point: Vector3 = target[0]
	var clear := 0.5 * (float(Movement.hull_box("gang_artillery")[2]) + float(Movement.hull_box("tank")[2])) + PlannerSeam.REROUTE_PAST_M
	print("MEASURE reroute target %s (route %s from %d, goal %s; clear %.1f m)" % [point, mover._path, mover._path_index, mover._goal, clear])
	assert_true(point.z < 0.0, "past the holder along the asker's way (north of the origin): %s" % point)
	assert_true(Movement._flat_distance(point, Vector3.ZERO) >= clear, "clear of both hulls: %s" % point)
	assert_true(Vector3(target[1]).z < 0.0, "heading the route's way")


func test_on_a_wedged_wheeled_asker_held_for_is_taken() -> void:
	Traffic.set_off("reroute", false)
	assert_true(PlannerSeam.reroute_on(), "setup: the planner is on")
	var staged: Array = await _stage("hold", 5.0)
	PlannerSeam._reroute_scan()
	assert_true(PlannerSeam._crews.has("Green_Asker"), "the seam holds the asker")
	assert_true(PlannerSeam._rerouted.has("Green_Asker"), "as a re-route")
	assert_eq(int(PlannerSeam.reroute_report()["asks"]), 1, "one ask")
	PlannerSeam._reroute_scan()
	assert_eq(int(PlannerSeam.reroute_report()["asks"]), 1, "a crew the seam holds is never asked twice")


func test_on_a_still_asker_is_not_taken() -> void:
	Traffic.set_off("reroute", false)
	var staged: Array = await _stage("hold", 1.0)
	PlannerSeam._reroute_scan()
	assert_true(not PlannerSeam._crews.has("Green_Asker"), "stalled 1 s < CHAIN_RELEASE_S: not wedged")


func test_on_a_side_step_is_not_a_hold() -> void:
	Traffic.set_off("reroute", false)
	var staged: Array = await _stage("side", 5.0)
	PlannerSeam._reroute_scan()
	assert_true(not PlannerSeam._crews.has("Green_Asker"), "the holder is stepping aside: the way opens without a plan")
	Traffic.set_off("rerouteany", false)
	PlannerSeam._reroute_scan()
	assert_true(PlannerSeam._crews.has("Green_Asker"), "=any: round any crew giving way to it")


func test_on_a_tracked_asker_is_not_taken() -> void:
	Traffic.set_off("reroute", false)
	var staged: Array = await _stage("hold", 5.0, "tank")
	PlannerSeam._reroute_scan()
	assert_true(not PlannerSeam._crews.has("Green_Asker"), "the lattice planner plans wheeled hulls only")


func test_on_the_planned_asker_drives_round_the_holder() -> void:
	Traffic.set_off("reroute", false)
	var staged: Array = await _stage("hold", 5.0)
	var asker := _lab.tank_of("Green_Asker")
	PlannerSeam._reroute_scan()
	var passed := false
	for i in 30 * SimClock.TICK_RATE:
		await _lab.step()
		if asker.global_position.z < -4.0:
			passed = true
			break
	var report := PlannerSeam.reroute_report()
	print("MEASURE reroute drive: %s, asker at %s | last abandoned %s | plans %s" % [report, asker.global_position,
			PlannerSeam.last_abandoned, PlannerSeam.last_plans])
	assert_true(int(report["outcomes"].get("planned", 0)) >= 1, "a plan landed: %s" % report)
	assert_true(int(report["pack_ticks"]) > 0, "the battery dug in while its search ran, and its leg waited for the legs")
	assert_true(passed, "the asker got past the holder: %s" % asker.global_position)


## Measurement: the re-route's whole search at BUDGET, unsliced (how many expansions the stage's plan takes).
func test_measure_the_search_unsliced() -> void:
	var staged: Array = await _stage("hold", 5.0)
	var mover: Movement = staged[1]
	var target: Array = PlannerSeam._reroute_target(mover, _lab.tank_of("Green_Holder"))
	var plan := Planner.plan(PlannerSeam.reroute_req(mover, target[0], target[1]))
	print("MEASURE reroute search unsliced: code %s expansions %d legs %d metres %.1f | %s" % [plan.code, plan.expansions,
			plan.legs.size(), plan.metres, plan.describe()])
	assert_true(plan.code != "", "a search ran")


## Until the leg rule is twinned in drive_native.cpp, ON runs the GDScript drive (as chainside runs the GDScript asks); OFF
## leaves native_drive as it was.
func test_on_runs_the_gdscript_drive_until_twinned() -> void:
	var before := BrainSwitches.native_drive
	Traffic.set_off("reroute", false)
	assert_true(not BrainSwitches.native_drive, "ON: the GDScript drive")
	Traffic.set_off("reroute", true)
	assert_eq(BrainSwitches.native_drive, before, "OFF: native_drive back as it was")
