extends TestCase
## Round 24 (native, N3d): `TankBrain.build_situation()` with its first part native (NativeSituation: the allies, which
## contacts to look at, each contact's entry) is the GDScript's, on real brains in a real fight: two doctrine teams of
## mixed units on the Sumps fight for a while, and at every few ticks each living brain builds its situation twice,
## native and GDScript, and the two Dictionaries must be equal (`==`, deep: every key in order, every float's bits).

const MATCH := preload("res://game/match/match.tscn")


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


func test_the_situation_is_the_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the situation equality is not exercised in this run")
		return
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "tank"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	var saved := BrainSwitches.native_situation
	var built := 0
	var live_usec := 0
	var native_usec := 0
	var with_contacts := 0
	var many := 0
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
			BrainSwitches.native_situation = false
			var t0 := Time.get_ticks_usec()
			var gdscript := brain.build_situation()
			live_usec += Time.get_ticks_usec() - t0
			BrainSwitches.native_situation = true
			t0 = Time.get_ticks_usec()
			var native := brain.build_situation()
			native_usec += Time.get_ticks_usec() - t0
			built += 1
			with_contacts += 1 if not (gdscript["contacts"] as Array).is_empty() else 0
			many += 1 if (game_match.intel[brain.tank.team] as Dictionary).size() > TankBrain.MAX_CONTACTS else 0
			if gdscript != native:
				mismatches += 1
				if first == "":
					for key: String in gdscript:
						if not native.has(key) or gdscript[key] != native[key]:
							first = "frame %d %s: key %s: gdscript %s, native %s" % [frame, brain.tank.name, key,
									var_to_str(gdscript[key]).left(400), var_to_str(native.get(key)).left(400)]
							break
					if first == "":
						first = "frame %d %s: the key order differs" % [frame, brain.tank.name]
	BrainSwitches.native_situation = saved
	print("native situation: %.1f usec a build_situation live, %.1f with the native core (second arm: memos warm)" % [
			float(live_usec) / maxi(built, 1), float(native_usec) / maxi(built, 1)])
	print("native situation: %d situations built (%d with contacts, %d over MAX_CONTACTS), %d mismatches" % [built,
			with_contacts, many, mismatches])
	assert_eq(mismatches, 0, "the native situation is the GDScript's: %s" % first)
	assert_true(built >= 500 and with_contacts >= 100, "a real sample (%d built, %d with contacts)" % [built, with_contacts])
