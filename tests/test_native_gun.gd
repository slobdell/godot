extends TestCase
## Round 27 (native, stage 1 E3): `Gunnery.apply` natively (NativeGun -> TankNative.gun_apply, gun_native.cpp) against the
## LIVE GDScript, from the same state. A brain-driven fight on the Sumps (both sides' brains choose real weapon orders);
## after every physics frame each living crew's gun is applied three ways from one snapshot: the GDScript, the native
## call on the live members, and the native call on the C++-owned state. The command, every Gunnery and Lay member, and
## the counters (Engagement.held_by_acquisition / held_by_discipline, OrderController.held_for_friends) must be equal bit
## for bit. Every few frames the crew's weapon order is swapped for a synthetic one (aim, suppress, a named target with
## and without fallback, a sector, hold fire with a watch point) so every branch is asked. Then the state goes back.

const MATCH := preload("res://game/match/match.tscn")
const FORWARDERS: Array[String] = ["tank", "tanks_root", "weapon_order", "move_order", "_step"]
const STATICS := [["Engagement", "held_by_acquisition"], ["Engagement", "held_by_discipline"],
		["OrderController", "held_for_friends"]]


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


static func _capture(gunnery: Gunnery) -> Dictionary:
	var state := {}
	for prop: Dictionary in gunnery.get_property_list():
		var name := String(prop["name"])
		if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and not FORWARDERS.has(name):
			state["g:" + name] = gunnery.get(name)
	var lay := gunnery.engagement_lay
	for name: String in ["target", "progress", "firing"]:
		state["l:" + name] = lay.get(name)
	state["s:held_by_acquisition"] = Engagement.held_by_acquisition
	state["s:held_by_discipline"] = Engagement.held_by_discipline
	state["s:held_for_friends"] = OrderController.held_for_friends
	return state


static func _restore(gunnery: Gunnery, state: Dictionary) -> void:
	for key: String in state:
		var name := key.substr(2)
		match key.left(2):
			"g:":
				gunnery.set(name, state[key])
			"l:":
				gunnery.engagement_lay.set(name, state[key])
	Engagement.held_by_acquisition = state["s:held_by_acquisition"]
	Engagement.held_by_discipline = state["s:held_by_discipline"]
	OrderController.held_for_friends = state["s:held_for_friends"]


static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Object:
		return is_same(a, b)
	return a == b


static func _diff(a: Dictionary, b: Dictionary) -> String:
	for key: String in a:
		if not _same(a[key], b[key]):
			return "%s: %s v %s" % [key, a[key], b[key]]
	return ""


static func _command(cmd: TankCommand) -> Array:
	return [cmd.throttle, cmd.turn, cmd.aim_point, cmd.fire]


func _synthetic(rng: RandomNumberGenerator, tank: Tank, enemies: Array) -> Dictionary:
	var spot := tank.global_position + Vector3(rng.randf_range(-60.0, 60.0), 0.0, rng.randf_range(-60.0, 60.0))
	var enemy: Tank = enemies[rng.randi_range(0, enemies.size() - 1)] if not enemies.is_empty() else null
	match rng.randi_range(0, 5):
		0:
			return {"type": "aim", "x": spot.x, "z": spot.z}
		1:
			return {"type": "suppress", "x": spot.x, "z": spot.z}
		2:
			return {"type": "target", "name": String(enemy.name) if enemy != null else "nobody", "fallback": rng.randf() < 0.5,
					"long_shot": rng.randf() < 0.3}
		3:
			return {"type": "fire_at_will", "sector": [rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)],
					"sector_cos": rng.randf_range(0.2, 0.9)}
		4:
			return {"type": "hold_fire"}
	return {"type": "fire_at_will"}


func test_gunnery_apply_is_the_live_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the gun equality is not exercised in this run")
		return
	assert_true(NativeGun.configure(), "the native gun takes the live constants")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "tank"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2711
	var seconds := 1.0 / float(SimClock.TICK_RATE)
	var applied := 0
	var mismatches := 0
	var owned_mismatches := 0
	var first := ""
	var fired := 0
	var engaged := 0
	var synthetic := 0
	var types := {}
	for frame in 420:
		await wait_physics_frames(1)
		var enemies_of := [[], []]
		for node in game_match.tanks.get_children():
			var hull := node as Tank
			if hull != null and hull.is_alive():
				(enemies_of[1 - hull.team] as Array).append(hull)
		for node in game_match.tanks.get_children():
			var tank := node as Tank
			var mover := Movement.of(tank)
			if mover == null or not tank.is_alive() or mover.ctl.gunnery == null:
				continue
			var ctl := mover.ctl
			var gunnery := ctl.gunnery
			var kept_order := ctl.weapon_order
			var kept_watch: Variant = gunnery.watch_point
			if (frame + applied) % 5 == 0:
				ctl.weapon_order = _synthetic(rng, tank, enemies_of[tank.team])
				if String(ctl.weapon_order["type"]) == "hold_fire" and rng.randf() < 0.7:
					gunnery.watch_point = tank.global_position + Vector3(rng.randf_range(-30.0, 30.0), 0.0, 20.0)
				synthetic += 1
			types[String(ctl.weapon_order["type"])] = int(types.get(String(ctl.weapon_order["type"]), 0)) + 1
			var aim_at := gunnery.held_aim_point()
			var start := _capture(gunnery)
			var live_cmd := TankCommand.new(0.0, 0.0, aim_at)
			gunnery.apply(live_cmd, seconds)
			var live := _capture(gunnery)
			_restore(gunnery, start)
			var native_cmd := TankCommand.new(0.0, 0.0, aim_at)
			NativeBridge.impl.gun_apply(gunnery, native_cmd, seconds, false)
			var native := _capture(gunnery)
			_restore(gunnery, start)
			var owned_cmd := TankCommand.new(0.0, 0.0, aim_at)
			NativeBridge.impl.gun_apply(gunnery, owned_cmd, seconds, true)
			var owned := _capture(gunnery)
			_restore(gunnery, start)
			ctl.weapon_order = kept_order
			gunnery.watch_point = kept_watch
			applied += 1
			fired += 1 if live_cmd.fire else 0
			engaged += 1 if String(live["g:engaged_target"]) != "" else 0
			var differ := _diff(live, native)
			if _command(live_cmd) != _command(native_cmd) or differ != "":
				mismatches += 1
				if first == "":
					first = "frame %d %s (%s, order %s): command live %s native %s; %s" % [frame, tank.name, tank.unit_id,
							ctl.weapon_order, _command(live_cmd), _command(native_cmd), differ]
			var owned_differ := _diff(live, owned)
			if _command(live_cmd) != _command(owned_cmd) or owned_differ != "":
				owned_mismatches += 1
				if first == "":
					first = "OWNED frame %d %s: command live %s owned %s; %s" % [frame, tank.name, _command(live_cmd),
							_command(owned_cmd), owned_differ]
	print("native gun: %d applies (%d synthetic orders, by type %s), %d fired, %d engaged, %d mismatches live members, %d owned state"
			% [applied, synthetic, types, fired, engaged, mismatches, owned_mismatches])
	assert_eq(mismatches + owned_mismatches, 0, "the native gun is the live GDScript gun: %s" % first)
	assert_true(applied >= 3000 and fired >= 50 and engaged >= 300 and synthetic >= 500,
			"a real sample (%d applies, %d fired, %d engaged, %d synthetic)" % [applied, fired, engaged, synthetic])
