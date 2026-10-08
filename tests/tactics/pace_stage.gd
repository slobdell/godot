class_name PaceStage
extends RefCounted
## Round 23 (brains B0/B1): HIS CASE, measured. "When I had tanks in line abreast and had them move somewhere, they
## never got into formation until the very end - because the lead vehicle was already close to the target point at the
## start, the other vehicles never caught up to it until it stopped." A squad of crews stands in a LINE whose own axis
## points at the click (`layout` "along": the line must swing 90 degrees into a line across the new heading, and one
## crew starts nearest the click, on or past its seat), or abreast across the heading ("across": round 20's yard case).
## One plain move of `metres`, every tick sampled against the SHAPE's stations (`Element.shape_stations`: the shape on
## the way, not the converging ones). Shared by tests/tactics/pace_probe.gd (the series) and tests/test_tactics_pace.gd.
##
## The report's fields (seconds from the order; -1 = never):
##   formed_m    the anchor's progress along its route (m from its start) when every crew was first within FORMED_M of
##               its shape station; formed_s the time; formed_frac that progress over the route's length
##   rms_m       the RMS over the transit of the crews' distances to their shape stations; rms10_m the first 10 s
##   lead_speed  the lead crew's (the one nearest the click at the order) mean speed over the first 10 s as a share of
##               its top speed; lead_pace its mean element pace over the same 10 s (1.0 = never limited)
##   pace_min    the lowest anchor pace (Element._transit_pace) seen; pace_drop_s when it first fell below 1
##   stops       (crew, episode) pairs where a crew stood (< STILL_MPS) for STOP_S or more between 2 s and the arrival
##   stop_s      the seconds those crews stood, summed
##   transit_s   the anchor's hand-off; arrived_s the element's arrival; in_slot_s every crew within IN_SLOT_M of its
##               final slot; stopped_s every crew still (as settle_probe); route_m the route's length

const FORMED_M := 3.0
const IN_SLOT_M := 3.0
const STILL_MPS := 0.3
const STILL_HOLD_S := 1.0
const STOP_S := 1.0
const START_JITTER_M := 1.5
const START_JITTER_DEG := 6.0
## His case: the parade ground's open middle, the line laid down x = 0 from z = +64 to +32 and sent to z = -100.
const PARADE_CENTRE := Vector3(0.0, 0.0, 48.0)
const PARADE_AXIS := Vector3(0.0, 0.0, -1.0)
const ROW_M := 8.0


