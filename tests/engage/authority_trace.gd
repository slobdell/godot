extends "res://tests/replay_orders.gd"
## Round 45 (engage E1): his Gorge replay with one AUTHORITY row per sample for the crews he steers alone: who is
## commanding the crew at that moment. The replay driver (native's tests/replay_orders.gd) issues his orders through
## RtsControls exactly as he clicked them; this adds the read of every layer that can move the crew:
##   order    its K1 order (verb, source, goal) and the order's id
##   element  the element it belongs to (or none), that element's task verb, its drill and why, and whether the crew is
##            detached from it
##   brain    the TankBrain's chosen option and the order it is acting on
##   mover    the mover's phase and goal
## `--authority-on-at=TICK` (E4, his acceptance read): replay his match as he played it (give `--player-authority=off`) and
## switch the rule ON at TICK, so his later clicks still meet the match they were made in.
## `--lane-clear-on-at=TICK` (round 46, L5): the same for the lane rule (give `--lane-clear=off`).
## `--authority-units=A,B` names the crews (default Green_Hunters_5); `--authority-from=TICK` / `--authority-every=N`.
##   godot --headless --fixed-fps 30 --path . --script res://tests/engage/authority_trace.gd -- --orders=<his jsonl> \
##         --seconds=107 [--authority-from=2500 --authority-every=3] [any game switch]

var _last := {}
## Round 45 (his Terminus playtest, "it wasn't shooting at anything"): rounds fired per traced crew (weapon_fired).
var _shots := {}
var _shots_hooked := false
## `--shots=T1,T2,... --shot-out=DIR --shot-name=NAME` (needs a window): the RTS camera on the first traced crew, a PNG at
## each tick, so his replay before / after is looked at with the same eyes (E4).
var _shot_ticks := {}
var _shots_read := false
var _framed := false
## Round 46 (engage L1): the last CLEAR_LANE read printed per crew (its tick), so each `_lane_spot` call prints once.
var _lane_printed := {}


func _trace() -> void:
	super._trace()
	if _match == null:
		return
	var off_at := int(_flag("authority-off-at", "-1"))
	if off_at >= 0 and _match.tick >= off_at and Drills.PLAYER_AUTHORITY:
		Drills.PLAYER_AUTHORITY = false
		print("AUTHORITY_SWITCH off at tick %d" % _match.tick)
	var on_at := int(_flag("authority-on-at", "-1"))
	if on_at >= 0 and _match.tick >= on_at and not Drills.PLAYER_AUTHORITY:
		Drills.PLAYER_AUTHORITY = true
		print("AUTHORITY_SWITCH on at tick %d" % _match.tick)
	TankBrain.LANE_READ = true
	# Round 46 (L5): his game as played (`--lane-clear=off`), the lane rule switched ON at TICK.
	var lane_at := int(_flag("lane-clear-on-at", "-1"))
	if lane_at >= 0 and _match.tick >= lane_at and not TankBrain.LANE_CLEAR:
		TankBrain.LANE_CLEAR = true
		print("LANE_SWITCH on at tick %d" % _match.tick)
	_shoot()
	if not _shots_hooked and _match != null:
		_shots_hooked = true
		_match.weapon_fired.connect(func(event: Dictionary) -> void:
			var who := String(event.get("shooter", ""))
			_shots[who] = int(_shots.get(who, 0)) + 1)
	var from := int(_flag("authority-from", "2500"))
	var every := maxi(int(_flag("authority-every", "3")), 1)
	if _match.tick < from:
		return
	for unit_name: String in _flag("authority-units", "Green_Hunters_5").split(","):
		var tank := _match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank == null or not tank.is_alive():
			continue
		var row := _row(tank)
		var key := JSON.stringify(row.duplicate().merged({"pos": null, "t": null}, true))
		# Every Nth tick, and on any change of who commands it.
		if _match.tick % every != 0 and key == String(_last.get(unit_name, "")):
			continue
		_last[unit_name] = key
		print("AUTHORITY " + JSON.stringify(row))
		_print_lane(tank)


