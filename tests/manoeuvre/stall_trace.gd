extends "res://tests/replay_orders.gd"
## Round 47 (manoeuvre M1), MEASUREMENT ONLY: his playtest replayed (tests/replay_orders.gd, every switch as he played) with one
## STALL_TRACE line per tick for each named crew inside the window: pose, speed, the move order, the mover's goal / next station /
## steer point / pace, the remaining route and its best so far, the stall clocks (stalled_ticks, _stuck_time, unstick / escape /
## k-turn state), traffic holds and waits, the yield, and every body the hull touched this tick (buildings, containers, hulls).
##   godot --headless --fixed-fps 30 --path . --script res://tests/manoeuvre/stall_trace.gd -- --orders=<his.jsonl> --seconds=12 \
##         --stall-trace=Green_Burners2_4,Green_Burners_2 --stall-window=120-320
## `make manoeuvre-stall-trace` runs it (mk/manoeuvre.mk).


func _trace() -> void:
	super._trace()
	var names := _flag("stall-trace", "").split(",", false)
	if names.is_empty():
		return
	var bounds := _flag("stall-window", "0-999999").split("-")
	if _match.tick < int(bounds[0]) or _match.tick > int(bounds[bounds.size() - 1]):
		return
	for n in names:
		var tank := _match.tanks.get_node_or_null(NodePath(n)) as Tank
		if tank == null or not tank.is_alive():
			continue
		var mover := Movement.of(tank)
		if mover == null:
			continue
		print("STALL_TRACE " + JSON.stringify(_row(tank, mover)))


static func _xz(v: Variant) -> Variant:
	if v is Vector3 and (v as Vector3) != Vector3.INF:
		return [snappedf((v as Vector3).x, 0.01), snappedf((v as Vector3).z, 0.01)]
	return null


func _row(tank: Tank, m: Movement) -> Dictionary:
	var fwd := -tank.global_basis.z
	var hits: Array = []
	for i in tank.get_slide_collision_count():
		var c := tank.get_slide_collision(i)
		var body := c.get_collider() as Node
		hits.append([String(body.name) if body != null else "?", _xz(c.get_position()), _xz(c.get_normal())])
	var order: Dictionary = m.ctl.move_order
	var next_station: Variant = null
	if m._path_index < m._path.size():
		next_station = _xz(m._path[m._path_index])
	var name := String(tank.name)
	# The element's travelling station for this crew (raw, as published) and where the brain's grounding puts it.
	var el_station: Variant = null
	var el_ground: Variant = null
	var el_pace := -1.0
	var elements: Variant = Elements.of_match(_match)
	var mine: Variant = elements.of(name) if elements != null else null
	if mine != null and (mine.stations as Dictionary).get(name) is Vector3:
		var raw: Vector3 = mine.stations[name]
		el_station = _xz(raw)
		el_ground = _xz(SlotGround.standable_for(tank, raw, SlotGround.envelope_of(tank.unit_id)))
		el_pace = float((mine.paces as Dictionary).get(name, -1.0))
	return {"el_station": el_station, "el_ground": el_ground, "el_pace": snappedf(el_pace, 0.01),"tick": _match.tick, "n": name, "pos": _xz(tank.global_position), "yaw": snappedf(rad_to_deg(atan2(-fwd.x, -fwd.z)), 0.1),
			"v": snappedf(tank.velocity.length(), 0.01), "rv": snappedf(tank.real_velocity.length(), 0.01),
			"thr": snappedf(tank.command.throttle, 0.001), "turn": snappedf(tank.command.turn, 0.001),
			"order": String(order.get("type", "")), "ox": snappedf(float(order.get("x", 0.0)), 0.01), "oz": snappedf(float(order.get("z", 0.0)), 0.01),
			"paced": bool(order.get("paced", false)), "direct": bool(order.get("direct", false)),
			"goal": _xz(m._goal), "station": next_station, "pi": m._path_index, "pn": m._path.size(), "steer": _xz(m.steer_to),
			"pace": snappedf(m.pace_now, 0.01), "rem": snappedf(m._remaining, 0.01), "best": snappedf(m._progress_best, 0.01),
			"phase": m.phase, "blocked": m.blocked_by, "stalled": m.stalled_ticks, "stuck_t": snappedf(m._stuck_time, 0.01),
			"unstick_left": snappedf(m._unstick_left, 0.01), "esc": m._esc_stage, "kturn_m": snappedf(m._kturn_left_m, 0.01),
			"yield_to": m.yield_to, "wait_for": m._wait_for, "hold": Traffic.holding(name), "deflected": m._deflected,
			"planner": PlannerSeam.on() and PlannerSeam.live(name), "short_halt": snappedf(tank.short_halt_seconds, 0.01),
			"wall": m.contact.touching, "cause": m.contact.cause, "collider": m.contact.collider, "hits": hits,
			"native": NativeDrive.usable(m)}
