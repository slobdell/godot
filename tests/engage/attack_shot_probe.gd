extends SceneTree
## Round 42 (engage E4, Bar E1's workload): HIS CASE AS A PROBE. A squad of 2-5 crews ordered to attack a target 20-40 m away
## behind a piece of cover (a container, a block), the crews on BOTH sides of it (one with a clear line, the rest behind), on
## locks / terminus / crossing (by seed), the target an enemy gun that shoots back. One run = one seed; the arm is
## `--attack-shot=on|off`. Everything is drawn from the seed (the cover piece, the sides, the crews' hull, the target's),
## so the two arms see the same stage and pair by seed.
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/engage/attack_shot_probe.gd -- --seed=N [--arena=A]
##         [--crews=N] [--seconds=60] [--attack-shot=on|off] [--trace=on]
## Prints ENGAGE_PROBE {json} once (read by tests/engage/attack_shot_table.py):
##   stuck_s      crew-seconds under the attack order, in distance-range of the target, with NO line to it (the cover map,
##                the read the plan and the brain decide by) and not moving: the thing he saw (the deciding line)
##   first_hit_s  per crew, seconds from the order to its first hit on the target (the window length when it never hits)
##   deaths, deaths_moving  crews that died, and died while moving for a shot (moving, no line, under the order): exposure
##   spot_changes  per crew, the distinct goals (> 2 m apart) of moves naming the target under the order: the dither count
##   never_reached  spots a crew was sent to and never came within 3 m of before the goal changed or the order ended
##   lines         ElementSituation.shot_lines over the run (cover-map lines the plan asked for) and per plan tick

const ARENAS := ["locks", "terminus", "crossing"]
## His case is a fixed gun's standoff hold (a turret circles and is rarely held still): five fixed mounts to one gun truck.
const HULLS := ["gang_scout", "scout", "law_scout", "gang_scout", "law_scout", "gang_ifv"]
## Targets a 2-5 crew squad can hurt in a minute (no tanks: a stage every crew dies on measures deaths, not shots).
const TARGETS := ["syn_artillery", "syn_scout", "ifv", "law_artillery", "syn_ifv"]
## The stage as the brief names it: the crews behind the cover start this far from the target.
const STAGE_MIN_M := 18.0
const STAGE_MAX_M := 42.0
const STAND_M := 3.0
const SPOT_CHANGE_M := 2.0
const REACH_M := 3.0

var case: TestCase
var _first_hit := {}
var _hits := {}
var _deaths := {}
var _target_name := ""


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _r(x: float) -> float:
	return snappedf(x, 0.1)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## The cover pieces to fight round, in the rng's order: medium-sized (a container, a small block), well inside the arena.
func _features(map: CoverMap, rng: RandomNumberGenerator) -> Array:
	var candidates: Array = []
	for feature: Dictionary in map.features:
		var half: Vector2 = feature["half"]
		var center: Vector2 = feature["center"]
		if float(feature.get("height", 3.0)) < CoverMap.EYE_HEIGHT:
			continue
		if minf(half.x, half.y) < 1.0 or maxf(half.x, half.y) > 14.0 or minf(half.x, half.y) > 8.0:
			continue
		if absf(center.x) > 80.0 or absf(center.y) > 80.0:
			continue
		candidates.append(feature)
	var order: Array = []
	while not candidates.is_empty():
		order.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))
	return order


