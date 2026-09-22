extends SceneTree
## Round 10, squad item 3: how long a short move takes to SETTLE, end to end, on the path the player uses.
##
## A squad of four stands formed at its team's spawn, facing the enemy, and is given the player's commonest order: a
## plain move (`drills: false`, a right-click on a whole squad) 20 m away. Every tick is sampled. Three times come out,
## all from the moment the order is given:
##
##   ordered_s    every crew holds an order from the new task (R2's acknowledgement: 0.0-0.1 s)
##   arrived_s    the element declares arrival (`Element.arrived`): the player's order is COMPLETED from here (B7)
##   stopped_s    every crew is below STILL_MPS and stays there for STILL_HOLD_S: the squad has stopped moving
##
## plus `in_slot_s` (every crew within IN_SLOT_M of its slot), the worst crew's distance from its slot at the end, and
## the closest any two hull centres came (a collision proxy: B7's bar is "no rise in collisions").
## Round 9 measured 22.3 s to arrival and ~20 s more to stop on a 20 m move (the facing-drag test, default arena);
## the bar is COMPLETED in <= 8 s on flat ground (B7) and settled in under 10 s (the brief).
##
##   --arena=         layout name ("" = the arena scene's default)      --dir=forward|side|back (the move's direction)
##   --units=tank:tank:ifv:ifv                                            --metres=20   --seed=3   --seconds=45
##
##   SETTLE_PROBE {"arena": ..., "dir": ..., "ordered_s": ..., "arrived_s": ..., "stopped_s": ..., ...}

const STILL_MPS := 0.3
const STILL_HOLD_S := 1.0
const IN_SLOT_M := 3.0
## B7: a crew has visibly acknowledged an order once it moves faster than this, or its hull or turret has turned this far.
const ACK_MPS := 1.0
const START_JITTER_M := 1.5
const START_JITTER_DEG := 10.0
const ACK_DEG := 5.0

var case: TestCase


func _initialize() -> void:
	_run_probe.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run_probe() -> void:
	case = TestCase.new()
	case.tree = self
	ElementPlan.PIN_LEADER_ON_PLAIN_MOVE = _flag("pin", "off") == "on"
	ElementPlan.PIN_LEADER_ON_LEGS = _flag("pin", "off") == "on"
	var report := await _run(_flag("arena", ""), _flag("dir", "forward"), _flag("units", "tank:tank:ifv:ifv").split(":"),
			float(_flag("metres", "20")), int(_flag("seed", "3")), float(_flag("seconds", "45")))
	print("SETTLE_PROBE " + JSON.stringify(report))
	print("SETTLE_PROBE_DONE")
	case.teardown()
	quit(0)


