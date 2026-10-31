extends TestCase
## Round 47 (native, R47.30, manoeuvre M5 `--traffic-on=holdyield`): Movement._holdyield_veto(point) natively (drive_native.cpp's
## holdyield_veto, inside _begin_yield's two spot loops) against its LIVE GDScript, on real TankBrains in a fight: for every living
## crew, its post forced on (TankBrain._his_post at a point near it) or off, random give-way points around it and toward the enemy,
## the switch on and off. The answer and the holdyield_vetoes count must be equal. On a tree without the rule (no
## Movement.holdyield_vetoes) the native veto never fires and the test says so.

const MATCH := preload("res://game/match/match.tscn")


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


func test_native_holdyield_is_the_live_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the holdyield equality is not exercised in this run")
		return
	if (Movement as Object).get("holdyield_vetoes") == null:
		print("holdyield: this tree has no Movement._holdyield_veto (the rule is manoeuvre's); the native veto never fires")
		return
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "tank"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	var was_off := Traffic.off("holdyield")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4730
	var compared := 0
	var mismatches := 0
	var vetoed := 0
	var first := ""
	for frame in 300:
		await wait_physics_frames(1)
		if frame % 6 != 0:
			continue
		for node in game_match.tanks.get_children():
			var tank := node as Tank
			var mover := Movement.of(tank) if tank != null else null
			var brain := mover.ctl as TankBrain if mover != null else null
			if brain == null or not tank.is_alive():
				continue
			var kept_post: Variant = brain.get("_his_post")
			var kept_at: Variant = brain.get("_his_post_at")
			Traffic.set_off("holdyield", rng.randf() < 0.2)
			brain.set("_his_post", rng.randf() < 0.8)
			brain.set("_his_post_at", tank.global_position + Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-6.0, 6.0)))
			for n in 6:
				var point := tank.global_position + Vector3(rng.randf_range(-14.0, 14.0), 0.0, rng.randf_range(-14.0, 14.0))
				var before: int = int((Movement as Object).get("holdyield_vetoes"))
				var live: bool = mover.call("_holdyield_veto", point)
				var live_count: int = int((Movement as Object).get("holdyield_vetoes")) - before
				(Movement as Object).set("holdyield_vetoes", before)
				var native: int = NativeBridge.impl.drive_holdyield_veto(mover, point)
				var native_count: int = int((Movement as Object).get("holdyield_vetoes")) - before
				(Movement as Object).set("holdyield_vetoes", before)
				compared += 1
				vetoed += 1 if live else 0
				if native != (1 if live else 0) or native_count != live_count:
					mismatches += 1
					if first == "":
						first = "frame %d %s point %s post %s at %s: live %s (%d) native %d (%d)" % [frame, tank.name, point,
								brain.get("_his_post"), brain.get("_his_post_at"), live, live_count, native, native_count]
			brain.set("_his_post", kept_post)
			brain.set("_his_post_at", kept_at)
	Traffic.set_off("holdyield", was_off)
	print("MEASURE native_holdyield compared=%d mismatches=%d vetoed=%d" % [compared, mismatches, vetoed])
	assert_eq(mismatches, 0, "the native holdyield veto is the GDScript's (%d); first: %s" % [compared, first])
	assert_true(compared >= 500 and vetoed >= 100 and vetoed < compared - 100,
			"a real sample both ways (%d compared, %d vetoed)" % [compared, vetoed])