## The stage round `feature`: the target 8-14 m off its far face, the crews 10-18 m off the near face spread along it (4 m
## apart at least), one crew past the face's end on the target's side. {} when a spot cannot stand (inside something, off
## the arena); the caller then tries the next piece, and the distances are judged once the ground has had its say.
func _stage(map: CoverMap, feature: Dictionary, rng: RandomNumberGenerator, crews_n: int) -> Dictionary:
	var center := Vector3((feature["center"] as Vector2).x, 0.0, (feature["center"] as Vector2).y)
	var axis := Vector3((feature["axis"] as Vector2).x, 0.0, (feature["axis"] as Vector2).y)
	var half: Vector2 = feature["half"]
	var along := axis
	var n := Vector3(-axis.z, 0.0, axis.x)
	var half_n := half.y
	var half_along := half.x
	if half.y > half.x:
		along = Vector3(-axis.z, 0.0, axis.x)
		n = axis
		half_n = half.x
		half_along = half.y
	if rng.randf() < 0.5:
		n = -n
	var target_at := center + n * (half_n + 8.0 + rng.randf_range(0.0, 6.0)) + along * rng.randf_range(-half_along * 0.5, half_along * 0.5)
	if not _standable(map, target_at):
		return {}
	var spots: Array = []
	for i in crews_n:
		var spot := Vector3.INF
		for attempt in 12:
			var try_at: Vector3
			if i == crews_n - 1 and crews_n >= 2:
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				try_at = center + along * side * (half_along + 8.0 + rng.randf_range(0.0, 4.0)) - n * rng.randf_range(0.0, 6.0)
			else:
				try_at = center - n * (half_n + 10.0 + rng.randf_range(0.0, 8.0)) \
						+ along * rng.randf_range(-half_along - 2.0, half_along + 2.0)
			var apart := true
			for other: Vector3 in spots:
				if other.distance_to(try_at) < 4.0:
					apart = false
			if apart and _standable(map, try_at):
				spot = try_at
				break
		if spot == Vector3.INF:
			return {}
		spots.append(spot)
	return {"center": center, "n": n, "target": target_at, "spots": spots}


