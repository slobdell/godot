extends TestCase
## Round 24 (native, N4): `Movement._around_fire` natively (drive_native.cpp's around_fire, with ThreatField's reads in
## C++) is the live GDScript's. Two doctrine teams fight on the Sumps; the teams' incoming-fire grids are stamped with
## random lanes and bursts on top of the real fire, and every few ticks every living brain's mover is asked both ways
## from one snapshot, with random waypoints and goals, an escape order now and then, a sidestep already under way (or
## not), a controller stride, and SuppressionFeed's indirect answer (direct_calls off). The waypoint returned, every
## mover member and static (MoverState), the brain's feed memo and OrderController's detour counters must be equal.

const MATCH := preload("res://game/match/match.tscn")


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


func _state(mover: Movement) -> Dictionary:
	var state := MoverState.capture(mover)
	state["ctl._fields_match"] = mover.ctl._fields_match
	state["ctl._fields?"] = mover.ctl._fields != null
	state["ctl._stride"] = mover.ctl._stride
	state["oc.fire_detours"] = OrderController.fire_detours
	state["oc.fire_no_way_round"] = OrderController.fire_no_way_round
	return state


func _restore(mover: Movement, state: Dictionary) -> void:
	MoverState.restore(mover, state)
	mover.ctl._fields_match = state["ctl._fields_match"]
	mover.ctl._stride = state["ctl._stride"]
	OrderController.fire_detours = state["oc.fire_detours"]
	OrderController.fire_no_way_round = state["oc.fire_no_way_round"]


func _stamp(game_match: Match, rng: RandomNumberGenerator) -> void:
	for team in 2:
		var field := game_match.threat_field(team)
		for n in rng.randi_range(2, 6):
			var from := Vector3(rng.randf_range(-110.0, 110.0), 0.0, rng.randf_range(-110.0, 110.0))
			var to := from + Vector3(rng.randf_range(-80.0, 80.0), 0.0, rng.randf_range(-80.0, 80.0))
			field.stamp_segment(from, to, rng.randf_range(0.2, 2.5))
		if rng.randf() < 0.5:
			field.stamp_burst(Vector3(rng.randf_range(-100.0, 100.0), 0.0, rng.randf_range(-100.0, 100.0)),
					rng.randf_range(4.0, 20.0), rng.randf_range(0.3, 1.5))


func test_around_fire_is_the_live_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the around-fire equality is not exercised in this run")
		return
	assert_true(NativeDrive.fire_ready(), "the native drive takes _around_fire's constants and scripts")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "tank"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2410
	var saved_direct := BrainSwitches.direct_calls
	var asked := 0
	var mismatches := 0
	var first := ""
	var detoured := 0
	var kept := 0
	var no_way := 0
	var indirect := 0
	for frame in 420:
		await wait_physics_frames(1)
		if frame % 30 == 0:
			_stamp(game_match, rng)
		if frame % 6 != 5:
			continue
		for node in game_match.brains.get_children():
			var brain := node as TankBrain
			if brain == null or brain.tank == null or not brain.tank.is_alive():
				continue
			var mover := Movement.of(brain.tank)
			var here := brain.tank.global_position
			for n in 3:
				var waypoint := here + Vector3(rng.randf_range(-40.0, 40.0), 0.0, rng.randf_range(-40.0, 40.0))
				var goal := waypoint + Vector3(rng.randf_range(-30.0, 30.0), 0.0, rng.randf_range(-30.0, 30.0)) if rng.randf() < 0.7 else waypoint
				var order := {"type": "move_to", "x": goal.x, "z": goal.z}
				if rng.randf() < 0.1:
					order["to_safety"] = true
				var start := _state(mover)
				# The state to ask from: a sidestep under way (or not), the clocks around it, a stride, the feed memo cold.
				var setup := rng.randi_range(0, 5)
				if setup == 1:
					mover._fire_detour = here + Vector3(rng.randf_range(-20.0, 20.0), 0.0, rng.randf_range(-20.0, 20.0))
					mover._fire_detour_since = game_match.tick - rng.randi_range(0, 30)
					mover._fire_detour_until = game_match.tick + rng.randi_range(-10, 60)
					mover._fire_since = game_match.tick - rng.randi_range(-1, 200) if rng.randf() < 0.7 else -1
				elif setup == 2:
					mover.ctl._stride = rng.randi_range(2, 4)
					mover._fire_checked_tick = game_match.tick - rng.randi_range(0, 6)
				elif setup == 3:
					mover._fire_detour_again = game_match.tick + rng.randi_range(-5, 30)
				elif setup == 4:
					mover.ctl._fields_match = 0
				var asked_from := _state(mover)
				var direct := rng.randf() >= 0.15
				BrainSwitches.direct_calls = direct
				indirect += 0 if direct else 1
				var live: Vector3 = mover._around_fire(waypoint, goal, order)
				var live_state := _state(mover)
				_restore(mover, asked_from)
				var native := NativeDrive.around_fire(mover, waypoint, goal, order)
				var native_state := _state(mover)
				BrainSwitches.direct_calls = saved_direct
				_restore(mover, start)
				asked += 1
				if live != waypoint:
					if live_state.get("_fire_detour") == null:
						pass
					elif asked_from.get("_fire_detour") != null and live == asked_from["_fire_detour"]:
						kept += 1
					else:
						detoured += 1
				if live_state["oc.fire_no_way_round"] != asked_from["oc.fire_no_way_round"]:
					no_way += 1
				var differ := MoverState.diff(live_state, native_state)
				if live != native or differ != "":
					mismatches += 1
					if first == "":
						first = "frame %d %s setup %d: live %s native %s; %s" % [frame, brain.tank.name, setup, live, native, differ.left(500)]
	BrainSwitches.direct_calls = saved_direct
	print("native fire: %d asked (%d new sidesteps, %d kept, %d no way round, %d indirect), %d mismatches" % [asked, detoured,
			kept, no_way, indirect, mismatches])
	assert_eq(mismatches, 0, "the native _around_fire is the live GDScript's: %s" % first)
	assert_true(asked >= 2000 and detoured >= 30 and kept >= 20 and no_way >= 5 and indirect >= 100,
			"a real sample (%d asked, %d sidesteps, %d kept, %d no way round, %d indirect)" % [asked, detoured, kept, no_way, indirect])
