extends TestCase
## Round 48 (native, R48.8): VisibilityField._rays natively (NativeVisfield -> visfield_native.cpp) against its LIVE GDScript, bit for bit
## (var_to_bytes of [reach, fan]), on Crossing's buildings with a fight on: every few frames, from every living crew's eye and from
## random eyes around it, at its sight radius and at random radii, the field's own ray directions. Enough rays must hit something.

const MATCH := preload("res://game/match/match.tscn")


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


func _directions(ray_count: int) -> PackedVector3Array:
	var directions := PackedVector3Array()
	directions.resize(ray_count)
	for r in ray_count:
		var angle := TAU * r / ray_count
		directions[r] = Vector3(cos(angle), 0.0, sin(angle))
	return directions


func test_native_visfield_rays_are_the_live_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the visfield equality is not exercised in this run")
		return
	await ArenaFixture.build(self, "crossing")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "tank"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	var field := VisibilityField.new()
	field.game_match = game_match
	field.team = Match.Team.GREEN
	game_match.add_child(field)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13505
	var compared := 0
	var mismatches := 0
	var rays := 0
	var hits := 0
	var first := ""
	var gd_usec := 0
	var native_usec := 0
	for frame in 240:
		await wait_physics_frames(1)
		if frame % 12 != 0:
			continue
		for node in game_match.tanks.get_children():
			var tank := node as Tank
			if tank == null or not tank.is_alive():
				continue
			for n in 3:
				var eye := tank.global_position + Vector3.UP * Perception.EYE_HEIGHT
				if n > 0:
					eye += Vector3(rng.randf_range(-20.0, 20.0), 0.0, rng.randf_range(-20.0, 20.0))
				var radius: float = tank.sight_radius if n < 2 else rng.randf_range(20.0, 110.0)
				var directions := _directions(ceili(TAU * radius / VisibilityField.CELL_SIZE))
				var space := tank.get_world_3d().direct_space_state
				var t0 := Time.get_ticks_usec()
				var live := field._rays(eye, radius, directions, space)
				gd_usec += Time.get_ticks_usec() - t0
				var t1 := Time.get_ticks_usec()
				var native: Array = NativeBridge.impl.visfield_rays(tank, eye, radius, directions, Perception.eye_mask())
				native_usec += Time.get_ticks_usec() - t1
				compared += 1
				rays += directions.size()
				for d: float in (live[0] as PackedFloat32Array):
					hits += 1 if d < radius - 0.001 else 0
				if var_to_bytes(live) != var_to_bytes(native):
					mismatches += 1
					if first == "":
						first = "frame %d %s eye %s radius %s: live %s native %s" % [frame, tank.name, eye, radius,
								var_to_str(live).left(300), var_to_str(native).left(300)]
	print("MEASURE native_visfield compared=%d mismatches=%d rays=%d hits=%d gd_usec=%d native_usec=%d" % [compared, mismatches,
			rays, hits, gd_usec, native_usec])
	assert_eq(mismatches, 0, "native _rays = the GDScript (%d fans); first: %s" % [compared, first])
	assert_true(compared >= 200 and hits >= 1000 and hits < rays, "a real sample (%d fans, %d rays, %d hits)" % [compared, rays, hits])
