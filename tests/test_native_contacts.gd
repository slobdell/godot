extends TestCase
## Round 48 (native N2): AiTickCache._contact_table natively (NativeContacts -> contacts_native.cpp) against its LIVE GDScript, bit for
## bit (var_to_bytes), on a fighting match: both teams every intel refresh, green on the champion (reload windows + the remembered
## suppression ON), rust on a6 (both OFF), so every branch of the prototype is read; and the suppression memory both write.

const MATCH := preload("res://game/match/match.tscn")


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


func test_native_contacts_is_the_live_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the contacts equality is not exercised in this run")
		return
	BrainVariants.use(Match.Team.RUST, "a6")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "tank"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	var compared := 0
	var mismatches := 0
	var contacts := 0
	var remembered := 0
	var reloading := 0
	var suppressed := 0
	var first := ""
	var last_bucket := -1
	for frame in 600:
		await wait_physics_frames(1)
		var bucket := game_match.tick / Match.INTEL_EVERY_TICKS
		if bucket == last_bucket:
			continue
		last_bucket = bucket
		var by_name := AiTickCache.tanks_by_name(game_match)
		AiTickCache._seen_reset(game_match)
		for side in 2:
			var live := AiTickCache._contact_table(game_match, side)
			var seen_live := var_to_bytes(AiTickCache._seen_suppression[side])
			var native := NativeContacts.table(game_match, side, AiTickCache.intel_names(game_match, side), by_name,
					AiTickCache._fired, AiTickCache._seen_suppression[side])
			compared += 1
			var same := var_to_bytes(live) == var_to_bytes(native) and seen_live == var_to_bytes(AiTickCache._seen_suppression[side])
			if not same:
				mismatches += 1
				if first == "":
					first = "tick %d side %d: live %s native %s" % [game_match.tick, side, var_to_str(live).left(600),
							var_to_str(native).left(600)]
			for entry: Dictionary in live.values():
				contacts += 1
				remembered += 0 if bool(entry["visible"]) else 1
				reloading += 1 if float(entry["gun_ready_in"]) > 0.0 else 0
				suppressed += 1 if float(entry["suppression"]) > 0.0 else 0
	BrainVariants.reset()
	print("MEASURE native_contacts compared=%d mismatches=%d contacts=%d remembered=%d reloading=%d suppressed=%d" % [compared,
			mismatches, contacts, remembered, reloading, suppressed])
	assert_eq(mismatches, 0, "native _contact_table = the GDScript (%d); first: %s" % [compared, first])
	assert_true(compared >= 30 and contacts >= 100, "a real sample (%d tables, %d contacts)" % [compared, contacts])
