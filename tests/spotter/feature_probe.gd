extends SceneTree
## Round 47 (spotter S1): THE FEATURE TABLE. One row per live crew per second of a CPU-v-CPU fight, in the terms a player would
## see: is it moving, getting closer to where it is going, reversing, touching a wall or a friend, pointed along its route, facing
## the fire it takes, holding fire with an enemy in sight and in range, far from its squad, held by an order. Read-only: it listens
## to the match's signals and reads public state once a second (the route query is NoProgressCensus's: the navigation server
## directly, no project memo), so a fight with it is the same fight as one without. Dev tooling; nothing ships.
##   godot --headless --fixed-fps 30 --path . --script res://tests/spotter/feature_probe.gd -- --skirmish --demo-match --clean
##       --seed=N --arena=A --mute --seconds=240 --spot-out=/abs/path/fight.jsonl
## Writes to --spot-out: a {"t":"fight"} header, then {"t":"crew"} rows (keys in tools/spotter/features.py FIELDS), then
## {"t":"end"}. Prints SPOT_DONE {...} last.

const SAMPLE_TICKS := SimClock.TICK_RATE
## How long a hit still counts as "incoming fire" for the facing feature (seconds).
const FIRE_MEMORY_S := 3.0
## Seconds of history the progress features look back over.
const PROGRESS_BACK := [2, 5]

var _out: FileAccess
var _seconds_run := 0.0
var _rows := 0
var _done := false
## crew -> shots fired since the last sample
var _shots := {}
## crew -> [[tick, shooter_pos(Vector3), damage], ...] incoming hits
var _incoming := {}
## crew -> [route distances, newest last]
var _route_hist := {}
## crew -> [goal, ...] last goal seen
var _goal_of := {}
## projectile_id -> shooter name
var _shooter_of := {}


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _write(row: Dictionary) -> void:
	if _out != null:
		_out.store_line(JSON.stringify(row))


func _finalize() -> void:
	_finish("quit")


func _finish(why: String) -> void:
	if _done:
		return
	_done = true
	_write({"t": "end", "seconds": snappedf(_seconds_run, 0.1), "rows": _rows, "why": why})
	if _out != null:
		_out.close()
	print("SPOT_DONE " + JSON.stringify({"seed": int(_flag("seed", "0")), "arena": String(Arena.active.get("name", "")),
			"seconds": snappedf(_seconds_run, 0.1), "rows": _rows, "why": why}))


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Unsigned angle in degrees between the hull's forward and the flat direction `dir` (0 = straight ahead, 180 = behind).
static func _off_nose(tank: Tank, dir: Vector3) -> float:
	var fwd := -tank.global_transform.basis.z
	var a := Vector2(fwd.x, fwd.z)
	var b := Vector2(dir.x, dir.z)
	if a.length() < 0.001 or b.length() < 0.001:
		return -1.0
	return snappedf(rad_to_deg(absf(a.angle_to(b))), 0.1)


func _route_m(tank: Tank, goal: Vector3) -> Array:  # [route metres, next path point or INF]
	var path := NavigationServer3D.map_get_path(tank.get_world_3d().navigation_map, tank.global_position, goal, true)
	var to_go := 0.0
	var from := tank.global_position
	var next := Vector3.INF
	for point in path:
		var leg := _flat(point, from)
		if next == Vector3.INF and leg > 2.0:
			next = point
		to_go += leg
		from = point
	if path.is_empty():
		to_go = _flat(goal, tank.global_position)
	return [to_go, next]