func _row(tank: Tank) -> Dictionary:
	var unit_name := String(tank.name)
	var row := {"t": _match.tick, "n": unit_name, "pos": [snappedf(tank.global_position.x, 0.1), snappedf(tank.global_position.z, 0.1)],
			"v": snappedf(tank.estimated_velocity.length(), 0.1)}
	var orders := _controls.orders
	var order: Dictionary = orders.current(unit_name) if orders != null else {}
	row["order"] = String(order.get("verb", ""))
	row["src"] = String(order.get("source", ""))
	row["id"] = int(order.get("id", -1))
	if order.has("goal"):
		row["goal"] = [snappedf(float(order["goal"][0]), 0.1), snappedf(float(order["goal"][1]), 0.1)]
	var element: Element = _controls.elements.of(unit_name) if _controls.elements != null else null
	if element == null:
		row["element"] = ""
	else:
		row["element"] = element.element_name
		row["task"] = String(element.task.get("verb", ""))
		row["drills"] = element.task.get("drills", true)
		row["drill"] = element.drill
		row["why"] = element.reason
		row["detached"] = element.is_detached(unit_name)
		row["issued"] = String(element.issued_to(unit_name).get("verb", ""))
	var brain := _match.brains.get_node_or_null("Brain_" + unit_name) as TankBrain
	row["shots"] = int(_shots.get(unit_name, 0))
	var reach := float(tank.weapon.get("range", 0.0))
	var seen := 0
	for enemy: Tank in Perception.enemies_of(tank, _match.tanks):
		if tank.global_position.distance_to(enemy.global_position) <= reach and _match.is_visible_to(tank.team, enemy):
			seen += 1
	row["in_range_seen"] = seen
	# ...and of those, how many this crew itself has a line to (Perception: its own sight ray, not the team's picture).
	var own := 0
	for enemy: Tank in Perception.enemies_of(tank, _match.tanks):
		if tank.global_position.distance_to(enemy.global_position) <= reach and Perception.has_line_of_sight(tank, enemy):
			own += 1
	row["in_range_own_los"] = own
	row["ammo"] = tank.ammo
	row["heat"] = snappedf(tank.heat, 0.1)
	row["heat_cap"] = tank.heat_capacity
	row["reload"] = tank._reload_ticks
	if brain != null:
		row["weapon"] = String(brain.weapon_order.get("type", ""))
		row["trigger"] = tank.command.fire
		var gun: Gunnery = brain.gunnery
		row["lane_blocker"] = gun.lane_blocker
		row["lane_ticks"] = gun.lane_blocked_ticks
		row["refused"] = brain.held_moves_refused
		var lane_goal: Variant = brain._lane_goal
		if lane_goal is Vector3:
			row["lane_goal"] = [snappedf((lane_goal as Vector3).x, 0.1), snappedf((lane_goal as Vector3).z, 0.1)]
			row["lane_goal_m"] = snappedf(tank.global_position.distance_to(lane_goal), 0.1)
		row["move"] = String(brain.move_order.get("type", ""))
		if brain.move_order.has("x"):
			row["move_to"] = [snappedf(float(brain.move_order["x"]), 0.1), snappedf(float(brain.move_order["z"]), 0.1)]
		# Round 46 (L1): the blocker: moving or parked, and under what order.
		if gun.lane_blocker != "":
			var blocker := _match.tanks.get_node_or_null(NodePath(gun.lane_blocker)) as Tank
			if blocker != null:
				row["blk_v"] = snappedf(blocker.estimated_velocity.length(), 0.1)
				row["blk_m"] = snappedf(tank.global_position.distance_to(blocker.global_position), 0.1)
				var blk_order: Dictionary = orders.current(gun.lane_blocker) if orders != null else {}
				row["blk_order"] = String(blk_order.get("verb", ""))
				row["blk_phase"] = String(Movement.state(blocker).get("phase", ""))
				var blk_brain := _match.brains.get_node_or_null("Brain_" + gun.lane_blocker) as TankBrain
				if blk_brain != null:
					row["blk_option"] = String(blk_brain.choice.get("option", ""))
		row["held_s"] = snappedf(gun.engagement_lay.held_s if "held_s" in gun.engagement_lay else -1.0, 0.1)
	if brain != null and brain.engaged_target != "":
		var target := _match.tanks.get_node_or_null(NodePath(brain.engaged_target)) as Tank
		if target != null:
			row["eng_m"] = snappedf(tank.global_position.distance_to(target.global_position), 0.1)
			row["eng_los"] = Perception.has_line_of_sight(tank, target)
	if brain != null:
		row["engaged"] = brain.engaged_target
		row["ctx"] = String((brain._order_context() as Dictionary).get("verb", "")) if brain._order_context() != null else ""
		row["option"] = String(brain.choice.get("option", ""))
		row["b_order"] = String(brain.order.get("verb", ""))
		var post: Variant = brain._player_post
		if post is Vector3:
			row["post"] = [snappedf((post as Vector3).x, 0.1), snappedf((post as Vector3).z, 0.1)]
	var mover := Movement.state(tank)
	row["phase"] = String(mover.get("phase", ""))
	# Round 45 (E5): which way the hull points (deg, 0 = -Z, positive = left) and whether it is backing up, and the mover's
	# last replan reason: a short move given while the crew drives the other way.
	var fwd := -tank.global_basis.z
	row["yaw"] = snappedf(rad_to_deg(atan2(-fwd.x, -fwd.z)), 1.0)
	row["rev"] = tank.command.throttle < -0.05
	row["thr"] = snappedf(tank.command.throttle, 0.01)
	var mv := Movement.of(tank)
	if mv != null:
		row["behind"] = String(mv._behind_plan)
		row["kturn_m"] = snappedf(mv._kturn_left_m, 0.1)
	var goal: Variant = mover.get("goal")
	if goal is Vector3:
		row["m_goal"] = [snappedf((goal as Vector3).x, 0.1), snappedf((goal as Vector3).z, 0.1)]
	return row


