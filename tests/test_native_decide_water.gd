extends TestCase
## Round 43 (native N3, engage A7 `--engage-water=on`; C43.4): the native decide's `_obey` (decide_native.cpp `obey`) skips a
## contact across water exactly as TankBrain._obey does. A Sumps fight's situations, each put under an attack-move with
## contacts in sight within reach, are decided both ways with ENGAGE_WATER on and off; the water test is the brain's own
## seam (TankBrain.water_between: contacts east of the crew are "across water"), so both paths ask the same question.

const MATCH := preload("res://game/match/match.tscn")


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


func test_the_water_skip_is_the_gdscript() -> void:
	if FreshStage.parent(self, "test_the_water_skip_is_the_gdscript"):  # its own process (tests/native/fresh_stage.gd)
		return
	if NativeExpect.absent(self):
		print("native: absent, the water skip's equality is not exercised in this run")
		return
	assert_true(NativeDecide.configure(), "the native decide takes the live constants")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "scout", "artillery"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4307
	var saved_native := BrainSwitches.native_decide
	var saved_water := TankBrain.ENGAGE_WATER
	var saved_seam := TankBrain.water_between
	TankBrain.water_between = func(from: Vector3, to: Vector3) -> bool: return to.x > from.x
	var asked := 0
	var mismatches := 0
	var changed := 0  # cases where the skip changed the GDScript's decision (so the twin's skip is exercised)
	var first := ""
	for frame in 300:
		await wait_physics_frames(1)
		if frame % 5 != 4:
			continue
		for node in game_match.brains.get_children():
			var brain := node as TankBrain
			if brain == null or brain.tank == null or not brain.tank.is_alive():
				continue
			var s := brain.build_situation()
			var here: Vector3 = s["self"]["position"]
			var reach := float(s["self"]["weapon"]["range"]) + TankBrain.ATTACK_MOVE_REACH_MARGIN
			var m := s.duplicate(true)
			m["order"] = {"verb": "attack_move", "target": "", "goal": here + Vector3(0.0, 0.0, -40.0), "target_alive": true}
			for c: Dictionary in m["contacts"]:
				if rng.randf() < 0.8:
					c["visible"] = true
					var angle := rng.randf_range(0.0, TAU)
					c["position"] = here + Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(5.0, reach * 1.1)
			var decided := {}
			for water in [false, true]:
				TankBrain.ENGAGE_WATER = water
				BrainSwitches.native_decide = false
				var live := TankBrain.decide(m, brain.choice.duplicate())
				BrainSwitches.native_decide = true
				var native := TankBrain.decide(m, brain.choice.duplicate())
				asked += 1
				decided[water] = live
				if live != native:
					mismatches += 1
					if first == "":
						first = "frame %d %s water %s: live %s, native %s" % [frame, brain.tank.name, water,
								var_to_str(live).left(400), var_to_str(native).left(400)]
			if decided[false] != decided[true]:
				changed += 1
	BrainSwitches.native_decide = saved_native
	TankBrain.ENGAGE_WATER = saved_water
	TankBrain.water_between = saved_seam
	print("native decide water: %d decisions, %d mismatches, %d cases the skip changed" % [asked, mismatches, changed])
	assert_eq(mismatches, 0, "the native decide's water skip is the GDScript's: %s" % first)
	assert_true(changed >= 20, "the skip changed decisions (%d): the twin's skip was exercised" % changed)
	assert_true(asked >= 600, "a real sample (%d decisions)" % asked)