func _run() -> void:
	var out_path := _flag("spot-out", "")
	if out_path != "":
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		_out = FileAccess.open(out_path, FileAccess.WRITE)
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var game_match: Match = main.get("game_match")
	game_match.weapon_fired.connect(func(event: Dictionary) -> void:
		var shooter := String(event.get("shooter", ""))
		_shots[shooter] = int(_shots.get(shooter, 0)) + 1
		_shooter_of[event.get("projectile_id", -1)] = shooter)
	game_match.projectile_impact.connect(func(event: Dictionary) -> void:
		var shooter_name := String(_shooter_of.get(event.get("projectile_id", -1), event.get("shooter", "")))
		var shooter := game_match.tanks.get_node_or_null(shooter_name) as Tank
		if shooter == null:
			return
		var victims: Array = event.get("victims", [])
		if victims.is_empty() and event.has("target"):
			victims = [{"target": event["target"], "damage": event.get("damage", 0.0)}]
		for victim_event: Dictionary in victims:
			var victim := String(victim_event.get("target", ""))
			var damage := float(victim_event.get("damage", 0.0))
			var v := game_match.tanks.get_node_or_null(victim) as Tank
			if v == null or v.team == shooter.team or damage <= 0.0:
				continue
			(_incoming.get_or_add(victim, []) as Array).append([game_match.tick, shooter.global_position, damage]))
	var seconds := float(_flag("seconds", "240"))
	var started := -1
	var last_tick := -1
	var next_sample := -1
	var frames := 0
	var header_done := false
	var ended := false
	game_match.finished.connect(func(_result: Dictionary) -> void: ended = true)
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
		if started < 0:
			started = tick
			next_sample = tick + SAMPLE_TICKS
		_seconds_run = (tick - started) / float(SimClock.TICK_RATE)
		if not header_done:
			header_done = true
			_write({"t": "fight", "seed": int(_flag("seed", "0")), "arena": String(Arena.active.get("name", "")),
					"tick_rate": SimClock.TICK_RATE, "flags": " ".join(OS.get_cmdline_user_args()),
					"rules": RuleSwitches.describe(), "native": NativeBridge.impl != null,
					"engine": Engine.get_version_info().get("string", "")})
		if tick >= next_sample:
			next_sample = tick + SAMPLE_TICKS
			_sample(game_match, tick)
		if ended or (seconds > 0.0 and _seconds_run > seconds):
			break
	_finish("ended" if ended else "seconds")
	quit(0)