func _shoot() -> void:
	if not _shots_read:
		_shots_read = true
		for part in _flag("shots", "").split(",", false):
			_shot_ticks[int(part)] = true
	if _shot_ticks.is_empty():
		return
	var rig := current_scene.find_child("RtsCamera", true, false) as RtsCamera
	var crew := _match.tanks.get_node_or_null(NodePath(_flag("authority-units", "Green_Hunters_5").split(",")[0])) as Tank
	if rig != null and crew != null and crew.is_alive():
		rig.focus_on(crew.global_position)
		if not _framed:
			rig.zoom = minf(rig.zoom, 0.35)
			_framed = true
	if not _shot_ticks.has(_match.tick):
		return
	_shot_ticks.erase(_match.tick)
	var tick := _match.tick
	await RenderingServer.frame_post_draw
	var file := "%s/%s-t%d.png" % [_flag("shot-out", "build/engage/shots"), _flag("shot-name", "shot"), tick]
	var err := root.get_viewport().get_texture().get_image().save_png(file)
	print("SHOT_SAVED %d %s%s" % [tick, file, "" if err == OK else " FAILED " + error_string(err)])


## Round 46 (engage L1): each CLEAR_LANE spot search once: the 16 candidates and why each was rejected, the one chosen.
func _print_lane(tank: Tank) -> void:
	var brain := _match.brains.get_node_or_null("Brain_" + String(tank.name)) as TankBrain
	if brain == null or brain.lane_read.is_empty():
		return
	var tick := int(brain.lane_read.get("tick", -1))
	if int(_lane_printed.get(String(tank.name), -2)) == tick:
		return
	_lane_printed[String(tank.name)] = tick
	print("LANE_READ " + JSON.stringify({"n": String(tank.name), "pos": [snappedf(tank.global_position.x, 0.1),
			snappedf(tank.global_position.z, 0.1)]}.merged(brain.lane_read)))
