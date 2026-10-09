extends TestCase
## Round 24 (native, C24.6): `TacticalQuery.find_cover` and `find_cover_fire` natively (NativeTq -> tq_native.cpp) are the
## live GDScript's, asked both ways on the Sumps' real cover map: random requests (one to six weighted threats, a target,
## range bands, search radii, anchors, friends crowding the candidates) and requests built from a real fight the way
## TankBrain builds them (its threat_list, its nearest visible contact, its weapon's band, its allies). The answers must be
## equal (`==`, deep: the points, the snapped scores, the peek spots, key order included).

const MATCH := preload("res://game/match/match.tscn")


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


func _ask(map: CoverMap, request: Dictionary) -> Array:
	var saved := BrainSwitches.native_tq
	BrainSwitches.native_tq = false
	var live_cover := TacticalQuery.find_cover(map, request)
	var live_fire := TacticalQuery.find_cover_fire(map, request)
	BrainSwitches.native_tq = true
	var native_cover := TacticalQuery.find_cover(map, request)
	var native_fire := TacticalQuery.find_cover_fire(map, request)
	BrainSwitches.native_tq = saved
	return [live_cover, native_cover, live_fire, native_fire]


func test_the_queries_are_the_live_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the tactical query equality is not exercised in this run")
		return
	assert_true(NativeTq.configure(), "the native queries take the live constants")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "tank"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	await wait_physics_frames(2)
	var map := CoverMap.of(game_match.tanks)
	var saved_tq := BrainSwitches.native_tq
	BrainSwitches.native_tq = true  # it ships OFF (its in-contact price); the proof asks it on
	assert_true(map != null and map._native != null and NativeTq.usable(map), "the Sumps' cover map has its native twin")
	BrainSwitches.native_tq = saved_tq
	var rng := RandomNumberGenerator.new()
	rng.seed = 2409
	var asked := 0
	var covers := 0
	var fires := 0
	var mismatches := 0
	var first := ""
	# Random requests over the whole map.
	for n in 400:
		var me := Vector3(rng.randf_range(-100.0, 100.0), 0.0, rng.randf_range(-100.0, 100.0))
		var threats := []
		for t in rng.randi_range(1, 7):
			threats.append({"position": me + Vector3(rng.randf_range(-70.0, 70.0), 0.0, rng.randf_range(-70.0, 70.0)),
					"weight": [1.0, 0.6][rng.randi_range(0, 1)]})
		var request := {"position": me, "threats": threats, "search_radius": rng.randf_range(15.0, 40.0),
				"target": (threats[0] as Dictionary)["position"], "range": [rng.randf_range(10.0, 30.0), rng.randf_range(35.0, 55.0), rng.randf_range(60.0, 90.0)]}
		if rng.randf() < 0.4:
			var friends := []
			for f in rng.randi_range(1, 5):
				friends.append(me + Vector3(rng.randf_range(-20.0, 20.0), 0.0, rng.randf_range(-20.0, 20.0)))
			request["friends"] = friends
		if rng.randf() < 0.3:
			request["anchor"] = me + Vector3(rng.randf_range(-10.0, 10.0), 0.0, rng.randf_range(-10.0, 10.0))
			request["anchor_radius"] = rng.randf_range(5.0, 20.0)
		var answers := _ask(map, request)
		asked += 1
		covers += 1 if not (answers[0] as Array).is_empty() else 0
		fires += 1 if not (answers[2] as Dictionary).is_empty() else 0
		if answers[0] != answers[1] or answers[2] != answers[3]:
			mismatches += 1
			if first == "":
				first = "random %d: cover %s v %s; fire %s v %s" % [n, var_to_str(answers[0]).left(200), var_to_str(answers[1]).left(200),
						var_to_str(answers[2]).left(200), var_to_str(answers[3]).left(200)]
	# Requests from a real fight, built as TankBrain builds them.
	for frame in 450:
		await wait_physics_frames(1)
		if frame % 15 != 14:
			continue
		for node in game_match.brains.get_children():
			var brain := node as TankBrain
			if brain == null or brain.tank == null or not brain.tank.is_alive():
				continue
			var s := brain.build_situation()
			var here: Vector3 = brain.tank.global_position
			var threats := TankBrain.threat_list(s["contacts"], here)
			if threats.is_empty():
				continue
			var target: Variant = null
			for c: Dictionary in s["contacts"]:
				if c["visible"]:
					target = c["position"]
					break
			var weapon: Dictionary = brain.tank.weapon
			var request := {"position": here, "threats": threats, "search_radius": TankBrain.COVER_SEARCH_RADIUS,
					"target": target, "range": [float(weapon["preferred_min"]), float(weapon["preferred_max"]), float(weapon["range"])],
					"friends": (s["allies"] as Array).map(func(ally: Dictionary) -> Vector3: return ally["position"])}
			var answers := _ask(map, request)
			asked += 1
			covers += 1 if not (answers[0] as Array).is_empty() else 0
			fires += 1 if not (answers[2] as Dictionary).is_empty() else 0
			if answers[0] != answers[1] or answers[2] != answers[3]:
				mismatches += 1
				if first == "":
					first = "fight frame %d %s: cover %s v %s; fire %s v %s" % [frame, brain.tank.name, var_to_str(answers[0]).left(200),
							var_to_str(answers[1]).left(200), var_to_str(answers[2]).left(200), var_to_str(answers[3]).left(200)]
	print("native tq: %d requests (%d found cover, %d found a hide/peek pair), %d mismatches" % [asked, covers, fires, mismatches])
	assert_eq(mismatches, 0, "the native tactical queries are the live GDScript's: %s" % first)
	assert_true(asked >= 600 and covers >= 100 and fires >= 50, "a real sample (%d asked, %d cover, %d fire)" % [asked, covers, fires])
