extends TestCase
## Round 32 (C32.8): split from tests/test_planner_trace_manoeuvre.gd (63 s on builder0, b204a489, quick), bodies
## byte-identical: the wedged semi here, the k-turn War Rig there. The header and helpers below are that file's.
## Round 31 (planner CP-P1, the gate's two red rows on native's ON tree aa0615e4): manoeuvre's `test_kturn_three_point`
## (the War Rig nose-on to a block, 4 legs where today does 2) and nav's `test_nav_face_recovery` (the wedged semi:
## the recovery never reached) both fail with the seam taking the rig. This file TRACES each scene with the seam ON
## and OFF in the same run and prints the OUTCOME manoeuvre set: the k-turn's gear segments of the hull's ACTUAL
## motion (not the census's legs), its arrival and contacts; the wedged semi's yaw, footprint residual, path and
## whether it is reported unable (the give-up reached) or left silent, over a longer horizon than the test's 8 s. The
## scenes are the two tests' own (copied, not edited: they are manoeuvre's). Every MEASURE line is the record; the
## assertions here are the arms (the switch read, the scene built), until manoeuvre rules on the outcomes.

const MATCH := preload("res://game/match/match.tscn")
const FACE_Z := 20.0
const GOAL := Vector3(10.0, 0.0, 31.0)
const CORRIDOR_M := 4.8
const MOTION_M := 0.01   # metres a tick (0.3 m/s at 30 Hz) below which the hull is standing, not driving a leg
const KTURN_BASE_CONTACTS := 0   # the base arm's wall-contact ticks on the k-turn scene (measured, builder0 1f325b91)
const WEDGED_WINDOW_S := 8.0     # nav's test judges the wedged semi at 8 s; the trace runs on to 20 s for the record
const WEDGED_RESIDUAL_BAR_M := 1.8   # test_nav_face_recovery.RESIDUAL_BAR_M


func _with_switch(on: bool, body: Callable) -> void:
	var was_off := Movement._off.duplicate()
	var was_parsed := Movement._off_parsed
	Movement._off = PackedStringArray(["planner"]) if on != PlannerSeam.PLANNER_DEFAULT else PackedStringArray()
	Movement._off_parsed = true
	PlannerSeam.reset()
	assert_eq(PlannerSeam.on(), on, "the seam reads the asked switch state")
	await body.call()
	PlannerSeam.reset()
	Movement._off = was_off
	Movement._off_parsed = was_parsed


## Gear segments of the hull's actual motion: runs of ticks moving the same way along its own axis, standing ticks
## ignored. Each is [sign, first tick, last tick, metres].
static func _segments(motion: Array) -> Array:
	var out: Array = []
	for m: Array in motion:   # [tick, signed metres along the hull's forward axis]
		var d := float(m[1])
		if absf(d) < MOTION_M:
			continue
		var sign := 1 if d > 0.0 else -1
		if out.is_empty() or int(out[-1][0]) != sign:
			out.append([sign, int(m[0]), int(m[0]), 0.0])
		out[-1][2] = int(m[0])
		out[-1][3] = float(out[-1][3]) + absf(d)
	return out


static func _segments_text(segs: Array) -> String:
	var parts: PackedStringArray = []
	for s: Array in segs:
		parts.append("%s%.1fm@%d-%d" % ["F" if int(s[0]) > 0 else "R", float(s[3]), int(s[1]), int(s[2])])
	return " ".join(parts)