func _standable(map: CoverMap, point: Vector3) -> bool:
	var limit := Match.DRIVABLE_LIMIT - 8.0
	return absf(point.x) <= limit and absf(point.z) <= limit and not map.inside_any(Vector2(point.x, point.z), STAND_M)


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	var seed_value := int(_flag("seed", "7001"))
	var seconds := float(_flag("seconds", "60"))
	var trace := _flag("trace", "off") == "on"
	var arena := _flag("arena", ARENAS[seed_value % ARENAS.size()])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var crews_n := int(_flag("crews", str(2 + rng.randi_range(0, 3))))
	var hull: String = HULLS[rng.randi_range(0, HULLS.size() - 1)]
	var target_unit: String = TARGETS[rng.randi_range(0, TARGETS.size() - 1)]
	# The seed's arena, else the next in the cycle (a seed whose draw stands nowhere on one map: 7012 on terminus).
	var lab: TacticsLab = null
	var game_match: Match = null
	var map: CoverMap = null
	var stage := {}
	var feature := {}
	for attempt in ARENAS.size():
		if _flag("arena", "") == "" and attempt > 0:
			arena = ARENAS[(seed_value + attempt) % ARENAS.size()]
		elif attempt > 0:
			break
		lab = TacticsLab.create(case, seed_value, arena)
		game_match = lab.game_match
		game_match.set_meta("player_team", Match.Team.GREEN)
		map = CoverMap.of(game_match)
		for candidate: Dictionary in _features(map, rng):
			stage = _stage(map, candidate, rng, crews_n)
			if not stage.is_empty():
				feature = candidate
				break
		if not stage.is_empty():
			break
		lab.dispose()
		await process_frame
	if stage.is_empty():
		print("ENGAGE_PROBE %s" % JSON.stringify({"seed": seed_value, "arena": arena, "error": "no stage stands"}))
		quit(0)
		return
	var center: Vector3 = stage["center"]
	var target_at: Vector3 = stage["target"]
	var crew_spots: Array = stage["spots"]
	var toward := _flat(target_at - center).normalized()
	var yaw := atan2(-toward.x, -toward.z)
	var names: Array = []
	for i in crews_n:
		var crew := lab.unit(Match.Team.GREEN, "Green_E_%d" % (i + 1), crew_spots[i], yaw, hull)
		names.append(String(crew.name))
	var target := lab.gun(Match.Team.RUST, "Rust_T_1", target_at, yaw + PI, target_unit)
	_target_name = String(target.name)
	var shooters := {}
	game_match.weapon_fired.connect(func(event: Dictionary) -> void:
		shooters[int(event.get("projectile_id", -1))] = String(event.get("shooter", "")))
	game_match.projectile_impact.connect(func(event: Dictionary) -> void:
		var shooter := String(shooters.get(int(event.get("projectile_id", -1)), event.get("shooter", "")))
		var victims: Array = event.get("victims", [])
		var on_target := String(event.get("target", "")) == _target_name \
				or victims.any(func(v: Dictionary) -> bool: return String(v.get("target", "")) == _target_name)
		if on_target and float(event.get("damage", 0.0)) > 0.0 and names.has(shooter):
			_hits[shooter] = int(_hits.get(shooter, 0)) + 1
			if not _first_hit.has(shooter):
				_first_hit[shooter] = int(event.get("tick", game_match.tick)))
	game_match.unit_destroyed.connect(func(event: Dictionary) -> void:
		_deaths[String(event.get("unit", ""))] = int(event.get("tick", game_match.tick)))
	await lab.start()
	# Ground every hull where it can stand (the navmesh is up now), as the game grounds a slot.
	var ground_node := game_match.tanks.get_child(0) as Node3D
	for unit_name: String in names:
		var tank := lab.tank_of(unit_name)
		var at := SlotGround.standable_for(ground_node, _flat(tank.global_position), SlotGround.envelope_of(tank.unit_id))
		if at.distance_to(_flat(tank.global_position)) > 0.5:
			tank.place(at, yaw)
	var grounded := SlotGround.standable_for(ground_node, _flat(target.global_position), SlotGround.envelope_of(target.unit_id))
	if grounded.distance_to(_flat(target.global_position)) > 0.5:
		target.place(grounded, yaw + PI)
	for i in 3:
		await lab.step()
	var placed: Array = []
	var start_m: Array = []
	var stage_ok := true
	var ground_moved := 0
	for i in names.size():
		var at := _flat(lab.tank_of(names[i]).global_position)
		placed.append([_r(at.x), _r(at.z)])
		if at.distance_to(crew_spots[i]) > 3.0:
			ground_moved += 1
		var d := at.distance_to(_flat(target.global_position))
		start_m.append(_r(d))
		if i < names.size() - 1 and (d < STAGE_MIN_M or d > STAGE_MAX_M):
			stage_ok = false
	if _flat(target.global_position).distance_to(target_at) > 3.0:
		ground_moved += 1
	if ground_moved > 0:
		stage_ok = false
	var element := lab.elements.form(names, "Echo")
	var order_tick := game_match.tick
	element.assign({"verb": "attack", "target": _target_name, "formation": "line"})
	var lines_before := ElementSituation.shot_lines
	var stuck_ticks := {}
	var in_range_no_shot_ticks := {}
	var moving_for_shot := {}
	var spots := {}      # crew -> [goals]
	var reached := {}    # crew -> {goal index: true}
	var start_lines := {}
	var death_moving := {}
	var flips := {}
	var last_shot := {}
	for unit_name: String in names:
		stuck_ticks[unit_name] = 0
		in_range_no_shot_ticks[unit_name] = 0
		spots[unit_name] = []
		reached[unit_name] = {}
		start_lines[unit_name] = map.clear_line(_flat(lab.tank_of(unit_name).global_position), _flat(target.global_position))
	var target_dead_tick := -1
	var plan_ticks := 0
	var last_plan_lines := lines_before
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		if ElementSituation.shot_lines != last_plan_lines:
			plan_ticks += 1
			last_plan_lines = ElementSituation.shot_lines
		if not target.is_alive():
			if target_dead_tick < 0:
				target_dead_tick = game_match.tick
			break
		var target_pos := _flat(target.global_position)
		for unit_name: String in names:
			var tank := lab.tank_of(unit_name)
			if tank == null or not tank.is_alive():
				continue
			var pos := _flat(tank.global_position)
			var order: Dictionary = lab.orders.call("current", unit_name)
			var verb := String(order.get("verb", ""))
			var named := String(order.get("target", "")) == _target_name
			var under := (verb == "attack" and named) or (verb in ["move", "attack_move"] and named) \
					or String(element.task.get("verb", "")) == "attack"
			if not under:
				continue
			var in_range := pos.distance_to(target_pos) <= float(tank.weapon.get("range", 60.0)) * ElementPlan.ENGAGE_RANGE_FACTOR
			var shot := map.clear_line(pos, target_pos)
			var moving := tank.estimated_velocity.length() >= 0.5
			if in_range and not shot:
				in_range_no_shot_ticks[unit_name] = int(in_range_no_shot_ticks[unit_name]) + 1
				if not moving:
					stuck_ticks[unit_name] = int(stuck_ticks[unit_name]) + 1
			moving_for_shot[unit_name] = moving and not shot
			if last_shot.has(unit_name) and bool(last_shot[unit_name]) != shot:
				flips[unit_name] = int(flips.get(unit_name, 0)) + 1
			last_shot[unit_name] = shot
			# A firing-spot move is a `move` naming the target (the drills' attack-moves and the formation's moves are not spots).
			if verb == "move" and named and order.has("goal"):
				var goal := Vector3(float(order["goal"][0]), 0.0, float(order["goal"][1]))
				var list: Array = spots[unit_name]
				if list.is_empty() or (list[list.size() - 1] as Vector3).distance_to(goal) > SPOT_CHANGE_M:
					list.append(goal)
				if pos.distance_to(list[list.size() - 1]) <= REACH_M:
					(reached[unit_name] as Dictionary)[list.size() - 1] = true
			if trace and tick % 15 == 0:
				var brain := game_match.brains.get_node_or_null("Brain_" + unit_name) as TankBrain
				print("ENGAGE_PROBE_TRACE t=%d %s at (%.1f, %.1f) d %.1f order %s%s in_range %s shot %s moving %s choice %s why '%s'" % [
						game_match.tick, unit_name, pos.x, pos.z, pos.distance_to(target_pos), verb, "*" if named else "", in_range, shot,
						moving, brain.choice.get("option", "") if brain != null else "-", brain.why if brain != null else "-"])
		for unit_name: String in names:
			if _deaths.has(unit_name) and not death_moving.has(unit_name):
				death_moving[unit_name] = bool(moving_for_shot.get(unit_name, false))
	var window := float(game_match.tick - order_tick) / SimClock.TICK_RATE
	var line_flips := {}
	for unit_name: String in names:
		line_flips[unit_name] = int(flips.get(unit_name, 0))
	var first_hit := {}
	var never_reached := 0
	var spot_changes := {}
	for unit_name: String in names:
		first_hit[unit_name] = _r(float(int(_first_hit[unit_name]) - order_tick) / SimClock.TICK_RATE) if _first_hit.has(unit_name) else -1.0
		var list: Array = spots[unit_name]
		spot_changes[unit_name] = maxi(list.size() - 1, 0)
		for i in list.size():
			if not (reached[unit_name] as Dictionary).has(i):
				never_reached += 1
	var deaths_moving := 0
	for unit_name: String in death_moving:
		if bool(death_moving[unit_name]):
			deaths_moving += 1
	var stuck_s := {}
	var no_shot_s := {}
	for unit_name: String in names:
		stuck_s[unit_name] = _r(float(stuck_ticks[unit_name]) / SimClock.TICK_RATE)
		no_shot_s[unit_name] = _r(float(in_range_no_shot_ticks[unit_name]) / SimClock.TICK_RATE)
	print("ENGAGE_PROBE %s" % JSON.stringify({"seed": seed_value, "arena": arena, "arm": "on" if ElementPlan.ATTACK_SHOT else "off",
			"crews": crews_n, "hull": hull, "target_unit": target_unit, "feature": String(feature.get("type", "")),
			"feature_at": [_r(center.x), _r(center.z)], "target_at": [_r(target_at.x), _r(target_at.z)],
			"crew_at": placed, "target_placed": [_r(target.global_position.x), _r(target.global_position.z)],
			"start_m": start_m, "stage_ok": stage_ok, "ground_moved": ground_moved, "line_flips": line_flips,
			"start_line": start_lines, "window_s": _r(window), "seconds": seconds,
			"stuck_s": stuck_s, "no_shot_s": no_shot_s, "first_hit_s": first_hit, "hits": _hits,
			"deaths": _deaths.keys().filter(func(k: String) -> bool: return names.has(k)).size(), "deaths_moving": deaths_moving,
			"target_dead_s": _r(float(target_dead_tick - order_tick) / SimClock.TICK_RATE) if target_dead_tick >= 0 else -1.0,
			"spot_changes": spot_changes, "never_reached": never_reached,
			"lines": ElementSituation.shot_lines - lines_before, "plan_ticks": plan_ticks,
			"plan": {"shot_moves": ElementPlan.shot_moves, "shot_attacks": ElementPlan.shot_attacks, "shot_none": ElementPlan.shot_none,
					"spots_found": FiringPosition.found, "spots_none": FiringPosition.none, "spots_kept": FiringPosition.kept}}))
	print("ENGAGE_PROBE_DONE")
	lab.dispose()
	quit(0)
