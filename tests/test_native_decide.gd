extends TestCase
## Round 24 (native, N3d): `TankBrain.decide` natively (NativeDecide -> TankNative.decide) is the live GDScript's: two
## doctrine teams of mixed units (scouts and artillery among them) fight on the Sumps; every few ticks every living
## brain's situation is decided both ways, as built and in mutated copies that reach the branches a skirmish rarely
## hits (each order verb through _obey, a commanded squad under each drill verb, cooldowns, a recent flip, the matchups
## variant, an empty gun, the control point, a blocked lane). The decisions must be equal (`==`, deep: the choice and
## the ranked three with their snapped scores).

const MATCH := preload("res://game/match/match.tscn")
const VERBS: Array[String] = ["move", "stop", "hold", "follow", "attack", "attack_move", "idle"]
const DRILLS: Array[String] = ["move", "bound", "hold", "assault", "break_contact"]


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


## A copy of `s` reaching branch family `n`.
func _mutate(s: Dictionary, current: Dictionary, n: int, rng: RandomNumberGenerator) -> Array:
	var m := s.duplicate(true)
	var cur := current.duplicate(true)
	var here: Vector3 = m["self"]["position"]
	var contacts: Array = m["contacts"]
	var first_name: String = String((contacts[0] as Dictionary)["name"]) if not contacts.is_empty() else ""
	match n % 8:
		0:
			var verb: String = VERBS[rng.randi_range(0, VERBS.size() - 1)]
			m["order"] = {"verb": verb, "target": first_name if rng.randf() < 0.6 else "",
					"goal": here + Vector3(20.0, 0.0, -10.0) if rng.randf() < 0.8 else null, "target_alive": rng.randf() < 0.7}
		1:
			m["squad"] = {"slot": here + Vector3(rng.randf_range(-8.0, 8.0), 0.0, rng.randf_range(-8.0, 8.0)),
					"verb": DRILLS[rng.randi_range(0, DRILLS.size() - 1)], "moving": rng.randf() < 0.5,
					"overwatch": rng.randf() < 0.3}
		2:
			m["cooldowns"] = {"ENGAGE": int(m["tick"]) + 30, "ADVANCE": int(m["tick"]) + 30, "HOLD": int(m["tick"]) - 1}
			if first_name != "":
				m["left"] = {"option": "ENGAGE", "target": first_name, "tick": int(m["tick"]) - 10}
		3:
			m["features"]["matchups"] = true
			m["features"]["suppress_proxy"] = true
		4:
			m["self"]["ammo"] = 0 if rng.randf() < 0.5 else 1
			m["self"]["max_ammo"] = 10
			m["self"]["in_resupply_zone"] = rng.randf() < 0.5
			m["self"]["health"] = int(float(m["self"]["max_health"]) * rng.randf_range(0.05, 0.5))
		5:
			m["control"] = {"center": here + Vector3(5.0, 0.0, 5.0), "radius": 20.0, "owner": rng.randi_range(-1, 1)}
		6:
			m["self"]["lane_blocked_ticks"] = 30
			if first_name != "":
				cur = {"option": "ENGAGE", "target": first_name}
		7:
			for c: Dictionary in contacts:
				c["pinned"] = rng.randf() < 0.5
				c["suppression"] = rng.randf()
			if first_name != "":
				cur = {"option": ["SUPPRESS", "ORBIT", "COVER_FIRE", "RECHARGE"][rng.randi_range(0, 3)], "target": first_name}
	return [m, cur]


func test_decide_is_the_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the decide equality is not exercised in this run")
		return
	assert_true(NativeDecide.configure(), "the native decide takes the live constants")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "scout", "artillery"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2408
	var saved := BrainSwitches.native_decide
	var asked := 0
	var live_usec := 0
	var native_usec := 0
	var options := {}
	var mismatches := 0
	var first := ""
	for frame in 600:
		await wait_physics_frames(1)
		if frame % 5 != 4:
			continue
		for node in game_match.brains.get_children():
			var brain := node as TankBrain
			if brain == null or brain.tank == null or not brain.tank.is_alive():
				continue
			var s := brain.build_situation()
			var cases := [[s, brain.choice.duplicate()]]
			for n in 2:
				cases.append(_mutate(s, brain.choice, asked + n, rng))
			for pair: Array in cases:
				BrainSwitches.native_decide = false
				var t0 := Time.get_ticks_usec()
				var live := TankBrain.decide(pair[0], pair[1])
				live_usec += Time.get_ticks_usec() - t0
				BrainSwitches.native_decide = true
				t0 = Time.get_ticks_usec()
				var native := TankBrain.decide(pair[0], pair[1])
				native_usec += Time.get_ticks_usec() - t0
				asked += 1
				var option := String(live["choice"]["option"])
				options[option] = int(options.get(option, 0)) + 1
				if live != native:
					mismatches += 1
					if first == "":
						first = "frame %d %s: live %s, native %s" % [frame, brain.tank.name, var_to_str(live).left(500),
								var_to_str(native).left(500)]
	BrainSwitches.native_decide = saved
	print("native decide: %.1f usec a decide live, %.1f native" % [float(live_usec) / maxi(asked, 1), float(native_usec) / maxi(asked, 1)])
	print("native decide: %d decisions, %d mismatches, chosen %s" % [asked, mismatches, options])
	assert_eq(mismatches, 0, "the native decide is the GDScript's: %s" % first)
	assert_true(asked >= 1500 and options.size() >= 10, "a real sample (%d decisions, %d options chosen)" % [asked, options.size()])
