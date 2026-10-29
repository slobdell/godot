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
## `--authority-units=A,B` names the crews (default Green_Hunters_5); `--authority-from=TICK` / `--authority-every=N`.
##   godot --headless --fixed-fps 30 --path . --script res://tests/engage/authority_trace.gd -- --orders=<his jsonl> \
##         --seconds=107 [--authority-from=2500 --authority-every=3] [any game switch]

var _last := {}
## `--shots=T1,T2,... --shot-out=DIR --shot-name=NAME` (needs a window): the RTS camera on the first traced crew, a PNG at
## each tick, so his replay before / after is looked at with the same eyes (E4).
var _shot_ticks := {}
var _shots_read := false
var _framed := false


func _trace() -> void:
	super._trace()
	if _match == null:
		return
	var on_at := int(_flag("authority-on-at", "-1"))
	if on_at >= 0 and _match.tick >= on_at and not Drills.PLAYER_AUTHORITY:
		Drills.PLAYER_AUTHORITY = true
		print("AUTHORITY_SWITCH on at tick %d" % _match.tick)
	_shoot()
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
	if brain != null:
		row["option"] = String(brain.choice.get("option", ""))
		row["b_order"] = String(brain.order.get("verb", ""))
		var post: Variant = brain._player_post
		if post is Vector3:
			row["post"] = [snappedf((post as Vector3).x, 0.1), snappedf((post as Vector3).z, 0.1)]
	var mover := Movement.state(tank)
	row["phase"] = String(mover.get("phase", ""))
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
