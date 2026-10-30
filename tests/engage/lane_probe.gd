extends SceneTree
## Round 46 (engage L4, Bar L1's workload): HIS CASE AS A PROBE. A crew with an enemy gun in range and its own squadmates
## parked in or beside its line of fire (his IFV behind his squads on Terminus, 116-140 s). Drawn from the seed: the arena
## (gorge / locks / terminus / crossing), the crew's hull, the enemy's, the range (18-32 m), one squadmate in the lane (35-65 %
## of the way, within 1.5 m of the line) and one or two beside it, and on a third of the seeds the one in the lane driving
## ACROSS it instead of parked. Who commands the crew (by seed): his ATTACK on the gun, his MOVE done (the post it left him
## at), or the CPU (no player: its own brain; the rule is symmetric, C46.6). The friends hold their fire (blockers, not help);
## the gun shoots back. The arm is `--lane-clear=on|off`, so both arms see the same stage and pair by seed.
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/engage/lane_probe.gd -- --seed=N [--lane-clear=off]
##         [--seconds=30] [--mode=attack|post|cpu] [--arena=A]
## Prints LANE_PROBE {json} once (tests/engage/lane_table.py):
##   held_s        seconds the crew's gun was held for a friend (its held count grew that tick) while its gun had a target
##                 (the deciding line: his "it wasn't shooting")
##   first_shot_s  seconds from the first hold to the next round fired (the window's rest when it never fires again)
##   shots         rounds the crew fired; ff_hits / ff_kills: friendly fire BY the crew (must not rise: the rule never
##                 fires through a friend)
##   died          the crew died in the window; enemy_hp: the gun's health left (did the crew still hurt it)
##   moved_m       the farthest the crew got from where it started; post_m (mode post): from his post
##   lines         feed lines "holding fire" that HudMessages would post with the crew selected (modes attack / post)

const ARENAS := ["gorge", "locks", "terminus", "crossing"]
const HULLS := ["ifv", "gang_ifv", "law_ifv", "syn_ifv", "tank", "gang_tank", "scout", "law_scout"]
const TARGETS := ["ifv", "syn_scout", "law_artillery", "syn_ifv", "gang_scout"]
const MODES := ["attack", "post", "cpu"]
const RANGE_MIN := 18.0
const RANGE_MAX := 32.0
const STAND_M := 4.0

var case: TestCase


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


func _standable(map: CoverMap, point: Vector3) -> bool:
	var limit := Match.DRIVABLE_LIMIT - 10.0
	return absf(point.x) <= limit and absf(point.z) <= limit and not map.inside_any(Vector2(point.x, point.z), STAND_M)


