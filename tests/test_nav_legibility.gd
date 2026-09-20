extends TestCase
## Round 9 (nav, N5 — contract S4, `_agents/legibility.md`): A6, the motion law, at LEVEL 3 of A7's table.
##
## A6-a the NOSE clause (turreted within 25 deg of the corridor tangent; hull-fixed bounded forward-oblique at 75),
## A6-b the SHOULDER clause (when both shoulders serve the band equally, take the one that advances along the
## corridor). A6-b is the clause that moves the falsifier: it is measured on VELOCITY, and a turreted hull's nose is
## already free of its gun, so a law constraining only the nose would pass its own review and leave P7 at 30-36%.
##
## OPT-IN: `--nav-off=a6` turns it ON.


static func _arm(on: bool) -> PackedStringArray:
	var was := Movement._off
	Movement._off = PackedStringArray(["a7", "a6"]) if on else PackedStringArray(["a7"])
	Movement._off_parsed = true
	CombatMotion.a6_asked = 0
	CombatMotion.a6_no_corridor = 0
	CombatMotion.a6_nose_narrowed = 0
	CombatMotion.a6_shoulder_narrowed = 0
	return was


## THE BINDING, first, because it is the claim a roster change could silently break. `legibility.md` §2: the law
## binds by `mount`, NEVER by a unit id list. `TankBrain.motion_style` derives style FROM mount, so hull-fixed is
## exactly {standoff, run}. If that stops being true, A6 starts applying a 25 deg nose bound to a hull whose gun IS
## its hull, which §4 calls an anti-goal - so it is asserted over the live roster rather than assumed.
func test_a6_binds_by_mount_and_the_style_mapping_still_carries_it() -> void:
	var fixed := 0
	var turreted := 0
	for unit_id: String in Units.PROFILES.keys():
		var mount := String((Units.profile(unit_id) as Dictionary).get("mount", "turret"))
		var style := TankBrain.motion_style(unit_id)
		if mount == "fixed":
			fixed += 1
			assert_true(style == "standoff" or style == "run",
					"%s is fixed-mount, so its style must be the hull-fixed pair (got %s)" % [unit_id, style])
		else:
			turreted += 1
			assert_true(style == "angle" or style == "strafe",
					"%s is turreted, so its style must be a turreted one (got %s)" % [unit_id, style])
	assert_true(fixed > 0 and turreted > 0,
			"POSITIVE CONTROL: the roster actually contains both mounts (%d fixed, %d turreted)" % [fixed, turreted])


## A6 IS INERT WITHOUT `request["corridor"]`, and it says so from inside the run. The field comes from
## `tank_brain.gd`, which is squad's file. Until it lands, every A6 tick is an inactive one - and an uncounted
## inactive law reads as "A6 does nothing" rather than "A6 never ran", which is this round's recurring failure
## (an unpublished `facing_arc` printing 0.0s; a denominator counting events; `--nav-off=a11` running one treatment
## in two arms). `a6_no_corridor == a6_asked` is the signal that the field has not arrived.
func test_a6_reports_when_it_had_no_corridor_rather_than_looking_inert() -> void:
	var was := _arm(true)
	var request := _request()
	request.erase("corridor")
	var result := CombatMotion.choose(request)
	Movement._off = was
	assert_true(not result.is_empty(), "the decision still returns - a missing corridor disables A6, not motion")
	assert_true(CombatMotion.a6_asked > 0, "A6 was reached (%d)" % CombatMotion.a6_asked)
	assert_eq(CombatMotion.a6_no_corridor, CombatMotion.a6_asked,
			"and every ask had no corridor, which is what `a6_no_corridor == a6_asked` is for")


