extends TestCase
## Round 27 (native, stage 1 E5): `OrderController.compute_command` as one native call (NativeExec -> TankNative.execute,
## execute_native.cpp) against the LIVE GDScript compute_command, from the same state. A brain-driven fight on the Sumps;
## after every physics frame each crew's execute step runs from one snapshot of every mover (MoverState: members, statics,
## the station PID) plus its gun and lay, the counters, `visible_enemy_names` and the wall-contact record (`decided`):
## the GDScript, then the native call on the live members, then on the C++-owned state. Off the common path the native
## call must answer null having written nothing. Then everything goes back, so the fight goes on as the game plays it.

const MATCH := preload("res://game/match/match.tscn")
const FORWARDERS: Array[String] = ["tank", "tanks_root", "weapon_order", "move_order", "_step"]


func _doctrine(units: Array[String]) -> Dictionary:
	var entries := []
	for unit in units:
		entries.append({"unit": unit})
	return {"squads": [{"name": "Alpha", "units": entries.slice(0, 5)}, {"name": "Bravo", "units": entries.slice(5)}]}


static func _capture(movers: Array[Movement], ctl: OrderController) -> Array:
	var all := []
	for mover in movers:
		all.append(MoverState.capture(mover))
	var gun := {}
	for prop: Dictionary in ctl.gunnery.get_property_list():
		var name := String(prop["name"])
		if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and not FORWARDERS.has(name):
			gun["g:" + name] = ctl.gunnery.get(name)
	for name: String in ["target", "progress", "firing"]:
		gun["l:" + name] = ctl.gunnery.engagement_lay.get(name)
	gun["s:acq"] = Engagement.held_by_acquisition
	gun["s:disc"] = Engagement.held_by_discipline
	gun["s:friends"] = OrderController.held_for_friends
	gun["c:visible"] = ctl.visible_enemy_names
	gun["c:decided"] = ctl.movement.contact.decided.duplicate(true)
	return [all, gun, MoverState.world_capture()]


static func _restore(movers: Array[Movement], ctl: OrderController, state: Array) -> void:
	for i in movers.size():
		MoverState.restore(movers[i], state[0][i])
	var gun: Dictionary = state[1]
	for key: String in gun:
		var name := key.substr(2)
		match key.left(2):
			"g:":
				ctl.gunnery.set(name, gun[key])
			"l:":
				ctl.gunnery.engagement_lay.set(name, gun[key])
	Engagement.held_by_acquisition = gun["s:acq"]
	Engagement.held_by_discipline = gun["s:disc"]
	OrderController.held_for_friends = gun["s:friends"]
	ctl.visible_enemy_names = gun["c:visible"]
	ctl.movement.contact.decided = (gun["c:decided"] as Dictionary).duplicate(true)
	MoverState.world_restore(state[2])


static func _diff(a: Array, b: Array) -> String:
	for i in a[0].size():
		var d := MoverState.diff(a[0][i], b[0][i])
		if d != "":
			return "mover %d: %s" % [i, d.left(400)]
	for key: String in a[1]:
		var x: Variant = a[1][key]
		var y: Variant = b[1][key]
		if typeof(x) != typeof(y) or (x is Object and not is_same(x, y)) or (not x is Object and x != y):
			return "%s: %s v %s" % [key, x, y]
	return MoverState.world_diff(a[2], b[2])


static func _command(cmd: TankCommand) -> Array:
	return [cmd.throttle, cmd.turn, cmd.aim_point, cmd.fire]


func test_execute_is_the_live_compute_command() -> void:
	if not NativeBridge.available:
		print("native: absent, the execute equality is not exercised in this run")
		return
	assert_true(NativeGun.configure() and NativeDrive.configure(), "the native drive and gun take the live constants")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv", "tank"]
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, _doctrine(units)), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, _doctrine(units)), "", "rust loads")
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var native := 0
	var handed_back := 0
	var mismatches := 0
	var first := ""
	var was_exec := BrainSwitches.native_exec
	BrainSwitches.native_exec = false
	for frame in 300:
		await wait_physics_frames(1)
		var movers: Array[Movement] = []
		for node in game_match.tanks.get_children():
			var mover := Movement.of(node)
			if mover != null and mover.ctl != null and mover.ctl.gunnery != null:
				movers.append(mover)
		for mover in movers:
			var ctl := mover.ctl
			var start := _capture(movers, ctl)
			var live_cmd: TankCommand = ctl.compute_command(delta)
			var live := _capture(movers, ctl)
			for owned in [false, true]:
				_restore(movers, ctl, start)
				for each in movers:
					each.native_stale = Movement.STALE_ALL  # the test wrote the members back: a door from outside
				var answer: Variant = NativeBridge.impl.execute(ctl, delta, NativeExec.EXEC_OWNED_VERIFY if owned \
						else NativeExec.EXEC_LIVE)
				var after := _capture(movers, ctl)
				if answer == null:
					handed_back += 1
					var untouched := _diff(start, after)
					if untouched != "":
						mismatches += 1
						if first == "":
							first = "frame %d %s handed back but wrote: %s" % [frame, ctl.tank.name, untouched]
					continue
				native += 1
				var differ := _diff(live, after)
				if _command(live_cmd) != _command(answer as TankCommand) or differ != "":
					mismatches += 1
					if first == "":
						first = "frame %d %s (%s, owned %s, move %s, weapon %s): command live %s native %s; %s" % [frame,
								ctl.tank.name, ctl.tank.unit_id, owned, ctl.move_order, ctl.weapon_order,
								_command(live_cmd), _command(answer as TankCommand), differ]
			_restore(movers, ctl, start)
			for each in movers:
				each.native_stale = Movement.STALE_ALL
	BrainSwitches.native_exec = was_exec
	var counts: Dictionary = NativeBridge.impl.execute_counts(true)
	print("native execute counts: %s" % counts)
	print("native execute: %d executes native (both views), %d handed back, %d mismatches" % [native, handed_back, mismatches])
	assert_eq(mismatches, 0, "the native execute is the live compute_command: %s" % first)
	assert_true(native >= 2000, "a real sample (%d native executes)" % native)