func _corridor(at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Corridor"
	for side: float in [-1.0, 1.0]:
		_slab(body, at + Vector3(side * 2.9, 2.0, 0.0), Vector3(1.0, 4.0, 30.0))
		_slab(body, at + Vector3(0.0, 2.0, side * 10.0), Vector3(6.0, 4.0, 1.0))
	return body


func _slab(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)


func _wedged(on: bool) -> void:
	Units.tuning["yaw_fit"] = 1.0
	var refusals_at := Tank.refusals_applied
	var checked_at := OrderController.face_checked
	var giveups_at := OrderController.face_giveups
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var at := Vector3(-100, 0, 40)
	add_to_tree(_corridor(at))
	var tank := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	tank.global_position = at
	tank.rotation.y = 0.0
	var ctl := OrderController.new()
	ctl.tank = tank
	ctl.tanks_root = game_match.tanks
	add_to_tree(ctl)
	assert_eq(ctl.set_orders({"type": "face", "x": at.x + 20.0, "z": at.z}, {"type": "hold_fire"}), "", "told to face across the corridor")
	var previous := tank.global_position
	var heading0 := -tank.global_basis.z
	var path := 0.0
	var first_checked := -1
	var first_giveup := -1
	var yaw_max := 0.0
	var timeline: PackedStringArray = []
	var seen := {"plans": 0, "aborted": 0, "refused": "", "live": false}
	var at_window := {}
	var horizon := int(SimClock.TICK_RATE * 20)
	for frame in horizon:
		await tree.physics_frame
		path += Vector2(tank.global_position.x - previous.x, tank.global_position.z - previous.z).length()
		previous = tank.global_position
		var forward := -tank.global_basis.z
		var yaw := rad_to_deg(absf(atan2(heading0.x * forward.z - heading0.z * forward.x, heading0.x * forward.x + heading0.z * forward.z)))
		yaw_max = maxf(yaw_max, yaw)
		if first_checked < 0 and OrderController.face_checked > checked_at:
			first_checked = frame
		if first_giveup < 0 and OrderController.face_giveups > giveups_at:
			first_giveup = frame
		var rep := PlannerSeam.report()
		var live := PlannerSeam.live("Rig")
		if int(rep["plans"]) != seen["plans"] or int(rep["aborted"]) != seen["aborted"] or JSON.stringify(rep["refused"]) != seen["refused"] or live != seen["live"]:
			timeline.append("t%d:plans%d/aborted%d/refused%s/%s" % [frame, rep["plans"], rep["aborted"], JSON.stringify(rep["refused"]), "live" if live else "released"])
			seen = {"plans": int(rep["plans"]), "aborted": int(rep["aborted"]), "refused": JSON.stringify(rep["refused"]), "live": live}
		var reading := Movement.state(tank)
		if frame % SimClock.TICK_RATE == 0:
			timeline.append("t%d:yaw%.1f/path%.2f/phase%s%s" % [frame, yaw, path, reading.get("phase", "-"), "/stalled" if bool(reading.get("face_stalled", false)) else ""])
		if frame == int(SimClock.TICK_RATE * WEDGED_WINDOW_S) - 1:
			at_window = {"yaw": yaw, "path": path, "checked": OrderController.face_checked - checked_at, "giveups": OrderController.face_giveups - giveups_at,
					"over": 14.0 * sin(deg_to_rad(yaw)) + 3.32 * cos(deg_to_rad(yaw)) - CORRIDOR_M}
	var forward := -tank.global_basis.z
	var yaw_end := rad_to_deg(absf(atan2(heading0.x * forward.z - heading0.z * forward.x, heading0.x * forward.x + heading0.z * forward.z)))
	var net := Vector2(tank.global_position.x - at.x, tank.global_position.z - at.z).length()
	var span := 14.0 * sin(deg_to_rad(yaw_end)) + 3.32 * cos(deg_to_rad(yaw_end))
	var span_max := 14.0 * sin(deg_to_rad(yaw_max)) + 3.32 * cos(deg_to_rad(yaw_max))
	Units.tuning.erase("yaw_fit")
	var rep := PlannerSeam.report()
	print("MEASURE planner_trace wedged seam %s over %d s: yaw end %.1f deg (max %.1f), footprint over the %.1f m corridor by %.2f m (max %.2f), path %.2f m, net drift %.2f m, yaw refusals applied %d, face windows checked %d (first at tick %d), giveups %d (first at tick %d), seam requests %d plans %d legs %d driven %d aborted %d abandoned %d refused %s holds %s, plans %s | timeline %s" % [
			"ON" if on else "OFF", horizon / SimClock.TICK_RATE, yaw_end, yaw_max, CORRIDOR_M, span - CORRIDOR_M, span_max - CORRIDOR_M, path, net,
			Tank.refusals_applied - refusals_at, OrderController.face_checked - checked_at, first_checked,
			OrderController.face_giveups - giveups_at, first_giveup, rep["requests"], rep["plans"], rep["plan_legs"], rep["driven"],
			rep["aborted"], rep["abandoned"], JSON.stringify(rep["refused"]), JSON.stringify(rep["holds"]), JSON.stringify(PlannerSeam.last_plans),
			" ".join(timeline)])
	print("MEASURE planner_trace wedged seam %s at %.0f s (nav's window): yaw %.1f deg, footprint over by %.2f m (bar %.1f), path %.2f m, windows checked %d, giveups %d" % [
			"ON" if on else "OFF", WEDGED_WINDOW_S, at_window["yaw"], at_window["over"], WEDGED_RESIDUAL_BAR_M, at_window["path"], at_window["checked"], at_window["giveups"]])
	assert_true(path > 0.0 or yaw_end > 0.0, "the scene ran (path %.2f m, yaw %.1f)" % [path, yaw_end])
	if on:
		# THE OUTCOME for nav's wedged row (N1's guarantee for a face, the orchestrator's ruling): within nav's window
		# the hull never yaws its footprint through the wall (the residual bar, yaw < 20) and is never silent: the
		# give-up is reached and reports it. Seam ON at 1f325b91: plan touched the slab at 1.7 s and handed back,
		# give-up at 4.6 s (base 4.5 s), at 8 s yaw 9.0 deg, 0.67 m over.
		assert_true(rep["requests"] > 0, "the seam took the rig (%d requests)" % rep["requests"])
		assert_true(float(at_window["over"]) <= WEDGED_RESIDUAL_BAR_M, "the footprint exceeds its corridor by at most %.1f m at %.0f s (%.2f m)" % [WEDGED_RESIDUAL_BAR_M, WEDGED_WINDOW_S, at_window["over"]])
		assert_true(float(at_window["yaw"]) < 20.0, "the wedged yaw stays under 20 deg at %.0f s (%.1f)" % [WEDGED_WINDOW_S, at_window["yaw"]])
		assert_true(int(at_window["checked"]) > 0 and int(at_window["giveups"]) > 0, "never silent: the give-up is reached within %.0f s (checked %d, giveups %d)" % [WEDGED_WINDOW_S, at_window["checked"], at_window["giveups"]])


func test_wedged_semi_with_the_seam_on() -> void:
	await _with_switch(true, func() -> void: await _wedged(true))


func test_wedged_semi_with_the_seam_off() -> void:
	await _with_switch(false, func() -> void: await _wedged(false))
