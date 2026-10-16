extends "res://tests/tactics/pursuit_case.gd"
## Round 32 (C32.8 / R31.9): split from one slow file; what its tests share is in tests/tactics/pursuit_case.gd.


func test_one_failed_line_fails_the_run() -> void:
	var good := {"closing_worst_m": -12.0, "closing_at": "", "let_go_at": "", "reversal_worst_deg": 50.0, "reversal_at": ""}
	assert_eq(pursuit_fails(good), "", "every line held: a pass")
	for bad: Dictionary in [{"closing_worst_m": 2.1}, {"let_go_at": "15.0 s"}, {"reversal_worst_deg": 121.0}]:
		var run := good.duplicate()
		run.merge(bad, true)
		assert_true(pursuit_fails(run) != "", "%s alone fails the run" % bad)


## The mutation check of found_again (the orchestrator's): it must fail on a kill by someone outside the squad and on a
## target that lives far away; it passes on a kill by the squad's own crew or a squad that ends on it.
func test_finding_it_again_is_a_kill_by_this_squad_or_ending_on_it() -> void:
	var squad := ["Green_A_1", "Green_A_2", "Green_A_3"]
	assert_true(found_again({"squad": squad, "killed_by": "Green_A_3", "center_to_target_m": -1.0}), "this squad killed it")
	assert_true(found_again({"squad": squad, "killed_by": "", "center_to_target_m": 12.0}), "alive, the squad on it")
	assert_true(not found_again({"squad": squad, "killed_by": "Green_B_1", "center_to_target_m": -1.0}),
			"dead by another squad's hand: not found")
	assert_true(not found_again({"squad": squad, "killed_by": "", "center_to_target_m": 75.0}), "alive and far: not found")
	assert_true(not found_again({"squad": squad, "killed_by": "", "center_to_target_m": -1.0}), "dead by no one's: not found")


func test_a_target_that_drives_out_of_sight_is_followed_not_given_up() -> void:
	var result: Dictionary = await _pursue(18.0, 40.0, 3, 60.0, "law_tank")
	print("MEASURE pursuit %s seed 3 five Law tanks v a spotter at 18 m/s out of sight: %s" % [ARENA, result])
	assert_true(float(result["forgotten_s"]) >= 3.0, "the stage does take it out of intel (%s s)" % result["forgotten_s"])
	assert_eq(float(result["arrived_s"]), 0.0, "the squad never reports arrived while it lives")
	assert_true(found_again(result), "and finds it again: killed by this squad, or the squad ends within 40 m of it (%s m, killed by '%s')"
			% [result["center_to_target_m"], result["killed_by"]])
	# Not asserted here: the 120-degree turn. Out of sight the target turned twice and the track carried it straight on,
	# so a crew that sees it again off to its side turns round ONCE to it (164 degrees, seed 3, laptop): a wrong guess
	# corrected, not a circle. The orbit is measured on the visible chases above.


func test_the_pursuit_point_is_the_last_sighting_carried_forward_then_held() -> void:
	var track := {"name": "Rust_Eyes_1", "position": Vector3(0, 0, -20), "velocity": Vector3(0, 0, -8), "seen_tick": 300}
	assert_eq(ElementPlan.pursuit_point(track, 300), Vector3(0, 0, -20), "seen this tick: where it is")
	var later: Vector3 = ElementPlan.pursuit_point(track, 300 + SimClock.TICK_RATE * 2)
	assert_near(later.z, -36.0, 0.01, "2 s out of sight at 8 m/s: 16 m on")
	var long_gone: Vector3 = ElementPlan.pursuit_point(track, 300 + SimClock.TICK_RATE * 60)
	var capped: Vector3 = ElementPlan.pursuit_point(track, 300 + int(SimClock.TICK_RATE * ElementPlan.PURSUIT_MEMORY_S))
	assert_eq(long_gone, capped, "the memory ends at PURSUIT_MEMORY_S: never back to the old spot, never on forever")
	assert_eq(ElementPlan.pursuit_point({}, 300), null, "no track, no point")


func test_an_attack_on_a_running_or_unseen_target_is_a_pursuit_and_stays_one() -> void:
	var task := {"verb": "attack", "target": "Rust_Eyes_1"}
	var seen := {"tick": 300, "contacts": [{"name": "Rust_Eyes_1", "position": Vector3(0, 0, -40), "visible": true}]}
	var running := {"name": "Rust_Eyes_1", "position": Vector3(0, 0, -40), "velocity": Vector3(0, 0, -8), "seen_tick": 300}
	var parked := running.duplicate()
	parked["velocity"] = Vector3.ZERO
	assert_true(ElementPlan.pursues(task, {"pursuit": running}, seen), "a running target: a pursuit")
	assert_true(not ElementPlan.pursues(task, {"pursuit": parked}, seen), "a parked target in sight: an attack as before")
	assert_true(ElementPlan.pursues(task, {"pursuit": parked}, {"tick": 300, "contacts": []}), "out of sight: a pursuit")
	assert_true(ElementPlan.pursues(task, {"pursuit": parked, "pursuing": true}, seen), "sticky for the task")
	assert_true(not ElementPlan.pursues({"verb": "attack", "to": [0, -40]}, {"pursuit": running}, seen), "a point: no")
	assert_true(not ElementPlan.pursues({"verb": "attack", "target": "Rust_2"}, {"pursuit": running}, seen),
			"a track of another vehicle is not this target's")


