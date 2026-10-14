extends SceneTree
## planner P0 (round 30): two of the failure modes reproduced on main's code, in a TacticsLab, with today's drive.
##
##   --case=face  F3, the boxed-in face: four War Rigs (gang_tank, 3.32 x 14 m, R 12) in a line abreast at PITCH m,
##                all heading north, each given a `face` order due east at the same tick (the drawn facing of a line
##                task, as the element issues it). Per second: each rig's heading error, distance off its spot, speed,
##                what Movement is doing (face legs / creep); at the end: seconds until each is within 8 deg, legs
##                (gear changes), drift, and how many never got there in LIMIT_S.
##   --case=gate  F4, the arrival gate: a car (law_scout, R 5.5) 9 m south of a slot, heading north, ordered to the slot
##                with a facing SOUTH (180 deg from its approach). Per second: where it goes; at the end: the farthest
##                it got from the slot, metres driven, seconds to arrive on the heading.
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/planner/boxed_face_probe.gd -- --case=face|gate|all
##         [--pitch=12] [--unit=gang_tank] [--seconds=75] [--turn-log]
##   PLANNER_PROBE lines per second; PLANNER_PROBE_DONE {json} per case.

const ALIGNED_DEG := 8.0
const CUSP_SPEED := 0.3
const ARRIVE_M := 2.5


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	BrainSwitches.ensure_parsed()
	var which := _flag("case", "all")
	if which == "face" or which == "all":
		await _face_case()
	if which == "gate" or which == "all":
		await _gate_case()
	quit(0)


static func _heading_deg(tank: Tank) -> float:
	var nose := -tank.global_basis.z
	return rad_to_deg(atan2(nose.x, -nose.z))


## A heading error against `want_deg`, signed, in (-180, 180].
static func _err_deg(tank: Tank, want_deg: float) -> float:
	return rad_to_deg(angle_difference(deg_to_rad(_heading_deg(tank)), deg_to_rad(want_deg)))


func _controller_of(lab: TacticsLab, tank: Tank) -> OrderController:
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == tank:
			return child
	return null


func _face_case() -> void:
	var case := TestCase.new()
	case.tree = self
	var unit_id := _flag("unit", "gang_tank")
	var pitch := float(_flag("pitch", "12"))
	var seconds := float(_flag("seconds", "75"))
	var lab := TacticsLab.create(case, 31)
	var tanks: Array[Tank] = []
	var home: Array[Vector3] = []
	var x0 := TacticsScenarios.LANE_X + 40.0  # open ground east of the lane (the foundry's west band)
	for i in 4:
		var at := Vector3(x0 + (i - 1.5) * pitch, 0.0, 20.0)
		tanks.append(lab.gun(Match.Team.GREEN, "Green_A_%d" % (i + 1), at, 0.0, unit_id))
		home.append(at)
	await lab.start()
	for tank in tanks:
		var ctl := _controller_of(lab, tank)
		ctl.set_orders({"type": "face", "x": tank.global_position.x + 100.0, "z": tank.global_position.z}, {"type": "fire_at_will"})
	var ticks := int(SimClock.TICK_RATE * seconds)
	var done_s := [-1.0, -1.0, -1.0, -1.0]
	var legs := [0, 0, 0, 0]
	var gear := [0, 0, 0, 0]
	var drift := [0.0, 0.0, 0.0, 0.0]
	var creep_ticks := [0, 0, 0, 0]
	var contact_ticks := [0, 0, 0, 0]
	for tick in ticks:
		await lab.step()
		var t := (tick + 1) / float(SimClock.TICK_RATE)
		for i in 4:
			var tank := tanks[i]
			var v := tank.speed()
			if absf(v) > CUSP_SPEED:
				var g := 1 if v > 0.0 else -1
				if g != gear[i]:
					legs[i] += 1
					gear[i] = g
			var off := Vector2(tank.global_position.x - home[i].x, tank.global_position.z - home[i].z).length()
			drift[i] = maxf(drift[i], off)
			var motion: Variant = tank.get("_motion")
			if motion is Dictionary and int((motion as Dictionary).get("creep_dir", 0)) != 0:
				creep_ticks[i] += 1
			var reading := Movement.state(tank)
			if bool(reading.get("wall_contact", false)):
				contact_ticks[i] += 1
			if done_s[i] < 0.0 and absf(_err_deg(tank, 90.0)) <= ALIGNED_DEG and absf(v) < CUSP_SPEED:
				done_s[i] = t
		if (tick + 1) % SimClock.TICK_RATE == 0:
			var parts: Array = []
			for i in 4:
				var tank := tanks[i]
				var reading := Movement.state(tank)
				parts.append("%s err %.0f off %.1f v %.1f legs %d face %s/%.1f kturn %s" % [tank.name, _err_deg(tank, 90.0),
						Vector2(tank.global_position.x - home[i].x, tank.global_position.z - home[i].z).length(), tank.speed(),
						legs[i], str(Movement.of(tank)._face_legs), Movement.of(tank)._face_left_m, str(reading.get("in_kturn", "?"))])
			print("PLANNER_PROBE face t %.0f | %s" % [t, " | ".join(parts)])
	var out := {"case": "face", "unit": unit_id, "pitch_m": pitch, "limit_s": seconds, "done_s": done_s, "legs": legs,
			"drift_m": drift.map(func(d: float) -> float: return snappedf(d, 0.1)), "creep_ticks": creep_ticks,
			"contact_ticks": contact_ticks, "never": done_s.filter(func(s: float) -> bool: return s < 0.0).size(),
			"face_plans": Manoeuvre.face_plans, "face_plan_legs": Manoeuvre.face_plan_legs, "face_none": Manoeuvre.face_none,
			"face_refused": Manoeuvre.face_refused}
	print("PLANNER_PROBE_DONE %s" % JSON.stringify(out))
	lab.dispose()


