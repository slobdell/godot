extends TestCase
## Round 28 (native N6.1): `TankMotion.step_in_place` natively (NativeMotion -> TankNative.motion_step,
## native/src/motion_native.cpp) against the LIVE GDScript. Seeded states of every locomotion (tracks, wheels, hover),
## with and without the optional keys (creep_dir / creep_ticks / creep_anchor, yaw_rate, hull_turn_accel_deg_s2), rolled
## 40 ticks under one command both ways from copies of one state; every key of the state compared bit for bit after every
## tick. The commands include the wheels' creep band (|throttle| under half of |turn|), exact zeros and out-of-range
## values (the clamps), so the creep's leg changes and its drift bound are reached.

const LOCOMOTIONS: Array[String] = ["tracks", "wheels", "hover"]
const ROLLS := 600
const TICKS := 40


func _state(rng: RandomNumberGenerator, locomotion: String) -> Dictionary:
	var angle := rng.randf_range(0.0, TAU)
	var forward := Vector3(cos(angle), 0.0, sin(angle))
	var speed := rng.randf_range(-6.0, 14.0) if rng.randf() < 0.8 else 0.0
	var side := Vector3(-forward.z, 0.0, forward.x) * rng.randf_range(-3.0, 3.0)
	var state := {"position": Vector3(rng.randf_range(-100.0, 100.0), 0.0, rng.randf_range(-100.0, 100.0)),
			"forward": forward, "speed": speed, "velocity": forward * speed + side, "locomotion": locomotion,
			"max_forward_speed": rng.randf_range(6.0, 22.0), "max_reverse_speed": rng.randf_range(2.0, 8.0),
			"hull_turn_rate_deg": rng.randf_range(30.0, 200.0), "acceleration_mps2": rng.randf_range(3.0, 20.0),
			"braking_mps2": rng.randf_range(4.0, 25.0), "min_turn_radius_m": rng.randf_range(0.0, 14.0),
			"lateral_grip": rng.randf_range(0.0, 1.0)}
	if rng.randf() < 0.3:
		state["yaw_rate"] = rng.randf_range(-2.0, 2.0)
	if rng.randf() < 0.3:
		state["hull_turn_accel_deg_s2"] = rng.randf_range(0.0, 400.0)
	if locomotion == "wheels" and rng.randf() < 0.4:
		state["creep_dir"] = [-1, 1][rng.randi_range(0, 1)]
		state["creep_ticks"] = rng.randi_range(0, TankMotion.CREEP_LEG_TICKS + 2)
		state["creep_anchor"] = state["position"] + Vector3(rng.randf_range(-8.0, 8.0), 0.0, rng.randf_range(-8.0, 8.0))
	return state


func _command(rng: RandomNumberGenerator) -> Vector2:
	match rng.randi_range(0, 4):
		0:
			return Vector2(0.0, [-1.0, 1.0][rng.randi_range(0, 1)] * rng.randf_range(0.3, 1.0))  # the creep band
		1:
			return Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-1.0, 1.0))
		2:
			return Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))  # the clamps
		3:
			return Vector2(0.0, 0.0)
	return Vector2(rng.randf_range(-1.0, 1.0), 0.0)


static func _diff(a: Dictionary, b: Dictionary) -> String:
	if a.size() != b.size():
		return "keys %s v %s" % [a.keys(), b.keys()]
	for key: Variant in a:
		if not b.has(key):
			return "missing %s" % key
		if typeof(a[key]) != typeof(b[key]) or a[key] != b[key]:
			return "%s: %s v %s" % [key, a[key], b[key]]
	return ""


func test_motion_step_is_the_live_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the motion equality is not exercised in this run")
		return
	assert_true(NativeMotion.configure(), "the native motion model takes the live constants")
	var was := BrainSwitches.native_motion
	var rng := RandomNumberGenerator.new()
	rng.seed = 2828
	var steps := 0
	var mismatches := 0
	var first := ""
	var by_locomotion := {}
	var creep_changes := 0
	for roll in ROLLS:
		var locomotion: String = LOCOMOTIONS[roll % LOCOMOTIONS.size()]
		var start := _state(rng, locomotion)
		var command := _command(rng)
		var delta := [TankMotion.TICK_SECONDS, 1.0 / 60.0, 2.0 * TankMotion.TICK_SECONDS][rng.randi_range(0, 2)] as float
		var live := start.duplicate(true)
		var native := start.duplicate(true)
		for tick in TICKS:
			BrainSwitches.native_motion = false
			TankMotion.step_in_place(live, command.x, command.y, delta)
			BrainSwitches.native_motion = true
			TankMotion.step_in_place(native, command.x, command.y, delta)
			steps += 1
			var differ := _diff(live, native)
			if differ != "":
				mismatches += 1
				if first == "":
					first = "roll %d (%s, command %s, delta %s) tick %d: %s" % [roll, locomotion, command, delta, tick, differ]
				break
			if live.has("creep_ticks") and int(live["creep_ticks"]) == 1 and tick > 0:
				creep_changes += 1
		by_locomotion[locomotion] = int(by_locomotion.get(locomotion, 0)) + 1
	BrainSwitches.native_motion = was
	print("native motion: %d rolls %s, %d steps, %d creep leg changes, %d mismatches" % [ROLLS, by_locomotion, steps,
			creep_changes, mismatches])
	assert_eq(mismatches, 0, "the native motion step is the live GDScript: %s" % first)
	assert_true(steps >= ROLLS * TICKS and creep_changes >= 50, "a real sample (%d steps, %d creep leg changes)" % [
			steps, creep_changes])