func test_a_squad_of_one_drives_straight_at_it_and_a_squad_lays_its_shape_ahead_of_it() -> void:
	var table: DoctrineTable = DoctrineTable.load_table("gangs")["table"]
	var track := {"name": "Rust_Eyes_1", "position": Vector3(0, 0, -80), "velocity": Vector3(8, 0, 0), "seen_tick": 300}
	var state := {"task": {"verb": "attack", "target": "Rust_Eyes_1", "formation": "vee"}, "pursuit": track,
			"pursuing": true, "heading": Vector3.FORWARD}
	var one := _situation(1)
	var plan := ElementPlan.build(one, state.duplicate(true), table)
	assert_eq(plan["orders"]["Green_1"]["verb"], "attack", "alone: straight at it (%s)" % plan["orders"])
	assert_eq(plan["orders"]["Green_1"]["target"], "Rust_Eyes_1", "at the one it was told")
	assert_true(not bool(plan["arrived"]), "never arrived short")
	var five := ElementPlan.build(_situation(5), state.duplicate(true), table)
	assert_true(not bool(five["arrived"]), "a pursuing squad never arrives outside its reach")
	for unit_name: String in five["orders"]:
		var order: Dictionary = five["orders"][unit_name]
		assert_eq(order["verb"], "attack_move", "%s drives for its station on an attack-move" % unit_name)
		assert_eq(order["target"], "Rust_Eyes_1", "%s: naming the target" % unit_name)
	var ahead := 0
	for unit_name: String in five["slots"]:
		if (five["slots"][unit_name] as Vector3).x > 4.0:
			ahead += 1
	assert_true(ahead >= 3, "the shape is laid where it is going (led to +x): %s" % five["slots"])


func test_the_contact_drills_give_way_to_a_pursuit_but_an_ambush_by_another_does_not() -> void:
	var table: DoctrineTable = DoctrineTable.load_table("standard")["table"]
	var running := {"name": "Rust_1", "visible": true, "distance": 60.0, "age": 500, "position": Vector3(0, 0, -60)}
	var task := {"verb": "attack", "target": "Rust_1"}
	var situation := _situation(4, [running], "contact")
	assert_eq(Drills.select(situation, {"task": task, "pursuing": false}, table)["drill"], "react_to_contact",
			"an attack that is not a pursuit reacts to contact as before")
	assert_eq(Drills.select(situation, {"task": task, "pursuing": true}, table)["drill"], "",
			"a pursuit does not stop to react to the target it is chasing")
	var far := Drills.select(situation, {"task": task, "pursuing": true, "drill": "far_ambush", "drill_tick": 990,
			"drill_why": "far ambush"}, table)
	assert_eq(far["drill"], "", "a far ambush already running stops")
	var popped := running.duplicate()
	popped["distance"] = 30.0
	popped["age"] = 0
	popped["position"] = Vector3(0, 0, -30)
	assert_true(Drills.select(_situation(4, [popped], "contact"), {"task": task, "pursuing": true}, table)["drill"] \
			!= "near_ambush", "the target coming back into sight is not an ambush")
	var stranger := popped.duplicate()
	stranger["name"] = "Rust_9"
	assert_eq(Drills.select(_situation(4, [stranger, running], "contact"), {"task": task, "pursuing": true}, table)["drill"],
			"near_ambush", "a sudden enemy who is not the target is still an ambush")


func test_a_brain_chases_the_target_it_was_told_to_kill_when_it_runs() -> void:
	var spear := Weapons.profile("spear_gun")
	var me := Vector3.ZERO
	var running := {"name": "Rust_1", "position": Vector3(0, 0, -40), "velocity": Vector3(0, 0, -8)}
	assert_true(TankBrain.chases({"verb": "attack", "target": "Rust_1"}, running, me, spear), "running beyond the band")
	assert_true(TankBrain.chases({"verb": "attack_move", "target": "Rust_1"}, running, me, spear), "a named attack-move")
	assert_true(not TankBrain.chases({"verb": "attack_move", "target": ""}, running, me, spear), "an unnamed attack-move")
	assert_true(not TankBrain.chases({"verb": "attack", "target": "Rust_2"}, running, me, spear), "another target")
	var close := running.duplicate()
	close["position"] = Vector3(0, 0, -20)
	assert_true(not TankBrain.chases({"verb": "attack", "target": "Rust_1"}, close, me, spear), "inside the band: fight")
	var coming := running.duplicate()
	coming["velocity"] = Vector3(0, 0, 8)
	assert_true(not TankBrain.chases({"verb": "attack", "target": "Rust_1"}, coming, me, spear), "closing on us: fight")