func _gate_case() -> void:
	var case := TestCase.new()
	case.tree = self
	var unit_id := _flag("unit", "law_scout")
	var seconds := float(_flag("seconds", "45"))
	var lab := TacticsLab.create(case, 31)
	var x0 := TacticsScenarios.LANE_X + 40.0
	var start := Vector3(x0, 0.0, 20.0)
	var slot := Vector3(x0, 0.0, 11.0)  # 9 m north of the car
	var car := lab.gun(Match.Team.GREEN, "Green_A_1", start, 0.0, unit_id)
	await lab.start()
	var ctl := _controller_of(lab, car)
	ctl.set_orders({"type": "move_to", "x": slot.x, "z": slot.z, "facing": [0.0, 1.0]}, {"type": "fire_at_will"})
	var ticks := int(SimClock.TICK_RATE * seconds)
	var farthest := 0.0
	var farthest_at := Vector2.ZERO
	var metres := 0.0
	var last := car.global_position
	var done_s := -1.0
	var legs := 0
	var gear := 0
	var gate_to: Variant = null
	for tick in ticks:
		await lab.step()
		var t := (tick + 1) / float(SimClock.TICK_RATE)
		var here := car.global_position
		metres += Vector2(here.x - last.x, here.z - last.z).length()
		last = here
		var off := Vector2(here.x - slot.x, here.z - slot.z).length()
		if off > farthest:
			farthest = off
			farthest_at = Vector2(here.x, here.z)
		var v := car.speed()
		if absf(v) > CUSP_SPEED:
			var g := 1 if v > 0.0 else -1
			if g != gear:
				legs += 1
				gear = g
		var reading := Movement.state(car)
		if gate_to == null and reading.get("steer_to") is Vector3:
			gate_to = reading["steer_to"]
		if done_s < 0.0 and off <= ARRIVE_M and absf(_err_deg(car, 180.0)) <= ALIGNED_DEG and absf(v) < CUSP_SPEED:
			done_s = t
		if (tick + 1) % (SimClock.TICK_RATE / 2) == 0:
			print("PLANNER_PROBE gate t %.1f at (%.1f, %.1f) hdg %.0f v %.1f off_slot %.1f steer %s phase %s legs %d" % [t, here.x, here.z,
					_heading_deg(car), v, off, str(reading.get("steer_to", "?")), str(reading.get("phase", "?")), legs])
	var out := {"case": "gate", "unit": unit_id, "slot_m": 9.0, "facing": "south (180 from the approach)", "done_s": done_s,
			"farthest_from_slot_m": snappedf(farthest, 0.1), "farthest_at": [snappedf(farthest_at.x, 0.1), snappedf(farthest_at.y, 0.1)],
			"metres": snappedf(metres, 0.1), "legs": legs, "first_steer": str(gate_to), "gates": Movement.gate_report()}
	print("PLANNER_PROBE_DONE %s" % JSON.stringify(out))
	lab.dispose()
