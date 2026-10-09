extends TestCase
## Round 24 (native, N3b `weapon.scan`): `Gunnery._nearest_shootable` as one native call over the record
## (NativeScan.nearest -> TankNative.scan_nearest) gives the LIVE GDScript's pick on every pose: random hulls of both
## teams on the Sumps (crates and walls between them, so the sight-line ray decides), random intel visibility, the
## three ways "seen" is judged (a spotter, the hull's own sight radius, acquisition off), with and without a sector of
## fire. The GDScript is asked through the real Gunnery each time, so a brains edit to the scan the C++ does not follow
## fails here (N2b's pattern).

const MATCH := preload("res://game/match/match.tscn")
const HULLS := 14
const POSES := 300
const UNITS: Array[String] = ["scout", "tank", "gang_tank", "artillery", "ifv", "lancer", "burner"]


func test_the_scan_picks_as_the_live_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the scan equality is not exercised in this run")
		return
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var gunners: Array[Gunnery] = []
	var tanks: Array[Tank] = []
	for i in HULLS:
		var team := Match.Team.GREEN if i % 2 == 0 else Match.Team.RUST
		var tank := game_match.spawn_tank("Scan%02d" % i, 0, team, UNITS[i % UNITS.size()])
		var orders := OrderController.new()
		orders.tank = tank
		orders.tanks_root = game_match.tanks
		add_to_tree(orders)
		tanks.append(tank)
		gunners.append(orders.gunnery)
	await wait_physics_frames(2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2403
	var mismatches := 0
	var picked := 0
	var none := 0
	var by_mode := [0, 0, 0]
	var first := ""
	var saved_acquisition := Engagement.acquisition_enabled
	for n in POSES:
		# A fight-sized cluster somewhere on the map, so ranges and crates both matter.
		var centre := Vector2(rng.randf_range(-120.0, 120.0), rng.randf_range(-120.0, 120.0))
		for tank in tanks:
			tank.global_position = Vector3(centre.x + rng.randf_range(-70.0, 70.0), 0.0, centre.y + rng.randf_range(-70.0, 70.0))
		for side in 2:
			var intel := {}
			for tank in tanks:
				if tank.team != side and rng.randf() < 0.6:
					intel[String(tank.name)] = {"position": tank.global_position, "velocity": Vector3.ZERO,
							"forward": Vector3.FORWARD, "turret_forward": Vector3.FORWARD, "health": 100, "shield": 0,
							"weapon": tank.weapon_id, "unit": tank.unit_id, "suppression": 0.0, "role": "",
							"visible": rng.randf() < 0.7, "seen_tick": 0}
			game_match.intel[side] = intel
		var mode := n % 3
		Engagement.acquisition_enabled = mode != 0
		var gunnery: Gunnery = gunners[n % HULLS]
		var team := gunnery.tank.team
		gunnery.spotter = (func(other: Tank) -> bool: return game_match.is_visible_to(team, other)) if mode == 1 else Callable()
		gunnery.weapon_order = {"type": "fire_at_will"}
		if rng.randf() < 0.5:
			gunnery.weapon_order["sector"] = [rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)]
			gunnery.weapon_order["sector_cos"] = rng.randf_range(0.0, 0.9)
		by_mode[mode] += 1
		BrainSwitches.native_scan = false
		var live := gunnery._nearest_shootable()
		BrainSwitches.native_scan = true
		var native := NativeScan.nearest(gunnery, true)  # refilled: the hulls moved without a physics frame
		var through_seam := gunnery._nearest_shootable()  # the seam, on the record just filled for this frame
		if live == null:
			none += 1
		else:
			picked += 1
		if live != native or through_seam != native:
			mismatches += 1
			if first == "":
				first = "pose %d mode %d: live %s, native %s" % [n, mode, live.name if live else "none", native.name if native else "none"]
	Engagement.acquisition_enabled = saved_acquisition
	print("native scan: %d poses, %d picks, %d none, modes %s, %d mismatches" % [POSES, picked, none, by_mode, mismatches])
	assert_eq(mismatches, 0, "the native scan picks as the live GDScript: %s" % first)
	assert_true(picked >= POSES / 5 and none >= POSES / 20, "both answers occur (%d picks, %d none)" % [picked, none])
