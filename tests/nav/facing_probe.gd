extends "res://tests/nav/order_probe.gd"
## `make nav-facing` (nav, round 7): does a unit achieve an ordered FACING, and how well? The lead: *"I couldn't tell
## what direction they were facing"*, and facing matters *"for trying to emplace units in an ambush"*. UnitCommand has
## carried `facing` since round 5 and Orders keeps it as the station's heading; this measures whether the hull ends up
## pointing that way. Every squad is sent somewhere and told to face 90 degrees off its direction of travel (the
## hardest ordinary case: arriving nose-first, then swinging), then watched for SETTLE_S seconds after its order
## completes. Prints `NAV_FACING <json>`: per unit the heading error at completion and at +2 / +5 / +10 s.
## `--verb=hold` orders a hold with facing instead of a move.

## Turned 90 degrees clockwise (seen from above) from each squad's travel direction.
const SETTLE_S := 10.0
const WITHIN_DEG := 15.0

var facing := {}         # name -> Vector2 ordered facing (x, z)
var errors := {}         # name -> {at: deg}
var verb := "move"


func _run() -> void:
	verb = _flag("verb", "move")
	await super()


## Issue each squad's order with a facing 90 degrees off its travel (replaces the parent's plain move).
func _issue_orders() -> void:
	for s in TARGETS.size():
		var names: Array = []
		var centre := Vector3.ZERO
		for tank in units:
			if String(tank.name).begins_with("Green_S%d_" % s):
				names.append(String(tank.name))
				centre += tank.global_position
		centre /= maxf(names.size(), 1)
		var to := Vector2(TARGETS[s][0], TARGETS[s][1])
		var travel := (to - Vector2(centre.x, centre.z)).normalized()
		var face := Vector2(-travel.y, travel.x)  # 90 degrees off the way it drove in
		for n: String in names:
			facing[n] = face
		var result := orders.issue(UnitCommand.make(names, verb, {"to": TARGETS[s], "facing": [face.x, face.y]}))
		if result != "":
			push_error("nav-facing: " + result)


func _sample() -> void:
	var elapsed := float(game_match.tick - issued_tick) / float(SimClock.TICK_RATE)
	for tank in units:
		var key := String(tank.name)
		if not completed_at.has(key):
			var g: Variant = orders.goal_position(key)
			if g != null:
				goal[key] = g
			var near: bool = goal.has(key) and _flat(tank.global_position, goal[key]) <= 5.0
			# A hold never completes: count it as "there" once it stands within 5 m of its spot.
			if (goal.has(key) and orders.is_idle(key)) or (verb == "hold" and near and tank.speed() < 0.3):
				completed_at[key] = elapsed
				completed_far[key] = _flat(tank.global_position, goal[key])
			continue
		var since := elapsed - float(completed_at[key])
		var forward := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
		var err := rad_to_deg(absf(forward.angle_to(facing[key])))
		var marks: Dictionary = errors.get(key, {})
		for at: float in [0.0, 2.0, 5.0, 10.0]:
			if since >= at and not marks.has(at):
				marks[at] = snappedf(err, 0.1)
		errors[key] = marks
	var settled := 0
	for key: String in errors:
		if (errors[key] as Dictionary).has(10.0):
			settled += 1
	if settled == units.size() or elapsed >= time_limit:
		_report_facing(elapsed)


func _report_facing(elapsed: float) -> void:
	physics_frame.disconnect(_sample)
	var summary := {}
	for at: float in [0.0, 2.0, 5.0, 10.0]:
		var values: Array = []
		for key: String in errors:
			if (errors[key] as Dictionary).has(at):
				values.append(float(errors[key][at]))
		values.sort()
		var within := values.filter(func(v: float) -> bool: return v <= WITHIN_DEG).size()
		summary["+%ds" % int(at)] = {"units": values.size(), "within_%d_deg" % int(WITHIN_DEG): within,
				"median_deg": values[values.size() / 2] if not values.is_empty() else -1.0,
				"worst_deg": values[-1] if not values.is_empty() else -1.0}
	var out := {"arena": String(Arena.active.get("name", "?")), "verb": verb, "units": units.size(),
			"arrived": completed_at.size(), "seconds": snappedf(elapsed, 0.1), "error_after_arrival": summary}
	print("NAV_FACING %s" % JSON.stringify(out))
	quit(0)
