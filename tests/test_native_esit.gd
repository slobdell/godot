extends TestCase
## Round 47 (native N4, R47.19): ElementSituation._entries natively (NativeEsit -> esit_native.cpp) against its LIVE GDScript, bit
## for bit (var_to_bytes), on a fighting match: every few ticks, for both teams, random member subsets (whole squads, mixed, a name
## that is dead or missing), headings including none, and a `known` memory both empty and carried from the last read.

const MATCH := preload("res://game/match/match.tscn")


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


func test_native_esit_is_the_live_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the esit equality is not exercised in this run")
		return
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "tank"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4719
	var compared := 0
	var mismatches := 0
	var with_contacts := 0
	var first := ""
	var known := [{}, {}]
	for frame in 400:
		await wait_physics_frames(1)
		if frame % 4 != 0:
			continue
		for team in 2:
			var names := PackedStringArray()
			for node in game_match.tanks.get_children():
				var tank := node as Tank
				if tank != null and tank.team == team and rng.randf() < 0.7:
					names.append(String(tank.name))
			if rng.randf() < 0.2:
				names.append("Nobody_9")
			var heading := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) if rng.randf() < 0.8 else Vector3.ZERO
			var state := {"heading": heading, "known": known[team] if rng.randf() < 0.7 else {}}
			var live := ElementSituation._entries(game_match, team, names, state)
			var native: Dictionary = NativeBridge.impl.esit_entries(game_match, team, names, heading, state["known"],
					NativeEsit._role_table(), NativeEsit.consts())
			known[team] = live["known"]
			compared += 1
			with_contacts += 1 if not (live["contacts"] as Array).is_empty() else 0
			if var_to_bytes(live) != var_to_bytes(native):
				mismatches += 1
				if first == "":
					first = "frame %d team %d: live %s native %s" % [frame, team, var_to_str(live).left(600), var_to_str(native).left(600)]
	print("MEASURE native_esit compared=%d mismatches=%d with_contacts=%d" % [compared, mismatches, with_contacts])
	assert_eq(mismatches, 0, "native _entries = the GDScript (%d); first: %s" % [compared, first])
	assert_true(compared >= 150 and with_contacts >= 30, "a real sample (%d, %d with contacts)" % [compared, with_contacts])
