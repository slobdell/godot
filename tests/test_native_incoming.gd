extends TestCase
## Round 28 (native N7.1): Match.incoming_projectiles (contract K2) natively (NativeIncoming -> incoming_native.cpp)
## against the LIVE GDScript. Seeded scenes of a fight: hulls of every unit, real shells (the match's own scene) aimed
## at them, past them, from them, burnt out and stopped, shooters alive and gone, and lobbed rounds in `_lob`'s own
## format landing near and far at every point of their flight; every unit asked both ways, with the hull as a disc (the
## default) and as a box (`--tune=match.hull_disc=0`). The threats -- positions, velocities, etas, ids, weapons, the
## damage estimates and their order -- compared bit for bit (var_to_bytes); and IncomingFire.count_for (its native
## count over the tick's shell columns) both ways.

const MATCH := preload("res://game/match/match.tscn")
const HULLS := 12
const SCENES := 120


func test_the_incoming_query_is_the_live_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the incoming equality is not exercised in this run")
		return
	assert_true(NativeIncoming.configure(), "the native query takes the live constants")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	await wait_physics_frames(1)
	var units: Array = Units.PROFILES.keys()
	units.sort()
	var tanks: Array[Tank] = []
	for i in HULLS:
		var team := Match.Team.GREEN if i % 2 == 0 else Match.Team.RUST
		tanks.append(game_match.spawn_tank("Inc%02d" % i, 0, team, String(units[(i * 5) % units.size()])))
	await wait_physics_frames(2)
	var weapons: Array[Dictionary] = []
	for unit: Variant in units:
		weapons.append(Weapons.profile(String(Units.PROFILES[unit].get("weapon", Weapons.DEFAULT))))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2832
	var was := BrainSwitches.native_incoming
	var tuning_was: Dictionary = Units.tuning.duplicate()
	var asked := 0
	var threats := 0
	var lobbed := 0
	var counted := 0
	var mismatches := 0
	var first := ""
	var next_id := 1
	for n in SCENES:
		for child in game_match.shells.get_children():
			game_match.shells.remove_child(child)
			child.free()
		var centre := Vector3(rng.randf_range(-60.0, 60.0), 0.0, rng.randf_range(-60.0, 60.0))
		for tank in tanks:
			tank.global_position = centre + Vector3(rng.randf_range(-30.0, 30.0), 0.0, rng.randf_range(-30.0, 30.0))
			tank.rotation.y = rng.randf_range(-PI, PI)
			tank.alive = rng.randf() < 0.9
			tank.shield = rng.randf_range(0.0, tank.max_shield) if rng.randf() < 0.6 else 0.0
		for s in rng.randi_range(0, 10):
			var shooter := tanks[rng.randi_range(0, HULLS - 1)]
			var target := tanks[rng.randi_range(0, HULLS - 1)].global_position + Vector3(rng.randf_range(-4.0, 4.0), 0.0,
					rng.randf_range(-4.0, 4.0))
			var start := shooter.global_position + Vector3(0.0, 1.5, 0.0)
			var shell: Shell = game_match.SHELL_SCENE.instantiate()
			shell.name = "Shell_%d" % next_id
			shell.position = start
			shell.direction = (target - start).normalized() if rng.randf() < 0.8 else \
					Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
			shell.shooter_name = String(shooter.name) if rng.randf() < 0.9 else "Gone%d" % s
			shell.speed = [70.0, 120.0, 40.0, 0.0][rng.randi_range(0, 3)] if rng.randf() < 0.95 else -1.0
			shell.max_range = rng.randf_range(20.0, 90.0)
			shell.projectile_id = next_id
			next_id += 1
			game_match.shells.add_child(shell)
			shell._travelled = rng.randf_range(0.0, shell.max_range * 1.2)
			if rng.randf() < 0.1:
				shell.set_physics_process(false)  # hit or burnt out: not in flight
		var rounds: Array = []
		for r in rng.randi_range(0, 4):
			var shooter := tanks[rng.randi_range(0, HULLS - 1)]
			var weapon: Dictionary = weapons[rng.randi_range(0, weapons.size() - 1)].duplicate()
			weapon["splash_radius"] = rng.randf_range(2.0, 12.0)
			var fire_tick := rng.randi_range(0, 400)
			rounds.append({"from": shooter.global_position + Vector3(0.0, 1.5, 0.0),
					"to": tanks[rng.randi_range(0, HULLS - 1)].global_position + Vector3(rng.randf_range(-15.0, 15.0), 0.0,
							rng.randf_range(-15.0, 15.0)),
					"fire_tick": fire_tick, "land_tick": fire_tick + rng.randi_range(1, 120), "team": shooter.team,
					"shooter": String(shooter.name), "weapon": weapon, "weapon_id": String(weapon.get("id", "")),
					"projectile_id": next_id if rng.randf() < 0.9 else -1})
			next_id += 1
		game_match._rounds = rounds
		game_match.tick = n * 4 + rng.randi_range(0, 3)  # a tick of its own: AiTickCache.flight is cached per tick
		if n % 2 == 1:
			Units.tuning["hull_disc"] = 0.0  # the box
		else:
			Units.tuning.erase("hull_disc")
		for tank in tanks:
			BrainSwitches.native_incoming = false
			var live: Array = game_match.incoming_projectiles(tank)
			BrainSwitches.native_incoming = true
			var native: Array = game_match.incoming_projectiles(tank)
			BrainSwitches.native_incoming = false
			var live_count := IncomingFire.count_for(game_match, tank)
			BrainSwitches.native_incoming = true
			var native_count := IncomingFire.count_for(game_match, tank)
			counted += live_count
			if live_count != native_count:
				mismatches += 1
				if first == "":
					first = "scene %d %s (%s): count live %d native %d" % [n, tank.name, tank.unit_id, live_count, native_count]
			asked += 1
			threats += live.size()
			if var_to_bytes(live) != var_to_bytes(native):
				mismatches += 1
				if first == "":
					first = "scene %d %s (%s): live %s native %s" % [n, tank.name, tank.unit_id, live, native]
		for flying: Dictionary in rounds:
			lobbed += 1
	for tank in tanks:
		tank.alive = true
	Units.tuning = tuning_was
	BrainSwitches.native_incoming = was
	print("native incoming: %d queries over %d scenes, %d threats, %d lobbed rounds placed, %d counted by count_for, %d mismatches" % [
			asked, SCENES, threats, lobbed, counted, mismatches])
	assert_eq(mismatches, 0, "the native K2 query is the live GDScript: %s" % first)
	assert_true(threats >= 300 and counted >= 50, "a real sample (%d threats, %d counted)" % [threats, counted])
