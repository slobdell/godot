extends TestCase
## Round 24 (native, N3a): the data the C++ owns for the per-vehicle tick. `NativeRecord.fill` hands the library one
## record per living hull in ONE call and `fill_contacts` each team's intel in one call each; every field read back
## from the library must equal the LIVE value it came from (`==`, bit for bit: a float32 member stays float32, a
## GDScript float stays double), the neighbour set must be Avoidance.neighbours' answer, and `command_into` must write a
## TankCommand exactly as GDScript would. `_agents/native.md` *N3*.

const MATCH := preload("res://game/match/match.tscn")
const UNITS: Array[String] = ["scout", "tank", "gang_tank", "artillery", "ifv", "tank", "scout", "gang_tank"]


func _mismatch(what: String, native: Variant, live: Variant) -> String:
	return "%s: native %s, live %s" % [what, var_to_str(native), var_to_str(live)]


func test_the_layout_is_the_library_s() -> void:
	if not NativeBridge.available:
		print("native: absent, the record is not exercised in this run")
		assert_true(not NativeRecord.layout_ok(), "no library, no layout")
		return
	assert_true(NativeRecord.layout_ok(), "native_record.gd's strides are tank_record.h's: %s" % NativeBridge.impl.record_layout())


func test_every_field_reads_back_as_the_live_value() -> void:
	if not NativeBridge.available:
		print("native: absent, the record is not exercised in this run")
		return
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tanks: Array[Tank] = []
	for i in UNITS.size():
		var team := Match.Team.GREEN if i % 2 == 0 else Match.Team.RUST
		var tank := game_match.spawn_tank("Rec%d" % i, 0, team, UNITS[i])
		# Close enough that some are each other's neighbours (Avoidance.NEIGHBOUR_RADIUS 14 m), some not.
		tank.global_position = Vector3(-40.0 + 6.0 * i, 0.0, 3.0 * (i % 3))
		if i < UNITS.size() - 1:  # the last one has no controller: the player's hull (no mover, no route)
			var orders := OrderController.new()
			orders.tank = tank
			orders.tanks_root = game_match.tanks
			add_to_tree(orders)
			orders.set_orders({"type": "move_to", "x": 60.0 - 10.0 * i, "z": 40.0 - 15.0 * (i % 4)}, null)
		tanks.append(tank)
	await wait_physics_frames(20)
	tanks[3].command.fire = true
	tanks[3].command.throttle = 0.123456789012345  # a double that is not a float32
	assert_true(NativeRecord.fill(game_match.tanks, true), "the record loads")
	Avoidance.refresh(game_match.tanks)  # this tick's avoidance table: what the neighbour set is asked of
	var native: Object = NativeBridge.impl
	var alive := 0
	for tank in tanks:
		alive += 1 if tank.is_alive() else 0
	assert_eq(native.record_size(), alive, "one row per living hull")
	assert_eq(NativeRecord.rows, alive, "and the fill counted them")
	var mismatches: Array[String] = []
	var routes := 0
	var with_neighbours := 0
	for tank in tanks:
		var r: int = native.record_find(String(tank.name))
		assert_true(r >= 0, "%s has a row" % tank.name)
		var row: Dictionary = native.record_row(r)
		var mover := Movement.of(tank)
		var halves: Vector2 = Avoidance._halves_of(tank.unit_id)
		var live := {
			"name": String(tank.name), "unit": tank.unit_id, "position": tank.global_position,
			"forward": -tank.global_basis.z, "velocity": tank.estimated_velocity, "aim": tank.command.aim_point,
			"turret_forward": tank.turret_forward(), "speed": tank.speed(), "throttle": tank.command.throttle,
			"turn": tank.command.turn, "max_speed": tank.max_forward_speed, "turn_rate": tank.hull_turn_rate,
			"radius": Avoidance.radius_of(tank.unit_id), "half_w": float(halves.x), "half_l": float(halves.y),
			"wheel_radius": mover.wheel_radius() if mover != null else NativeRecord.wheel_radius_of(tank.unit_id),
			"team": tank.team, "health": tank.health, "fire": tank.command.fire,
			"path_index": mover._path_index if mover != null else 0,
			"route": mover._path if mover != null else PackedVector3Array(),
		}
		for key: String in live:
			if typeof(row.get(key)) != typeof(live[key]) or row.get(key) != live[key]:
				mismatches.append(_mismatch("%s.%s" % [tank.name, key], row.get(key), live[key]))
		# float32 columns: the value is the member's bits, not a double rounded again.
		if (row["position"] as Vector3).x != tank.global_position.x:
			mismatches.append(_mismatch("%s.position.x" % tank.name, row["position"].x, tank.global_position.x))
		var want := PackedStringArray()
		var p := tank.global_position
		for near: Array in Avoidance.neighbours(String(tank.name), p.x, p.z):
			want.append(String(near[1]))
		var near_native: PackedStringArray = native.record_neighbours(r)
		if near_native != want:
			mismatches.append(_mismatch("%s.neighbours" % tank.name, near_native, want))
		with_neighbours += 1 if want.size() > 0 else 0
		routes += 1 if (row["route"] as PackedVector3Array).size() >= 2 else 0
		var cover_map := CoverMap.of(game_match.tanks)
		var cover: int = cover_map._native.get_instance_id() if cover_map._native != null else 0
		if int(row["cover"]) != cover:
			mismatches.append(_mismatch("%s.cover" % tank.name, row["cover"], cover))
	assert_true(mismatches.is_empty(), "every field equal to the live value: %s" % "; ".join(mismatches.slice(0, 6)))
	assert_true(routes >= 3, "some hulls carry a route (%d)" % routes)
	assert_true(with_neighbours >= 3, "some hulls have neighbours (%d)" % with_neighbours)
	assert_eq(native.record_row(-1), {}, "out of range reads nothing")
	assert_eq(native.record_find("nobody"), -1, "an unknown name has no row")

	# TankCommand built natively: the row's command (this tick = the last command until N3c writes one), then a
	# written one, set exactly as GDScript sets a TankCommand's fields.
	var r3: int = native.record_find(String(tanks[3].name))
	var cmd := TankCommand.new(0.5, -0.5, Vector3.ONE, false)
	native.command_into(r3, cmd)
	assert_eq(cmd.throttle, tanks[3].command.throttle, "the last command's throttle, a double")
	assert_eq(cmd.turn, tanks[3].command.turn, "turn")
	assert_eq(cmd.aim_point, tanks[3].command.aim_point, "aim")
	assert_eq(cmd.fire, true, "fire")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2401
	var command_mismatches := 0
	for n in 200:
		var throttle := rng.randf_range(-1.0, 1.0) / 3.0
		var turn := rng.randf_range(-1.0, 1.0) / 7.0
		var aim := Vector3(rng.randf_range(-200.0, 200.0), rng.randf_range(0.0, 5.0), rng.randf_range(-200.0, 200.0))
		var fire := rng.randf() < 0.5
		native.record_set_command(r3, throttle, turn, aim, fire)
		var built := TankCommand.new()
		native.command_into(r3, built)
		var expected := TankCommand.new()
		expected.throttle = throttle
		expected.turn = turn
		expected.aim_point = aim
		expected.fire = fire
		if built.throttle != expected.throttle or built.turn != expected.turn or built.aim_point != expected.aim_point \
				or built.fire != expected.fire:
			command_mismatches += 1
	assert_eq(command_mismatches, 0, "200 commands written natively = written by GDScript")


