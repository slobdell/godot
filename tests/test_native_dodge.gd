extends TestCase
## Round 23 (native, N0b): CombatMotion.would_be_hit (the dodge loop: every incoming round, every DODGE_STEP, the
## closest approach inside each step, the hull turning then accelerating) in C++ as ONE call gives the GDScript's
## answer over seeded inputs, and the shared inner step agrees bit for bit (test_native.gd). Skipped (said) without
## the library.

const SAMPLES := 3000


func test_would_be_hit_is_the_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the would_be_hit equality is not exercised in this run")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var mismatches := 0
	var hits := 0
	var first := ""
	for i in SAMPLES:
		var here := Vector3(rng.randf_range(-100.0, 100.0), 0.0, rng.randf_range(-100.0, 100.0))
		var now2 := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(0.0, 9.0) if i % 7 != 0 else Vector2.ZERO
		var now := Vector3(now2.x, 0.0, now2.y)
		var planned := Vector3(rng.randf_range(-9.0, 9.0), 0.0, rng.randf_range(-9.0, 9.0)) if i % 5 != 0 else Vector3.ZERO
		var incoming: Array = []
		for r in (i % 4):
			# A round aimed near the hull, arriving in 3..40 ticks; some entries carry no eta (the default), some a float.
			var eta: Variant = rng.randi_range(3, 40)
			if r == 1:
				eta = float(rng.randi_range(3, 40))
			var speed := rng.randf_range(40.0, 120.0)
			var dir := Vector2.from_angle(rng.randf_range(0.0, TAU))
			var dir3 := Vector3(dir.x, 0.0, dir.y)
			var aim := here + Vector3(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-4.0, 4.0))
			var round_velocity := dir3 * speed
			var position := aim - round_velocity * (float(eta) / SimClock.TICK_RATE)
			var entry := {"position": position, "velocity": round_velocity, "shooter": "X"}
			if r != 2:
				entry["eta_ticks"] = eta
			incoming.append(entry)
		var turn_seconds: float = [0.0, 0.3, 0.9, 1.5][i % 4]
		var acceleration: float = [1000.0, 4.0, 2.5][i % 3]
		BrainSwitches.native = false
		var reference := CombatMotion.would_be_hit(here, now, planned, incoming, turn_seconds, acceleration)
		BrainSwitches.native = true
		var ours := CombatMotion.would_be_hit(here, now, planned, incoming, turn_seconds, acceleration)
		if reference:
			hits += 1
		if ours != reference:
			mismatches += 1
			if first == "":
				first = "sample %d: native %s vs gdscript %s (here %s now %s planned %s incoming %s turn %s acc %s)" % [
						i, ours, reference, here, now, planned, incoming, turn_seconds, acceleration]
	BrainSwitches.native = NativeBridge.available
	print("MEASURE native would_be_hit %d samples, %d hits, %d mismatches" % [SAMPLES, hits, mismatches])
	assert_true(hits > SAMPLES / 10 and hits < SAMPLES * 9 / 10, "the samples hit and miss both (%d of %d hit)" % [hits, SAMPLES])
	assert_eq(mismatches, 0, "every answer equal; first mismatch: %s" % first)
