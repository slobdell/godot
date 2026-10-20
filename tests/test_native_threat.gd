extends TestCase
## Round 28 (native N7.2): the suppression field natively (NativeThreat -> threat_native.cpp) against the LIVE GDScript.
## (1) Two ThreatFields fed one seeded stream of stamps (points, lanes, bursts, on the grid, across its edge and off it)
## and decays, one through the GDScript and one natively: density, _active and _is_active compared bit for bit after
## every operation. (2) Match._update_suppression from one snapshot both ways over a live match's hulls (both teams,
## fields stamped round them, seeded suppression, a dead hull, sight / hull-turn changed from outside between samples):
## both fields, every hull's suppression, sight_radius, hull_turn_rate and their calm / shown values, and the stats.

const MATCH := preload("res://game/match/match.tscn")
const OPERATIONS := 4000
const SAMPLES := 200


static func _field_state(field: ThreatField) -> Array:
	return [field.density.duplicate(), field._active.duplicate(), field._is_active.duplicate()]


static func _set_field(field: ThreatField, state: Array) -> void:
	field.density = state[0].duplicate()
	field._active = state[1].duplicate()
	field._is_active = state[2].duplicate()


static func _point(rng: RandomNumberGenerator, reach: float) -> Vector3:
	return Vector3(rng.randf_range(-reach, reach), rng.randf_range(-1.0, 3.0), rng.randf_range(-reach, reach))


static func _operate(field: ThreatField, op: Array) -> void:
	match op[0]:
		"point":
			field.stamp_point(op[1], op[2])
		"segment":
			field.stamp_segment(op[1], op[2], op[3])
		"burst":
			field.stamp_burst(op[1], op[2], op[3])
		"decay":
			field.decay(op[1])