func test_the_contacts_table_is_the_intel() -> void:
	if not NativeBridge.available:
		print("native: absent, the contacts table is not exercised in this run")
		return
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2402
	var weapons: Array = Weapons.PROFILES.keys()
	for side in 2:
		var intel := {}
		for n in 9 + side * 4:
			var v := func() -> Vector3:
				return Vector3(rng.randf_range(-150.0, 150.0), rng.randf_range(0.0, 3.0), rng.randf_range(-150.0, 150.0))
			intel["C%d_%02d" % [side, (n * 7) % 13]] = {"position": v.call(), "velocity": v.call() / 17.0,
					"forward": (v.call() as Vector3).normalized(), "turret_forward": (v.call() as Vector3).normalized(),
					"health": rng.randi_range(1, 400), "shield": rng.randi_range(0, 50), "weapon": weapons[n % weapons.size()],
					"unit": "tank", "suppression": rng.randf() / 3.0, "role": "line", "visible": rng.randf() < 0.5,
					"seen_tick": rng.randi_range(0, 9000)}
		game_match.intel[side] = intel
	assert_true(NativeRecord.fill_contacts(game_match), "both tables load")
	var mismatches: Array[String] = []
	for side in 2:
		var intel: Dictionary = game_match.intel[side]
		var names := intel.keys()
		names.sort()
		assert_eq(NativeBridge.impl.contacts_size(side), names.size(), "team %d: one row per contact" % side)
		for r in names.size():
			var row: Dictionary = NativeBridge.impl.contacts_row(side, r)
			var known: Dictionary = intel[names[r]]
			if row["name"] != names[r]:
				mismatches.append(_mismatch("team %d row %d name (name order)" % [side, r], row["name"], names[r]))
			for key: String in ["position", "velocity", "forward", "turret_forward", "health", "shield", "weapon", "unit",
					"suppression", "role", "visible", "seen_tick"]:
				if row[key] != known[key] or typeof(row[key]) != typeof(known[key]):
					mismatches.append(_mismatch("%s.%s" % [names[r], key], row[key], known[key]))
			var reach := float(Weapons.profile(String(known["weapon"]))["range"])
			if row["weapon_range"] != reach:
				mismatches.append(_mismatch("%s.weapon_range" % names[r], row["weapon_range"], reach))
	assert_true(mismatches.is_empty(), "every contact field equal to the intel: %s" % "; ".join(mismatches.slice(0, 6)))