## A6-a: with a corridor, a turreted hull's chosen heading sits within the nose bound of the tangent - or, when no
## candidate does, as close to it as level 3's tolerance allows. The control is the SAME request with A6 off.
##
## WHAT THIS TEST PROVES, AND WHAT IT DOES NOT. It proves the law is REACHED, has its corridor, and NARROWS the live
## set. On this synthetic request both arms then choose the same heading (0.383 either way, printed above) - level 3
## hands its null space down and levels 4 and 5 pick the same winner out of a smaller set. **So this file must not be
## read as "A6 changes behaviour".** Whether it does is the falsifier's question, on a fight, over active ticks:
## off-corridor velocity fraction 30-36% -> under 10% WITHOUT a fall in exchange ratio. That needs
## `request["corridor"]` from squad's brain, and it is the only thing that can answer it.
func test_a6a_brings_a_turreted_nose_toward_the_corridor_tangent() -> void:
	var tangent := Vector3(1, 0, 0)
	var was := _arm(false)
	var control := CombatMotion.choose(_request(tangent))
	Movement._off = was
	was = _arm(true)
	var treated := CombatMotion.choose(_request(tangent))
	var narrowed := CombatMotion.a6_nose_narrowed + CombatMotion.a6_shoulder_narrowed
	var no_corridor := CombatMotion.a6_no_corridor
	Movement._off = was
	assert_eq(no_corridor, 0, "POSITIVE CONTROL: A6 had its corridor this time (%d asks without one)" % no_corridor)
	assert_true(narrowed > 0, "and it actually narrowed the live set - an arm that changed nothing is not an arm")
	var control_dot := _heading(control).dot(tangent)
	var treated_dot := _heading(treated).dot(tangent)
	print("MEASURE a6_nose: control dot %.3f, A6 dot %.3f (bound %.0f deg)" % [
			control_dot, treated_dot, CombatMotion.A6_NOSE_DEG])
	# The guard against a vacuous pass: both arms must have produced a real heading, or the comparison below is
	# 0.000 against 0.000 and cannot fail.
	assert_true(absf(control_dot) > 0.001 or absf(treated_dot) > 0.001,
			"POSITIVE CONTROL: at least one arm produced a heading with a real projection on the tangent")
	assert_true(treated_dot >= control_dot - 0.001,
			"A6 never points the nose FURTHER from the corridor than the blend did (%.3f vs %.3f)" % [
			treated_dot, control_dot])


## A6-b, the clause that moves the falsifier: of two otherwise equal shoulders, the chosen step must not be the one
## that carries the hull back down the corridor.
func test_a6b_takes_the_shoulder_that_advances_along_the_corridor() -> void:
	var tangent := Vector3(1, 0, 0)
	var was := _arm(true)
	var result := CombatMotion.choose(_request(tangent))
	var no_corridor := CombatMotion.a6_no_corridor
	Movement._off = was
	assert_eq(no_corridor, 0, "POSITIVE CONTROL: A6 had its corridor")
	var step: Vector3 = result.get("point", Vector3.ZERO)  # the request puts the hull at the origin
	if step.length_squared() < 0.0001:
		return  # a hold does not travel, and A6-b never pushes a unit off a hold
	print("MEASURE a6_shoulder: step dot tangent %.3f" % step.normalized().dot(tangent))
	assert_true(step.normalized().dot(tangent) > -0.5,
			"the chosen shoulder is not a retreat down the corridor (dot %.3f)" % step.normalized().dot(tangent))


## The hull heading the decision implies. `choose()` answers with a `point` to steer at (NOT `to` -- nav's first cut
## of this test read a key that does not exist, so `_heading` returned its fallback in both arms and the comparison
## passed on 0.000 against 0.000: an assertion that could not fail, in the test written to catch exactly that).
## A reversing candidate drives backwards, so its hull points the other way.
static func _heading(result: Dictionary) -> Vector3:
	var point: Vector3 = result.get("point", Vector3.ZERO)
	var flat := Vector3(point.x, 0.0, point.z)
	if flat.length_squared() <= 0.0001:
		return Vector3.FORWARD
	var dir := flat.normalized()
	return -dir if bool(result.get("reverse", false)) else dir


## A turreted hull (`tank` is turret-mounted, front armour >= 6 -> `angle`) fighting a target off to one side, with
## an ordered corridor running east. Deliberately a case where the band leaves both shoulders open.
static func _request(tangent: Variant = null) -> Dictionary:
	var request := {
		"type": "tank", "position": Vector3.ZERO, "forward": Vector3.FORWARD, "velocity": Vector3.ZERO,
		"target": {"position": Vector3(0, 0, -30)}, "band": [18.0, 26.0], "style": "angle", "speed": 9.0,
		"acceleration": 6.0, "reverse_speed": 4.0, "turn_rate_deg": 80.0, "min_turn_radius": 0.0,
		"radius": 2.0, "wheels": false, "friends": [], "threats": [], "incoming": [], "center": Vector3.ZERO,
		"side": 1, "strafe": 0, "run": 0, "phase": 0, "target_busy": false, "map": null,
		"previous_index": -1, "previous_reverse": false,
	}
	if tangent != null:
		request["corridor"] = tangent
	return request
