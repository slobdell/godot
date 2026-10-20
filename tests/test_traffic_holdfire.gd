extends TestCase
## Round 35 (traffic T8, R35.7; `--traffic-on=holdfire`, DEFAULT_OFF until judged): a crew held at a street mouth (T1's
## take-turns hold) that is being hit leaves the hold, as a passed crew does. Manoeuvre's W1 (24 fights): 33 of 81 wedged deaths
## were crews held at a mouth under fire, a median 5.4 s in. His Terminus head-on case (test_traffic_hold_live's) on the GDScript
## path; every crew holding is "hit" each tick by the stage's on_tick hook.

var _saved_native := false


func teardown() -> void:
	BrainSwitches.native = _saved_native
	Traffic.set_off("hold", false)
	Traffic.set_off("holdfire", Traffic.DEFAULT_OFF.has("holdfire"))
	super.teardown()


func _hit_the_held(lab: TacticsLab, _now: float) -> void:
	for node in lab.game_match.tanks.get_children():
		var tank := node as Tank
		if tank != null and tank.is_alive() and Traffic.holding(String(tank.name)):
			tank.ticks_since_hit = 0


func _run(on: bool) -> Dictionary:
	_saved_native = BrainSwitches.native
	BrainSwitches.native = false
	Traffic.set_off("hold", false)
	Traffic.set_off("holdfire", not on)
	return await TrafficStage.run(self, 1, "terminus", "head", "both", 30.0, "green", false, _hit_the_held)


func test_on_a_held_crew_being_hit_leaves_the_hold() -> void:
	var report := await _run(true)
	assert_true(int(report["tr_holds"]) > 0, "the waiting squad was still sent to its spots: %s" % report["tr_holds"])
	assert_true(int(report["tr_released_fire"]) > 0, "and its crews, hit while holding, were released: %s" % report["tr_released_fire"])


func test_off_a_held_crew_being_hit_holds_as_before() -> void:
	var report := await _run(false)
	assert_true(int(report["tr_hold_ticks"]) > 0, "held: %s crew-ticks" % report["tr_hold_ticks"])
	assert_eq(int(report["tr_released_fire"]), 0, "nobody released for fire with the switch off")