func _run(arena_name: String, dir: String, unit_ids: PackedStringArray, metres: float, seed_value: int,
		seconds: float) -> Dictionary:
	var lab := TacticsLab.create(case, seed_value, arena_name)
	var game_match := lab.game_match
	# The player commands GREEN, as in `make skirmish`: the element is a player's squad (R2's pre-emption applies).
	game_match.set_meta("player_team", Match.Team.GREEN)
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	var toward := TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-toward.z, 0.0, toward.x)
	var yaw := atan2(-toward.x, -toward.z)
	var names: Array = []
	# The SEED jitters each crew's start (±START_JITTER_M along both axes, ±START_JITTER_DEG of yaw), so a series over
	# seeds samples real layouts: before this every seed produced the identical run (builder0, 0d18ce43: six seeds per
	# cell, six identical rows), and a "paired series" of n = 6 was n = 1.
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	for i in unit_ids.size():
		# Abreast at 8 m, the squad as it stands after forming up at the spawn.
		var at := home + right * ((i - (unit_ids.size() - 1) * 0.5) * 8.0) \
				+ right * jitter.randf_range(-START_JITTER_M, START_JITTER_M) \
				+ toward * jitter.randf_range(-START_JITTER_M, START_JITTER_M)
		var tank := lab.unit(Match.Team.GREEN, "Green_S_%d" % (i + 1), at,
				yaw + deg_to_rad(jitter.randf_range(-START_JITTER_DEG, START_JITTER_DEG)), String(unit_ids[i]))
		names.append(String(tank.name))
	await lab.start()
	# The faction's own table (Elements picks it), exactly as a numbered squad gets in skirmish.
	var element := lab.elements.form(names, "Alpha")
	var direction: Vector3 = {"forward": toward, "side": right, "back": -toward}.get(dir, toward)
	var centre := _centre(game_match, names)
	var goal := centre + direction * metres
	var before := {}
	for unit_name: String in names:
		before[unit_name] = int((lab.orders.call("current", unit_name) as Dictionary).get("id", -1))
	# B7's acknowledgement: each crew's hull yaw and turret heading when the order is given.
	var yaw0 := {}
	var gun0 := {}
	for unit_name: String in names:
		var t := game_match.tanks.get_node(NodePath(unit_name)) as Tank
		yaw0[unit_name] = t.global_rotation.y
		gun0[unit_name] = t.turret_forward()
	var acked := {}
	var given: int = game_match.tick
	# --drills=on: the task with drills ON takes ElementPlan's LEGGED movement (the path PIN_LEADER_ON_LEGS governs),
	# not the plain move's form-up; that is the CPU's and an attack-move's path.
	var task := {"verb": "move", "to": [goal.x, goal.z]}
	if _flag("drills", "off") != "on":
		task["drills"] = false
	element.assign(task)
	var ordered := -1
	var arrived := -1
	var in_slot := -1
	var still_since := -1
	var stopped := -1
	var closest := INF
	var trace := _flag("trace", "off") == "on"
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		var now: int = game_match.tick - given
		if ordered < 0 and _all_reordered(lab.orders, names, before):
			ordered = now
		if arrived < 0 and element.arrived:
			arrived = now
		for unit_name: String in names:
			if acked.has(unit_name):
				continue
			var t := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if t == null:
				continue
			var turned: float = absf(angle_difference(t.global_rotation.y, float(yaw0[unit_name])))
			var slewed: float = (gun0[unit_name] as Vector3).angle_to(t.turret_forward())
			if t.estimated_velocity.length() > ACK_MPS or turned > deg_to_rad(ACK_DEG) or slewed > deg_to_rad(ACK_DEG):
				acked[unit_name] = now
		var fastest := 0.0
		var worst_slot := 0.0
		var at := {}
		for unit_name: String in names:
			var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if tank == null or not tank.is_alive():
				continue
			at[unit_name] = tank.global_position
			fastest = maxf(fastest, tank.estimated_velocity.length())
			var slot: Variant = element.slots.get(unit_name)
			if slot is Vector3:
				worst_slot = maxf(worst_slot, _flat(tank.global_position).distance_to(_flat(slot)))
		for a in names.size():
			for b in range(a + 1, names.size()):
				if at.has(names[a]) and at.has(names[b]):
					closest = minf(closest, _flat(at[names[a]]).distance_to(_flat(at[names[b]])))
		if trace and now % SimClock.TICK_RATE == 0:
			var parts: Array = []
			for unit_name: String in names:
				var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
				var order: Dictionary = lab.orders.call("current", unit_name)
				var slot: Variant = element.slots.get(unit_name)
				var mover := Movement.state(tank)
				parts.append("%s %s v%.1f p%.2f slot%.1f %s%s" % [unit_name.right(1), String(order.get("verb", "-")),
						tank.estimated_velocity.length(), float(element.paces.get(unit_name, 1.0)),
						_flat(tank.global_position).distance_to(_flat(slot)) if slot is Vector3 else -1.0,
						String(mover.get("phase", "?")), ("/" + String(mover.get("blocked_by", ""))) \
						if String(mover.get("blocked_by", "")) != "" else ""])
			print("SETTLE_TRACE t=%ds centre %.1f m arrived=%s joined=%s | %s" % [now / SimClock.TICK_RATE,
					_centre(game_match, names).distance_to(goal), element.arrived, element.flow_joined, " | ".join(parts)])
		if in_slot < 0 and arrived >= 0 and worst_slot <= IN_SLOT_M:
			in_slot = now
		if arrived >= 0 and fastest < STILL_MPS:
			if still_since < 0:
				still_since = now
			if now - still_since >= int(STILL_HOLD_S * SimClock.TICK_RATE):
				stopped = still_since
				break
		else:
			still_since = -1
	var off := {}
	for unit_name: String in names:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		var slot: Variant = element.slots.get(unit_name)
		if tank != null and slot is Vector3:
			off[unit_name] = snappedf(_flat(tank.global_position).distance_to(_flat(slot)), 0.1)
	return {"arena": arena_name if arena_name != "" else "default", "dir": dir,
			"pin": ElementPlan.PIN_LEADER_ON_PLAIN_MOVE, "drills": _flag("drills", "off"), "units": ":".join(unit_ids),
			"metres": metres, "seed": seed_value, "formation": element.formation,
			"ack_s": _s(acked.values().max()) if acked.size() == names.size() else null,
			"ordered_s": _s(ordered), "arrived_s": _s(arrived), "in_slot_s": _s(in_slot), "stopped_s": _s(stopped),
			"off_slot_m": off, "closest_m": snappedf(closest, 0.01), "goal_moves": element.goal_moves,
			"bottleneck_s": _s(element.bottleneck_ticks)}


static func _s(ticks: int) -> Variant:
	return snappedf(ticks / float(SimClock.TICK_RATE), 0.01) if ticks >= 0 else null


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _centre(game_match: Match, names: Array) -> Vector3:
	var sum := Vector3.ZERO
	for unit_name: String in names:
		sum += _flat((game_match.tanks.get_node(NodePath(unit_name)) as Node3D).global_position)
	return sum / float(names.size())


func _all_reordered(orders: Object, names: Array, before: Dictionary) -> bool:
	for unit_name: String in names:
		var order: Dictionary = orders.call("current", unit_name)
		if order.is_empty() or int(order.get("id", -1)) == int(before[unit_name]):
			return false
	return true
