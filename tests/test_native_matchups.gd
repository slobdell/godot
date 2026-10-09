extends TestCase
## Round 24 (native, N3d): `TankBrain.matchups_for` natively (NativeMatchups, with Matchups' math and Armor.facing
## ported) is the live GDScript's on real situations: two doctrine teams of mixed units fight on the Sumps, every
## brain's situation is built every few ticks, and matchups_for (and the whole decide that reads it) is asked both ways:
## the Dictionaries must be equal (`==`, deep, key order included). The C++'s copies of matchups.gd's and armor.gd's
## constants are held to the live ones.

const MATCH := preload("res://game/match/match.tscn")


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


func test_the_constants_are_the_live_ones() -> void:
	if not NativeBridge.available:
		print("native: absent, the matchups constants are not exercised in this run")
		return
	assert_eq(NativeBridge.impl.matchups_constants(), NativeMatchups.live_constants(),
			"matchups_native.cpp's constants are matchups.gd's and armor.gd's")


func test_matchups_and_decide_are_the_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the matchups equality is not exercised in this run")
		return
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "scout"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	var saved := BrainSwitches.native_matchups
	var asked := 0
	var entries := 0
	var orbits := 0
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
			var current := brain.choice.duplicate()
			BrainSwitches.native_matchups = false
			var live := TankBrain.matchups_for(s)
			var live_decision := TankBrain.decide(s, current)
			BrainSwitches.native_matchups = true
			var native := TankBrain.matchups_for(s)
			var native_decision := TankBrain.decide(s, current)
			asked += 1
			entries += live.size()
			# The orbit branch: the same situation seen by a fixed-gun scout with its contacts pulled into reach, some
			# of them slow turrets (tank 50 deg/s, lancer 55), half the time seeking the engine deck.
			if not (s["contacts"] as Array).is_empty():
				var o := s.duplicate(true)
				var scout := "scout" if frame % 2 == 0 else "gang_scout"
				o["self"]["unit"] = scout
				o["self"]["weapon"] = Weapons.profile(String(Units.stat(scout, "weapon", "")))
				o["features"]["weak_spots"] = frame % 4 < 2
				var here: Vector3 = o["self"]["position"]
				var k := 0
				for c: Dictionary in o["contacts"]:
					var angle := float(k) * 1.3 + float(frame) * 0.1
					c["position"] = here + Vector3(cos(angle), 0.0, sin(angle)) * (8.0 + 6.0 * float(k % 4))
					c["unit"] = ["tank", "lancer", "ifv"][k % 3]
					c["age"] = 0
					k += 1
				BrainSwitches.native_matchups = false
				var live_orbit := TankBrain.matchups_for(o)
				BrainSwitches.native_matchups = true
				var native_orbit := TankBrain.matchups_for(o)
				for entry: Dictionary in live_orbit.values():
					orbits += 1 if entry["orbit"] else 0
				if live_orbit != native_orbit:
					mismatches += 1
					if first == "":
						first = "orbit case frame %d: live %s, native %s" % [frame, var_to_str(live_orbit).left(300), var_to_str(native_orbit).left(300)]
			for entry: Dictionary in live.values():
				orbits += 1 if entry["orbit"] else 0
			if live != native or live_decision != native_decision:
				mismatches += 1
				if first == "":
					first = "frame %d %s: live %s / %s, native %s / %s" % [frame, brain.tank.name, var_to_str(live).left(300),
							var_to_str(live_decision).left(200), var_to_str(native).left(300), var_to_str(native_decision).left(200)]
	BrainSwitches.native_matchups = saved
	print("native matchups: %d situations, %d matchup entries (%d orbit), %d mismatches" % [asked, entries, orbits, mismatches])
	assert_eq(mismatches, 0, "the native matchups (and the decide that reads them) are the GDScript's: %s" % first)
	assert_true(asked >= 500 and entries >= 500 and orbits >= 100, "a real sample (%d situations, %d entries, %d orbit)" % [asked, entries, orbits])