## The stage: the crew, the gun (a clear line between them), the squadmate in the lane and one or two beside it, all
## standable. {} when this draw does not stand.
func _stage(map: CoverMap, rng: RandomNumberGenerator, beside_n: int) -> Dictionary:
	var limit := Match.DRIVABLE_LIMIT - 30.0
	var me := Vector3(rng.randf_range(-limit, limit), 0.0, rng.randf_range(-limit, limit))
	var heading := rng.randf_range(0.0, TAU)
	var lane := Vector3(cos(heading), 0.0, sin(heading))
	var side := Vector3(-lane.z, 0.0, lane.x)
	var gun := me + lane * rng.randf_range(RANGE_MIN, RANGE_MAX)
	var length := me.distance_to(gun)
	if not _standable(map, me) or not _standable(map, gun) or not map.clear_line(me, gun):
		return {}
	var friends: Array = [me + lane * length * rng.randf_range(0.35, 0.65) + side * rng.randf_range(-1.5, 1.5)]
	for i in beside_n:
		var sign := 1.0 if rng.randf() < 0.5 else -1.0
		friends.append(me + lane * length * rng.randf_range(0.2, 0.8) + side * sign * rng.randf_range(3.0, 8.0))
	for i in friends.size():
		if not _standable(map, friends[i]):
			return {}
		for j in i:
			if (friends[i] as Vector3).distance_to(friends[j]) < 6.0:
				return {}
		if (friends[i] as Vector3).distance_to(me) < 6.0 or (friends[i] as Vector3).distance_to(gun) < 6.0:
			return {}
	return {"me": me, "gun": gun, "lane": lane, "side": side, "friends": friends}


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	var seed_value := int(_flag("seed", "7001"))
	var seconds := float(_flag("seconds", "30"))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var hull: String = HULLS[rng.randi_range(0, HULLS.size() - 1)]
	var target_unit: String = TARGETS[rng.randi_range(0, TARGETS.size() - 1)]
	var mode := _flag("mode", MODES[seed_value % MODES.size()])
	var beside_n := 1 + rng.randi_range(0, 1)
	var crossing := rng.randf() < 0.34
	var arena := _flag("arena", ARENAS[(seed_value / MODES.size()) % ARENAS.size()])
	var lab := TacticsLab.create(case, seed_value, arena)
	var game_match := lab.game_match
	if mode != "cpu":
		game_match.set_meta("player_team", Match.Team.GREEN)
	var map := CoverMap.of(game_match)
	var stage := {}
	for attempt in 400:
		stage = _stage(map, rng, beside_n)
		if not stage.is_empty():
			break
	if stage.is_empty():
		print("LANE_PROBE %s" % JSON.stringify({"seed": seed_value, "arena": arena, "error": "no stage stands"}))
		quit(0)
		return
	var lane: Vector3 = stage["lane"]
	var side: Vector3 = stage["side"]
	var yaw := atan2(-lane.x, -lane.z)
	var crew := lab.unit(Match.Team.GREEN, "Green_Hunters_1", stage["me"], yaw, hull)
	var friends: Array = []
	var friend_names: Array = []
	for i in (stage["friends"] as Array).size():
		var friend := lab.gun(Match.Team.GREEN, "Green_Guns_%d" % (i + 1), stage["friends"][i], yaw + rng.randf_range(-1.2, 1.2), "tank")
		lab.game_match.brains.get_node("Orders_" + String(friend.name)).set_orders({"type": "stop"}, {"type": "hold_fire"})
		friends.append(friend)
		friend_names.append(String(friend.name))
	var target := lab.gun(Match.Team.RUST, "Rust_Eyes_3", stage["gun"], yaw + PI, target_unit)
	var crew_name := String(crew.name)
	var shots := [0]
	var shot_ticks: Array = []
	game_match.weapon_fired.connect(func(event: Dictionary) -> void:
		if String(event.get("shooter", "")) == crew_name:
			shots[0] += 1
			shot_ticks.append(game_match.tick)
			if _flag("trace", "off") == "on":
				print("LANE_SHOT t=%d crew_at=%s v=%.1f in_line_now=%s" % [game_match.tick, _flat(crew.global_position),
						crew.estimated_velocity.length(), FireLanes.for_shot(game_match.tanks, crew, target.global_position)]))
	var ff := [0, 0]
	var trace := _flag("trace", "off") == "on"
	game_match.friendly_fire.connect(func(victim: Tank, shooter: String, _hull: int, killed: bool) -> void:
		if shooter == crew_name:
			ff[0] += 1
			if killed:
				ff[1] += 1
			if trace:
				var b := game_match.brains.get_node_or_null("Brain_" + crew_name) as TankBrain
				print("LANE_FF t=%d victim=%s at=%s crew_at=%s crew_v=%.1f option=%s blocker=%s held=%d target_at=%s" % [game_match.tick,
						victim.name, _flat(victim.global_position), _flat(crew.global_position), crew.estimated_velocity.length(),
						b.choice.get("option", "") if b != null else "-", b.lane_blocker if b != null else "-",
						b.lane_blocked_ticks if b != null else -1, _flat(target.global_position)]))
	await lab.start()
	var ground_node := game_match.tanks.get_child(0) as Node3D
	for tank: Tank in [crew, target] + friends:
		var at := SlotGround.standable_for(ground_node, _flat(tank.global_position), SlotGround.envelope_of(tank.unit_id))
		if at.distance_to(_flat(tank.global_position)) > 0.5:
			tank.place(at, tank.rotation.y)
	for i in 3:
		await lab.step()
	var start := _flat(crew.global_position)
	var crew_pose := [_r(start.x), _r(start.z), snappedf(crew.rotation.y, 0.001)]
	var target_pose := [_r(target.global_position.x), _r(target.global_position.z), snappedf(target.rotation.y, 0.001)]
	var friend_starts: Array = []
	for friend: Tank in friends:
		friend_starts.append([_r(friend.global_position.x), _r(friend.global_position.z), snappedf(friend.rotation.y, 0.001), String(friend.name)])
	var orders: Object = lab.orders
	if mode == "attack":
		orders.call("issue", {"units": [crew_name], "verb": "attack", "target": String(target.name), "source": "player"})
	elif mode == "post":
		orders.call("issue", {"units": [crew_name], "verb": "move", "to": [start.x + lane.x * 0.5, start.z + lane.z * 0.5],
				"source": "player"})
	# The squadmate in the lane drives across it (a third of the seeds): 14 m to one side and back, once each way.
	var lane_friend: Tank = friends[0]
	var cross_ends: Array = []
	if crossing:
		var middle := _flat(lane_friend.global_position)
		cross_ends = [middle + side * 7.0, middle - side * 7.0]
		lab.game_match.brains.get_node("Orders_" + String(lane_friend.name)).set_orders(
				{"type": "move_to", "x": (cross_ends[0] as Vector3).x, "z": (cross_ends[0] as Vector3).z}, {"type": "hold_fire"})
	# The feed as he would see it with the crew selected (modes with a player).
	var lines: Array = []
	var messages: HudMessages = null
	if mode != "cpu":
		var selected := SelectionOf.new()
		selected.units.append(crew_name)
		messages = HudMessages.new()
		messages.game_match = game_match
		messages.selection_source = selected
		messages.posted.connect(func(text: String, _severity: int) -> void:
			if text.contains("holding fire"):
				lines.append(text))
		game_match.add_child(messages)
	var brain := game_match.brains.get_node("Brain_" + crew_name) as TankBrain
	var start_tick := game_match.tick
	var held_ticks := 0
	var first_block := -1
	var last_count := brain.lane_blocked_ticks
	var moved := 0.0
	var post_m := 0.0
	var going := 0
	var died := false
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		if not crew.is_alive():
			died = true
			break
		if not target.is_alive():
			break
		var count := brain.lane_blocked_ticks
		if count > last_count and brain.engaged_target != "":
			held_ticks += count - last_count
			if first_block < 0:
				first_block = game_match.tick
		last_count = count
		var here := _flat(crew.global_position)
		moved = maxf(moved, here.distance_to(start))
		if _flag("trace", "off") == "on" and tick % 15 == 0:
			var cur: Dictionary = (orders.call("current", crew_name) as Dictionary)
			print("LANE_STATE t=%d at=%s v=%.1f option=%s why=%s move=%s order=%s phase=%s hp=%d since_hit=%d" % [game_match.tick, here,
					crew.estimated_velocity.length(), brain.choice.get("option", ""), brain.why, JSON.stringify(brain.move_order),
					String(cur.get("verb", "")), String(Movement.state(crew).get("phase", "")), crew.health, crew.ticks_since_hit])
		if mode == "post":
			post_m = maxf(post_m, here.distance_to(start))
		if crossing and lane_friend.is_alive() and going < 2 \
				and _flat(lane_friend.global_position).distance_to(cross_ends[going % 2]) < 3.0:
			going += 1
			var next: Vector3 = cross_ends[going % 2]
			lab.game_match.brains.get_node("Orders_" + String(lane_friend.name)).set_orders(
					{"type": "move_to", "x": next.x, "z": next.z}, {"type": "hold_fire"})
	var window_ticks := game_match.tick - start_tick
	var first_shot_s := -1.0
	if first_block >= 0:
		first_shot_s = float(window_ticks - (first_block - start_tick)) / SimClock.TICK_RATE
		for at: int in shot_ticks:
			if at >= first_block:
				first_shot_s = float(at - first_block) / SimClock.TICK_RATE
				break
	var result := {"seed": seed_value, "arena": arena, "mode": mode, "hull": hull, "target": target_unit,
			"lane_clear": TankBrain.LANE_CLEAR, "native": NativeBridge.available, "crossing": crossing, "friends": friends.size(),
			"range_m": _r((stage["me"] as Vector3).distance_to(stage["gun"])), "window_s": _r(float(window_ticks) / SimClock.TICK_RATE),
			"held_s": _r(float(held_ticks) / SimClock.TICK_RATE), "blocked": first_block >= 0, "first_shot_s": _r(first_shot_s),
			"shots": shots[0], "ff_hits": ff[0], "ff_kills": ff[1], "died": died,
			"enemy_hp": _r(float(target.health) / maxf(float(target.max_health), 1.0)) if target.is_alive() else 0.0,
			"moved_m": _r(moved), "post_m": _r(post_m), "lines": lines.size(),
			# The stage as placed (after grounding), so a run can be rebuilt as a test: [x, z, yaw] per hull.
			"stage": {"crew": crew_pose, "gun": target_pose, "friends": friend_starts}}
	print("LANE_PROBE %s" % JSON.stringify(result))
	quit(0)


## His selection, as RtsControls reports it to HudMessages.
class SelectionOf:
	extends RefCounted
	var units: Array[String] = []

	func selection_state() -> Dictionary:
		return {"units": units.duplicate()}