func _sample(game_match: Match, tick: int) -> void:
	var ctl_of := {}
	for id: int in Movement._registry:
		var mover: Movement = Movement._registry[id]
		if mover != null and is_instance_valid(mover.ctl) and mover.ctl.tank != null:
			ctl_of[String(mover.ctl.tank.name)] = mover.ctl
	var live: Array[Tank] = []
	var squad_sum := {}  # "team|squad" -> [sum Vector3, n]
	for child in game_match.tanks.get_children():
		var tank := child as Tank
		if tank == null or not tank.is_alive():
			continue
		live.append(tank)
		var brain := ctl_of.get(String(tank.name)) as TankBrain
		var squad := brain.squad_name if brain != null else ""
		if squad != "":
			var key := "%d|%s" % [tank.team, squad]
			var acc: Array = squad_sum.get_or_add(key, [Vector3.ZERO, 0])
			acc[0] = (acc[0] as Vector3) + tank.global_position
			acc[1] = int(acc[1]) + 1
	for tank in live:
		var name := String(tank.name)
		var ctl: OrderController = ctl_of.get(name)
		var brain := ctl as TankBrain
		var mover: Movement = ctl.movement if ctl != null else null
		var row := {"t": "crew", "tick": tick, "s": int(round(float(tick) / SimClock.TICK_RATE)), "crew": name,
				"team": tank.team, "unit": String(tank.unit_id), "loco": tank.locomotion,
				"x": snappedf(tank.global_position.x, 0.1), "z": snappedf(tank.global_position.z, 0.1),
				"yaw": snappedf(rad_to_deg(tank.global_rotation.y), 0.1),
				"speed": snappedf(tank.speed(), 0.01), "vmax": snappedf(tank.max_forward_speed, 0.01),
				"hp": snappedf(float(tank.health), 0.1), "shield": snappedf(float(tank.shield), 0.1),
				"intent": String(tank.intent), "shots": int(_shots.get(name, 0)),
				"range": float(tank.weapon.get("range", 0.0)), "arc": tank.weapon["kind"] == Weapons.Kind.ARC}
		_shots[name] = 0
		if brain != null:
			row["squad"] = brain.squad_name
			row["choice"] = String(brain.choice.get("option", ""))
			row["order"] = String(brain.order.get("verb", brain.order.get("type", "")))
			row["src"] = String(brain.order.get("source", ""))
		if ctl != null:
			row["move"] = String(ctl.move_order.get("type", ""))
			row["weap"] = String(ctl.weapon_order.get("type", ""))
			row["since_fire"] = ctl.ticks_since_fire
			row["lane_blocked"] = ctl.lane_blocked_ticks
			row["lane_blocker"] = ctl.lane_blocker
			row["engaged"] = ctl.engaged_target
			# The nearest enemy this crew can SEE (within its sight radius, a clear line of sight: Perception's own pure
			# physics ray, the same test OrderController._sense uses), and the nearest enemy at any distance.
			# OrderController.visible_enemy_names is filled only for halt_on_contact reflexes, so batch 1 read none (-1).
			var near := INF
			var near_dir := Vector3.ZERO
			var any := INF
			var seen := 0
			for child in game_match.tanks.get_children():
				var enemy := child as Tank
				if enemy == null or not enemy.is_alive() or enemy.team == tank.team:
					continue
				var d := _flat(enemy.global_position, tank.global_position)
				any = minf(any, d)
				if d > tank.sight_radius or not Perception.has_line_of_sight(tank, enemy):
					continue
				seen += 1
				if d < near:
					near = d
					near_dir = enemy.global_position - tank.global_position
			row["seen"] = seen
			row["near_enemy"] = snappedf(near, 0.1) if near < INF else -1.0
			row["near_enemy_off"] = _off_nose(tank, near_dir) if near < INF else -1.0
			row["near_any"] = snappedf(any, 0.1) if any < INF else -1.0
		if mover != null:
			row["phase"] = String(mover.phase)
			row["blocked"] = String(mover.blocked_by) if mover.phase == "blocked" or mover.phase == "yielding" else ""
			row["stalled"] = mover.stalled_ticks
			row["touch"] = mover.contact.touching
			row["touch_cause"] = String(mover.contact.cause) if mover.contact.touching else ""
			row["touch_what"] = String(mover.contact.collider) if mover.contact.touching else ""
			var goal := mover._goal
			# A follow's brain.order.goal is set once and never moved; the drive follows the live station (orders, round 47:
			# batch 1's FOLLOW "goal getting farther" was this). So a follow reads the mover's own goal.
			var following := brain != null and String(brain.order.get("verb", "")) == "follow"
			if brain != null and not following and not brain.order.is_empty() and brain.order.get("goal") is Vector3:
				goal = brain.order["goal"]
			row["follow_live"] = following
			var moving_order := String(ctl.move_order.get("type", "")) == "move_to"
			if goal != Vector3.INF and moving_order:
				var route := _route_m(tank, goal)
				var to_go := float(route[0])
				row["goal_x"] = snappedf(goal.x, 0.1)
				row["goal_z"] = snappedf(goal.z, 0.1)
				row["to_go"] = snappedf(to_go, 0.1)
				var last_goal: Variant = _goal_of.get(name)
				if last_goal == null or _flat(last_goal as Vector3, goal) > 3.0:
					_route_hist[name] = []
				_goal_of[name] = goal
				var hist: Array = _route_hist.get_or_add(name, [])
				hist.append(to_go)
				if hist.size() > 6:
					hist.pop_front()
				for back: int in PROGRESS_BACK:
					if hist.size() > back:
						row["gain_%d" % back] = snappedf(float(hist[hist.size() - 1 - back]) - to_go, 0.1)
				var next: Vector3 = route[1]
				if next != Vector3.INF:
					row["route_off"] = _off_nose(tank, next - tank.global_position)
			else:
				_route_hist.erase(name)
				_goal_of.erase(name)
		# Squad spread: how far from its squad's live centroid (the crew itself included).
		if brain != null and brain.squad_name != "":
			var acc: Array = squad_sum["%d|%s" % [tank.team, brain.squad_name]]
			if int(acc[1]) > 1:
				var centre := (acc[0] as Vector3) / float(acc[1])
				row["squad_n"] = int(acc[1])
				row["squad_d"] = snappedf(_flat(centre, tank.global_position), 0.1)
		# Incoming fire in the last FIRE_MEMORY_S: damage, and how far off the nose the fire came from.
		var hits: Array = _incoming.get(name, [])
		var keep: Array = []
		var damage := 0.0
		var worst := 0.0
		var worst_from := Vector3.ZERO
		var shooter_far := 0.0
		for hit: Array in hits:
			if tick - int(hit[0]) > int(FIRE_MEMORY_S * SimClock.TICK_RATE):
				continue
			keep.append(hit)
			damage += float(hit[2])
			if float(hit[2]) > worst:
				worst = float(hit[2])
				worst_from = hit[1]
			shooter_far = maxf(shooter_far, _flat(hit[1], tank.global_position))
		_incoming[name] = keep
		row["hit_dmg"] = snappedf(damage, 0.1)
		if worst > 0.0:
			row["fire_off"] = _off_nose(tank, worst_from - tank.global_position)
			row["fire_far"] = snappedf(shooter_far, 0.1)
		_write(row)
		_rows += 1