func test_field_stamps_and_decay_are_the_live_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the threat field equality is not exercised in this run")
		return
	assert_true(NativeThreat.configure(), "the native threat field takes the live constants")
	var was := BrainSwitches.native_threat
	var live := ThreatField.new(60.0)
	var native := ThreatField.new(60.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2872
	var counts := {}
	var mismatches := 0
	var first := ""
	for n in OPERATIONS:
		var roll := rng.randf()
		var op: Array
		if roll < 0.15:
			op = ["point", _point(rng, 75.0), rng.randf_range(0.0, 1.5)]
		elif roll < 0.6:
			var from := _point(rng, 80.0)
			var to := from + _point(rng, 70.0) if rng.randf() < 0.8 else from + Vector3(0.004, 0.0, -0.003)
			op = ["segment", from, to, rng.randf_range(0.05, 1.2)]
		elif roll < 0.8:
			op = ["burst", _point(rng, 75.0), rng.randf_range(0.0, 16.0), rng.randf_range(0.1, 2.0)]
		else:
			op = ["decay", rng.randi_range(-1, 9)]
		counts[op[0]] = int(counts.get(op[0], 0)) + 1
		BrainSwitches.native_threat = false
		_operate(live, op)
		BrainSwitches.native_threat = true
		_operate(native, op)
		BrainSwitches.native_threat = was
		if _field_state(live) != _field_state(native):
			mismatches += 1
			if first == "":
				first = "op %d %s" % [n, op]
	BrainSwitches.native_threat = was
	print("native threat field: %d operations %s, %d live cells at the end, %d mismatches" % [OPERATIONS, counts,
			live._active.size(), mismatches])
	assert_eq(mismatches, 0, "the native threat field is the live GDScript: %s" % first)
	assert_true(live.total() > 0.0 and int(counts.get("decay", 0)) > 400, "a real sample (%s)" % [counts])


static func _hull_state(tank: Tank) -> Array:
	return [tank.suppression, tank.sight_radius, tank.hull_turn_rate, tank._calm_sight, tank._calm_hull_turn,
			tank._shown_sight, tank._shown_hull_turn]


static func _set_hull(tank: Tank, state: Array) -> void:
	tank.suppression = state[0]
	tank.sight_radius = state[1]
	tank.hull_turn_rate = state[2]
	tank._calm_sight = state[3]
	tank._calm_hull_turn = state[4]
	tank._shown_sight = state[5]
	tank._shown_hull_turn = state[6]


static func _suppression_state(game_match: Match, hulls: Array[Tank]) -> Array:
	var state: Array = [_field_state(game_match.threat_field(0)), _field_state(game_match.threat_field(1))]
	for tank in hulls:
		state.append(_hull_state(tank))
	for key in ["suppression_samples", "suppression_total", "pinned_samples"]:
		state.append(game_match.stats[key].duplicate())
	return state


static func _set_suppression_state(game_match: Match, hulls: Array[Tank], state: Array) -> void:
	_set_field(game_match.threat_field(0), state[0])
	_set_field(game_match.threat_field(1), state[1])
	for i in hulls.size():
		_set_hull(hulls[i], state[2 + i])
	var keys := ["suppression_samples", "suppression_total", "pinned_samples"]
	for i in keys.size():
		game_match.stats[keys[i]] = state[2 + hulls.size() + i].duplicate()


func test_update_suppression_is_the_live_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the suppression update equality is not exercised in this run")
		return
	assert_true(NativeThreat.configure(), "the native threat field takes the live constants")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	await wait_physics_frames(1)
	var hulls: Array[Tank] = []
	for i in 12:
		var team := Match.Team.GREEN if i % 2 == 0 else Match.Team.RUST
		var tank := game_match.spawn_tank("Crew%02d" % i, 0, team, "tank")
		tank.place(Vector3(9.0 * (i % 4) - 14.0, 0.0, 10.0 * (i / 4) - 10.0), tank.rotation.y)
		hulls.append(tank)
	await wait_physics_frames(2)
	hulls[5].alive = false  # the dead are skipped
	var rng := RandomNumberGenerator.new()
	rng.seed = 2873
	var was := BrainSwitches.native_threat
	var mismatches := 0
	var first := ""
	var pinned_seen := 0
	for n in SAMPLES:
		BrainSwitches.native_threat = false  # stamp through the reference; the stamps' own equality is the test above
		for s in rng.randi_range(0, 4):
			var target := hulls[rng.randi_range(0, hulls.size() - 1)]
			var from := target.global_position + _point(rng, 30.0)
			game_match.threat_field(1 - target.team).stamp_segment(from, target.global_position, rng.randf_range(0.2, 1.5))
		if rng.randf() < 0.2:
			game_match.threat_field(rng.randi_range(0, 1)).stamp_burst(_point(rng, 20.0), rng.randf_range(2.0, 12.0), 1.0)
		if rng.randf() < 0.1:
			var tank := hulls[rng.randi_range(0, hulls.size() - 1)]
			tank.suppression = rng.randf_range(0.0, 1.0)
		if rng.randf() < 0.05:
			var tank := hulls[rng.randi_range(0, hulls.size() - 1)]
			tank.sight_radius = rng.randf_range(40.0, 120.0)  # changed from outside: becomes the calm value
			tank.hull_turn_rate = rng.randf_range(0.5, 2.0)
		var start := _suppression_state(game_match, hulls)
		game_match._update_suppression()
		var live := _suppression_state(game_match, hulls)
		_set_suppression_state(game_match, hulls, start)
		BrainSwitches.native_threat = true
		game_match._update_suppression()
		var native := _suppression_state(game_match, hulls)
		BrainSwitches.native_threat = was
		for tank in hulls:
			pinned_seen += 1 if tank.is_pinned() else 0
		if live != native:
			mismatches += 1
			if first == "":
				for i in live.size():
					if live[i] != native[i]:
						first = "sample %d, part %d: live %s native %s" % [n, i, live[i], native[i]]
						break
	BrainSwitches.native_threat = was
	print("native suppression update: %d samples over %d hulls, %d pinned hull-samples, stats %s, %d mismatches" % [
			SAMPLES, hulls.size(), pinned_seen, game_match.stats["suppression_total"], mismatches])
	assert_eq(mismatches, 0, "the native suppression update is the live GDScript: %s" % first)
	assert_true(pinned_seen > 20, "a real sample: crews pinned (%d)" % pinned_seen)
