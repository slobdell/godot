extends SceneTree
## Round 48 (manoeuvre M1), MEASUREMENT ONLY: who waits on whom in a CPU-v-CPU fight, tick by tick. The same fight as the
## spotter's feature probe (`--skirmish --demo-match --clean --seed --arena --mute`); it reads public mover / brain state once a
## tick and never calls a decision, so a traced fight is the fight the clip shows (check: the crew's pos at the clip's peak tick).
## For each crew in --ytrace (comma list) inside --ytrace-window=<from>-<to> (ticks), it prints a YTRACE row, and follows the
## chain: the crew it is blocked by / yielding to / passing, and theirs, up to --ytrace-depth (default 3) links.
##   godot --headless --fixed-fps 30 --path . --script res://tests/manoeuvre/yield_trace.gd -- --skirmish --demo-match --clean \
##       --seed=13215 --arena=crossing --mute --ytrace=Green_Spears_1 --ytrace-window=450-800 [--ytrace-every=3]
## `make manoeuvre-yield-trace` runs it (mk/manoeuvre.mk).

var _ctl_of := {}


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


static func _xz(v: Variant) -> Variant:
	if v is Vector3 and (v as Vector3) != Vector3.INF:
		return [snappedf((v as Vector3).x, 0.1), snappedf((v as Vector3).z, 0.1)]
	return null


func _run() -> void:
	var names := _flag("ytrace", "").split(",", false)
	var bounds := _flag("ytrace-window", "0-999999").split("-")
	var from := int(bounds[0])
	var to := int(bounds[bounds.size() - 1])
	var every := maxi(1, int(_flag("ytrace-every", "1")))
	var depth := int(_flag("ytrace-depth", "3"))
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var game_match: Match = main.get("game_match")
	var last_tick := -1
	var frames := 0
	while true:
		await physics_frame
		frames += 1
		if game_match == null or not is_instance_valid(game_match):
			break
		var tick := game_match.tick
		if tick == last_tick:
			if frames > 60 * 60 * 10:
				break
			continue
		last_tick = tick
		if tick > to:
			break
		if tick < from or tick % every != 0:
			continue
		_ctl_of.clear()
		for id: int in Movement._registry:
			var mover: Movement = Movement._registry[id]
			if mover != null and is_instance_valid(mover.ctl) and mover.ctl.tank != null:
				_ctl_of[String(mover.ctl.tank.name)] = mover.ctl
		var seen := {}
		var queue: Array = []
		for n in names:
			queue.append([n, 0, ""])
		while not queue.is_empty():
			var item: Array = queue.pop_front()
			var n := String(item[0])
			if seen.has(n):
				continue
			seen[n] = true
			var tank := game_match.tanks.get_node_or_null(NodePath(n)) as Tank
			var ctl: OrderController = _ctl_of.get(n)
			if tank == null or ctl == null or ctl.movement == null:
				continue
			var row := _row(game_match, tank, ctl, int(item[1]), String(item[2]))
			print("YTRACE " + JSON.stringify(row))
			if int(item[1]) >= depth:
				continue
			for link: String in [String(row["blocked"]), String(row["yield_to"]), String(row["pass_by"]), String(row["ahead"])]:
				if link != "" and link != "terrain" and link != "no_path" and not seen.has(link):
					queue.append([link, int(item[1]) + 1, n])
	print("YTRACE_DONE tick %d" % last_tick)
	quit(0)


## The nearest live friendly hull ahead of `tank` (within 45 deg of its travel or its nose) inside 12 m, by name: what it faces.
func _ahead_of(game_match: Match, tank: Tank, m: Movement) -> Array:
	var here := tank.global_position
	var way := Vector2.ZERO
	if m._path_index < m._path.size():
		way = Vector2(m._path[m._path_index].x - here.x, m._path[m._path_index].z - here.z)
	if way.length_squared() < 0.01:
		way = Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z)
	way = way.normalized()
	var best := ""
	var best_d := 12.0
	for child in game_match.tanks.get_children():
		var other := child as Tank
		if other == null or other == tank or not other.is_alive() or other.team != tank.team:
			continue
		var off := Vector2(other.global_position.x - here.x, other.global_position.z - here.z)
		var d := off.length()
		if d < best_d and d > 0.01 and off.normalized().dot(way) > 0.707:
			best = String(other.name)
			best_d = d
	return [best, snappedf(best_d, 0.1)]


func _row(game_match: Match, tank: Tank, ctl: OrderController, level: int, via: String) -> Dictionary:
	var m := ctl.movement
	var fwd := -tank.global_basis.z
	var brain := ctl as TankBrain
	var hits: Array = []
	for i in tank.get_slide_collision_count():
		var body := tank.get_slide_collision(i).get_collider() as Node
		hits.append(String(body.name) if body != null else "?")
	var ahead := _ahead_of(game_match, tank, m)
	var row := {"tick": game_match.tick, "n": String(tank.name), "lvl": level, "via": via, "unit": String(tank.unit_id),
			"pos": _xz(tank.global_position), "yaw": snappedf(rad_to_deg(atan2(-fwd.x, -fwd.z)), 1.0),
			"v": snappedf(tank.speed(), 0.01), "thr": snappedf(tank.command.throttle, 0.01), "hp": snappedf(float(tank.health), 1.0),
			"move": String(ctl.move_order.get("type", "")), "goal": _xz(m._goal), "rem": snappedf(m._remaining, 0.1),
			"under_way": m.is_under_way(), "phase": m.phase, "blocked": m.blocked_by, "stalled": m.stalled_ticks,
			"yield_to": m.yield_to, "yspot": String(m.yield_spot), "ypt": _xz(m._yield_point), "yleft": m._yield_left,
			"last_y": m._last_yielded_to, "pass_by": m._pass_by, "wait_for": m._wait_for, "hold": Traffic.holding(String(tank.name)),
			"fire_post": m.on_fire_post(), "under_fire": m.under_fire(), "deploy": snappedf(tank.deploy_ratio, 0.01),
			"ahead": String(ahead[0]), "ahead_m": ahead[1], "hits": hits, "native": NativeDrive.usable(m)}
	if brain != null:
		row["choice"] = String(brain.choice.get("option", ""))
		row["verb"] = String(brain.order.get("verb", brain.order.get("type", "")))
		row["his_post"] = brain._his_post
		row["post"] = _xz(brain._his_post_at) if brain._his_post else null
		row["squad"] = brain.squad_name
	return row