## `layout`: "along" (his case: the line's axis is the heading) or "across" (abreast across the heading, round 20's
## yard case). `facing`: "abreast" (the hulls face across the line, as a line abreast does) or "goal". `arena` "" is the
## parade ground's open middle by hand; "yard" (or any other) lays the squad at that map's Green spawn as
## test_tactics_form_on_move does (the first spawn row, 8 m apart, facing the enemy).
static func run(case: TestCase, seed_value: int, arena: String, unit_ids: PackedStringArray, metres: float,
		layout: String, shape: String, seconds: float, facing := "abreast", trace := false) -> Dictionary:
	var lab := TacticsLab.create(case, seed_value, "parade" if arena == "" else arena)
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var centre: Vector3
	var axis: Vector3
	if arena == "":
		centre = PARADE_CENTRE
		axis = PARADE_AXIS
	else:
		var home := Match.spawn_position(Match.Team.GREEN, 0)
		centre = Vector3(home.x, 0.0, home.z)
		axis = TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-axis.z, 0.0, axis.x)
	var row: Vector3 = axis if layout == "along" else right
	# The hulls' facing: a line abreast faces across its own row; "goal" faces the click.
	var face: Vector3 = axis if facing == "goal" or layout == "across" else right
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	var names: Array = []
	for i in unit_ids.size():
		var at := centre + row * ((i - (unit_ids.size() - 1) * 0.5) * ROW_M) \
				+ right * jitter.randf_range(-START_JITTER_M, START_JITTER_M) \
				+ axis * jitter.randf_range(-START_JITTER_M, START_JITTER_M)
		var yaw := atan2(-face.x, -face.z) + deg_to_rad(jitter.randf_range(-START_JITTER_DEG, START_JITTER_DEG))
		names.append(String(lab.unit(Match.Team.GREEN, "Green_S_%d" % (i + 1), at, yaw, String(unit_ids[i])).name))
	await lab.start()
	var element := lab.elements.form(names, "Alpha")
	var goal := _flat(lab.center_of(names) + axis * metres)
	var task := {"verb": "move", "to": [goal.x, goal.z], "drills": false}
	if shape != "":
		task["formation"] = shape
	element.assign(task)
	# The lead crew: the one nearest the click when the order is given.
	var lead := ""
	var nearest := INF
	var top := {}
	for unit_name: String in names:
		var t := lab.tank_of(unit_name)
		top[unit_name] = maxf(t.max_forward_speed, 0.1)
		var d := _flat(t.global_position).distance_to(goal)
		if d < nearest:
			nearest = d
			lead = unit_name
	var given: int = game_match.tick
	var formed := -1
	var formed_m := -1.0
	var sq_sum := 0.0
	var sq_n := 0
	var sq10_sum := 0.0
	var sq10_n := 0
	var lead_speed_sum := 0.0
	var lead_pace_sum := 0.0
	var lead_n := 0
	var pace_min := 1.0
	var pace_drop := -1
	var transit_done := -1
	var transit_seen := false
	var route_m := -1.0
	var arrived := -1
	var in_slot := -1
	var stopped := -1
	var still_since := -1
	var stops := 0
	var stop_ticks := 0
	var standing := {}  # unit -> ticks standing in the current episode
	var counted := {}
	var worst_slot := 0.0
	var closest := INF
	var ticks := int(seconds * SimClock.TICK_RATE)
	for tick in ticks:
		await lab.step()
		var now: int = game_match.tick - given
		if arrived < 0 and element.arrived:
			arrived = now
		var moving := element.in_transit()
		if moving:
			transit_seen = true
			route_m = float(element.transit.get("length", -1.0))
			var pace := float(element.transit.get("pace", 1.0))
			pace_min = minf(pace_min, pace)
			if pace_drop < 0 and pace < 0.999:
				pace_drop = now
			var all_in := true
			var sq := 0.0
			var n := 0
			# The SHAPE's own stations (round 12's, laid round the anchor), not the converging ones the element publishes
			# (Element.shape_stations is the converged set: what the lag rule and the fall-in rule read).
			var shape_now := _shape_now(lab, element)
			for unit_name: String in names:
				var t := lab.tank_of(unit_name)
				var station: Variant = shape_now.get(unit_name)
				if t == null or not (station is Vector3):
					all_in = false
					continue
				var error := _flat(t.global_position).distance_to(_flat(station))
				sq += error * error
				n += 1
				if error > FORMED_M:
					all_in = false
			if n > 0:
				sq_sum += sq
				sq_n += n
				if now <= 10 * SimClock.TICK_RATE:
					sq10_sum += sq
					sq10_n += n
			if all_in and n == names.size() and formed < 0:
				formed = now
				formed_m = float(element.transit.get("s", 0.0)) - float(element.transit.get("start_s", 0.0))
		elif transit_seen and transit_done < 0:
			transit_done = now
		if now <= 10 * SimClock.TICK_RATE and lead != "":
			var t := lab.tank_of(lead)
			lead_speed_sum += t.estimated_velocity.length() / float(top[lead])
			lead_pace_sum += float((element.paces as Dictionary).get(lead, 1.0))
			lead_n += 1
		var fastest := 0.0
		worst_slot = 0.0
		var at := {}
		for unit_name: String in names:
			var t := lab.tank_of(unit_name)
			if t == null or not t.is_alive():
				continue
			at[unit_name] = _flat(t.global_position)
			var speed := t.estimated_velocity.length()
			fastest = maxf(fastest, speed)
			var slot: Variant = element.slots.get(unit_name)
			if slot is Vector3:
				worst_slot = maxf(worst_slot, _flat(t.global_position).distance_to(_flat(slot)))
			# A crew that stops dead on the way (after the first 2 s, before the element arrives).
			if arrived < 0 and now > 2 * SimClock.TICK_RATE:
				if speed < STILL_MPS:
					standing[unit_name] = int(standing.get(unit_name, 0)) + 1
					if int(standing[unit_name]) >= int(STOP_S * SimClock.TICK_RATE) and not counted.has(unit_name):
						stops += 1
						counted[unit_name] = true
					if counted.has(unit_name):
						stop_ticks += 1
				else:
					standing[unit_name] = 0
					counted.erase(unit_name)
		for a in names.size():
			for b in range(a + 1, names.size()):
				if at.has(names[a]) and at.has(names[b]):
					closest = minf(closest, (at[names[a]] as Vector3).distance_to(at[names[b]]))
		if in_slot < 0 and arrived >= 0 and worst_slot <= IN_SLOT_M:
			in_slot = now
		if fastest < STILL_MPS and arrived >= 0:
			if still_since < 0:
				still_since = now
			elif stopped < 0 and now - still_since >= int(STILL_HOLD_S * SimClock.TICK_RATE):
				stopped = still_since
		else:
			still_since = -1
		if trace and now % (SimClock.TICK_RATE / 2) == 0:
			var track := {"t": _s(now), "anchor": null, "pace": null, "crews": {}, "stations": {}, "speeds": {}, "paces": {}}
			if moving:
				var a: Vector3 = element.transit["anchor"]
				track["anchor"] = [snappedf(a.x, 0.1), snappedf(a.z, 0.1)]
				track["pace"] = snappedf(float(element.transit.get("pace", 1.0)), 0.01)
			for unit_name: String in names:
				var t := lab.tank_of(unit_name)
				if t != null:
					track["crews"][unit_name] = [snappedf(t.global_position.x, 0.1), snappedf(t.global_position.z, 0.1)]
					track["speeds"][unit_name] = snappedf(t.estimated_velocity.length(), 0.1)
					track["paces"][unit_name] = snappedf(float((element.paces as Dictionary).get(unit_name, 1.0)), 0.01)
					# The mover's own reading: ORCA's pace and deflection, the station PID, the order's speed and goal.
					var mover := Movement.of(t)
					var brain := game_match.brains.get_node_or_null(NodePath("Brain_" + unit_name)) as TankBrain
					if mover != null:
						var aim: Variant = mover.ctl.move_order.get("goal") if "move_order" in mover.ctl else null
						track["movers"] = track.get("movers", {})
						track["movers"][unit_name] = {"orca": snappedf(mover.pace_now, 0.01), "defl": mover._deflected,
								"pid": mover.get("stationed_now"), "gw": mover.get("give_ways"), "thr": snappedf(float(t.command.throttle), 0.01) if t.command != null else null,
								"spd": snappedf(float(mover.ctl.move_order.get("speed", 1.0)), 0.01) if "move_order" in mover.ctl else null,
								"goal": [snappedf((aim as Vector3).x, 0.1), snappedf((aim as Vector3).z, 0.1)] if aim is Vector3 else null,
								"why": brain.why if brain != null and "why" in brain else ""}
				var st: Variant = element.shape_stations.get(unit_name)
				if st is Vector3:
					track["stations"][unit_name] = [snappedf((st as Vector3).x, 0.1), snappedf((st as Vector3).z, 0.1)]
			if moving:
				track["shape"] = {}
				var shape_now := _shape_now(lab, element)
				for unit_name: String in shape_now:
					track["shape"][unit_name] = [snappedf((shape_now[unit_name] as Vector3).x, 0.1), snappedf((shape_now[unit_name] as Vector3).z, 0.1)]
			print("PACE_TRACK " + JSON.stringify(track))
		if stopped >= 0 and in_slot >= 0 and now > transit_done + 2 * SimClock.TICK_RATE:
			break
	var report := {"seed": seed_value, "arena": "parade" if arena == "" else arena, "units": ":".join(unit_ids),
			"metres": metres, "layout": layout, "shape": shape, "facing": facing, "formation": element.formation,
			"route_m": snappedf(route_m, 0.1), "lead": lead,
			"formed_s": _s(formed), "formed_m": snappedf(formed_m, 0.1),
			"formed_frac": snappedf(formed_m / route_m, 0.01) if formed_m >= 0.0 and route_m > 0.0 else -1.0,
			"rms_m": snappedf(sqrt(sq_sum / sq_n), 0.1) if sq_n > 0 else -1.0,
			"rms10_m": snappedf(sqrt(sq10_sum / sq10_n), 0.1) if sq10_n > 0 else -1.0,
			"lead_speed": snappedf(lead_speed_sum / lead_n, 0.01) if lead_n > 0 else -1.0,
			"lead_pace": snappedf(lead_pace_sum / lead_n, 0.01) if lead_n > 0 else -1.0,
			"pace_min": snappedf(pace_min, 0.01), "pace_drop_s": _s(pace_drop),
			"stops": stops, "stop_s": _s(stop_ticks),
			"transit_s": _s(transit_done), "arrived_s": _s(arrived), "in_slot_s": _s(in_slot), "stopped_s": _s(stopped),
			"worst_slot_m": snappedf(worst_slot, 0.1), "closest_m": snappedf(closest, 0.1) if is_finite(closest) else -1.0}
	lab.dispose()
	return report


## The shape's own stations now, where each hull can stand (the same grounding as the brain's station: a seat laid in
## a container wall is measured where the crew can really get to, in both arms).
static func _shape_now(lab: TacticsLab, element: Element) -> Dictionary:
	var shape := ElementPlan.stations_along({"seats": element.seats, "formation": element.formation,
			"pitch": element.pitch}, element.transit)
	var node := lab.game_match.tanks.get_child(0) as Node3D if lab.game_match.tanks.get_child_count() > 0 else null
	for unit_name: String in shape:
		var t := lab.tank_of(unit_name)
		if node != null and t != null:
			shape[unit_name] = SlotGround.standable_for(node, shape[unit_name], SlotGround.envelope_of(t.unit_id))
	return shape


static func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)


static func _s(ticks: int) -> float:
	return snappedf(ticks / float(SimClock.TICK_RATE), 0.1) if ticks >= 0 else -1.0
