extends TestCase
## Round 10, squad item 4: the lateral slot pitch from the TURNING ENVELOPE, measured rather than assumed. Crews stand
## abreast at a candidate pitch and are each told to hold on the spot facing a new heading, so every hull turns in place
## beside its neighbours (a formation dressing to a dragged heading). Every tick, every pair's hull boxes (Units
## hull_size on each tank's live transform) are tested with the separating-axis rule; the smallest gap is the result.
##
## The candidates (TacticsFormation.LATERAL_FLOOR): "width" (round 9, width + HULL_CLEAR_M), "one_turning"
## (half_diagonal + half_width), "both_turning" (2 × half_diagonal). The orchestrator's direction (2026-09-22): land the
## smallest that passes with zero intersections as the hulls actually turn; the conservative bound is the fallback.

const SECONDS := 8.0


## The smallest gap (metres; negative = overlapping) between any two of `tanks`' hull boxes right now.
static func smallest_gap(tanks: Array) -> float:
	var worst := INF
	for a in tanks.size():
		for b in range(a + 1, tanks.size()):
			worst = minf(worst, box_gap(tanks[a], tanks[b]))
	return worst


static func box_gap(a: Tank, b: Tank) -> float:
	var ha := _half(a)
	var hb := _half(b)
	var fa := _flat(-a.global_basis.z)
	var fb := _flat(-b.global_basis.z)
	var d := Vector3(b.global_position.x - a.global_position.x, 0.0, b.global_position.z - a.global_position.z)
	var gap := -INF
	for axis: Vector3 in [fa, Vector3(-fa.z, 0.0, fa.x), fb, Vector3(-fb.z, 0.0, fb.x)]:
		gap = maxf(gap, absf(d.dot(axis)) - _radius(ha, fa, axis) - _radius(hb, fb, axis))
	return gap


static func _half(tank: Tank) -> Vector2:
	var hull: Array = Units.stat(tank.unit_id, "hull_size", [2.4, 2.4, 8.62])
	return Vector2(minf(float(hull[0]), float(hull[2])), maxf(float(hull[0]), float(hull[2]))) * 0.5


static func _radius(half: Vector2, forward: Vector3, axis: Vector3) -> float:
	return half.x * absf(Vector3(-forward.z, 0.0, forward.x).dot(axis)) + half.y * absf(forward.dot(axis))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()


## Four `unit`s abreast at the pitch `rule` gives, all turned to hold east (or alternately east and west when
## `opposite`). Returns {"pitch", "gap"}.
func _turn_in_place(unit: String, rule: String, opposite: bool, fixed_pitch := 0.0) -> Dictionary:
	var hull: Array = Units.stat(unit, "hull_size", [])
	var extent := Vector2(minf(float(hull[0]), float(hull[2])), maxf(float(hull[0]), float(hull[2])))
	var pitch := maxf(extent.x + TacticsFormation.HULL_CLEAR_M, TacticsFormation.turning_pitch(extent, rule))
	if fixed_pitch > 0.0:
		pitch = fixed_pitch
	var scenario := AiScenario.create(self)
	var tanks: Array = []
	for i in 4:
		tanks.append(scenario.brain_tank(Match.Team.GREEN, "Green_P_%d" % (i + 1),
				Vector3(-60.0 + i * pitch, 0.0, 40.0), 0.0, {}, unit))
	var orders: Object = scenario.orders()
	await scenario.start()
	for i in tanks.size():
		var t: Tank = tanks[i]
		var east := -1.0 if opposite and i % 2 == 1 else 1.0
		orders.call("issue", {"units": [String(t.name)], "verb": "hold", "to": [t.global_position.x, t.global_position.z],
				"facing": [east, 0.0], "source": "player"})
	var worst := smallest_gap(tanks)
	for tick in int(SECONDS * SimClock.TICK_RATE):
		await scenario.step()
		worst = minf(worst, smallest_gap(tanks))
	var turned := 0
	for t: Tank in tanks:
		if absf(_flat(-t.global_basis.z).x) > 0.9:
			turned += 1
	scenario.dispose()
	return {"pitch": snappedf(pitch, 0.01), "gap": snappedf(worst, 0.01), "turned": turned}


func test_the_lateral_pitch_candidates_as_hulls_turn_in_place() -> void:
	var rows: Array = []
	var results := {}
	for unit: String in ["tank"]:
		for rule: String in ["width", "one_turning", "both_turning", "dressing"]:
			for opposite: bool in [false, true]:
				var r := await _turn_in_place(unit, rule, opposite)
				results["%s/%s/%s" % [unit, rule, "opposite" if opposite else "same"]] = r
				rows.append("%s %s %s: pitch %.2f m, smallest gap %.2f m, %d of 4 turned" % [unit, rule,
						"opposite" if opposite else "same", r["pitch"], r["gap"], r["turned"]])
	print("MEASURE pitch_turning " + " | ".join(rows))
	# The positive control (B12): at round 9's pitch, hulls turning in place must clip, or this instrument sees nothing.
	assert_true(float(results["tank/width/same"]["gap"]) < 0.0, "at the width pitch, turning hulls clip (the control)")
	# MEASURED (laptop, 2026-09-22): width 4.40 m clips -0.23 same / -0.48 opposite, and only 2 of 4 hulls got round
	# (jammed); half_diagonal + half_width 5.67 m clips -0.73 / -0.36; the sweep 6.5-8.5 m clips at every step (-0.27 at
	# 8.5); 2 x half_diagonal 8.95 m clears +0.01 / 0.00. The geometry: two parallel hulls turning TOGETHER each project
	# w|cos t| + l|sin t| on the line between them, which peaks at the full diagonal part-way round. So a formation
	# dressing the same way needs the diagonal, not the one-turning bound (which assumes the neighbour stands still).
	for side: String in ["same", "opposite"]:
		var r: Dictionary = results["tank/both_turning/%s" % side]
		assert_true(float(r["gap"]) >= -0.05, "at 2 x half_diagonal the hulls turn clear (%s: %.2f m)" % [side, r["gap"]])
		assert_eq(int(r["turned"]), 4, "and every hull got round to the new heading (%s)" % side)
		var landed: Dictionary = results["tank/dressing/%s" % side]
		assert_true(float(landed["gap"]) >= 0.0, "at the LANDED pitch (diagonal + margin) the hulls turn clear (%s: %.2f m)" \
				% [side, landed["gap"]])
	# The formations the game lays use the landed rule: a formed group's lateral floor is the diagonal + margin.
	var hull: Array = Units.stat("tank", "hull_size")
	var extent := Vector2(minf(float(hull[0]), float(hull[2])), maxf(float(hull[0]), float(hull[2])))
	assert_near(TacticsFormation.hull_floor([{"unit": "tank"}]).x, extent.length() + TacticsFormation.DRESS_MARGIN_M, 1e-4,
			"TacticsFormation lays a tank group's lateral floor at the diagonal + DRESS_MARGIN_M")


## Not run by the suite (no `test_` prefix): the sweep between the candidates, kept as the instrument that produced the
## numbers above. Rename to `test_...` and `make test FILTER=smallest_pitch` to re-measure.
func measure_the_smallest_pitch_that_turns_clear() -> void:
	var rows: Array = []
	for pitch: float in [6.5, 7.0, 7.5, 8.0, 8.5]:
		var same := await _turn_in_place("tank", "", false, pitch)
		var opposite := await _turn_in_place("tank", "", true, pitch)
		rows.append("%.1f m: same %.2f, opposite %.2f" % [pitch, same["gap"], opposite["gap"]])
	print("MEASURE pitch_sweep tank " + " | ".join(rows))
