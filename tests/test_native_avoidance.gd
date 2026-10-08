extends TestCase
## Round 23 (native, N1): ORCA avoidance (Avoidance.neighbours + solve + the three linear programs) in C++
## (native/src/avoidance.cpp) gives the GDScript's velocity BIT FOR BIT over seeded tables: clusters, overlaps, two
## hulls on one spot, crowds (the infeasible program), the oriented radius on and off, every row as the mover. The
## probe counters (solved, deflected, oriented_pairs) agree too. Skipped (said) without the library.

const DT := 1.0 / 30.0
const TABLES := 60
const QUERIES_PER_TABLE := 25


func _random_table(rng: RandomNumberGenerator, n: int, spread: float) -> Array:
	var rows: Array = []
	var clusters: Array[Vector2] = []
	for c in 4:
		clusters.append(Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread)))
	for i in n:
		var centre: Vector2 = clusters[i % 4]
		var pos := centre + Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0))
		match i % 11:
			3:  # right on top of another hull (the same-spot branch, decided by name)
				if i > 0:
					var other: Array = rows[i - 1]
					pos = Vector2(float(other[1]), float(other[2]))
			5:  # overlapping, not on the spot
				if i > 0:
					var other2: Array = rows[i - 1]
					pos = Vector2(float(other2[1]) + 0.3, float(other2[2]) - 0.2)
		var speed := rng.randf_range(0.0, 9.0)
		var dir := Vector2.from_angle(rng.randf_range(0.0, TAU))
		var heading := Vector2.from_angle(rng.randf_range(0.0, TAU))
		var hw := rng.randf_range(0.9, 1.7)
		var hl := rng.randf_range(1.5, 7.0)
		var radius := (hw + hl) / 2.0 + Avoidance.RADIUS_MARGIN
		var still := rng.randf() < 0.3
		rows.append(["U%02d" % i, pos.x, pos.y, dir.x * speed, dir.y * speed, radius, still, hw, hl, heading.x, heading.y])
	return rows


func test_solve_is_the_gdscript_bit_for_bit() -> void:
	if not NativeBridge.available:
		print("native: absent, the avoidance equality is not exercised in this run")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var saved_off := Movement._off
	var saved_parsed := Movement._off_parsed
	var mismatches := 0
	var first := ""
	var compared := 0
	var deflected_any := 0
	for t in TABLES:
		var n: int = [3, 8, 14, 30, 45][t % 5]
		var spread: float = [6.0, 15.0, 40.0][t % 3]
		var rows := _random_table(rng, n, spread)
		Movement._off = PackedStringArray(["oriented"]) if t % 2 == 1 else PackedStringArray()
		Movement._off_parsed = true
		Avoidance.load_rows(rows)
		for q in QUERIES_PER_TABLE:
			var row: Array = rows[q % n]
			var me: String = row[0]
			var position := Vector2(float(row[1]), float(row[2])) + (Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05)) if q % 3 == 0 else Vector2.ZERO)
			var velocity := Vector2(float(row[3]), float(row[4]))
			var preferred := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(0.0, 10.0)
			var max_speed := rng.randf_range(4.0, 9.0)
			var radius := float(row[5]) if q % 4 != 1 else rng.randf_range(1.5, 4.5)
			var cap := Avoidance.MAX_NEIGHBOURS if q % 5 != 2 else 3
			BrainSwitches.native = false
			var before := [Avoidance.solved, Avoidance.deflected, Avoidance.oriented_pairs]
			var reference := Avoidance.solve(me, position, velocity, preferred, max_speed, radius, DT, cap)
			var gd_counts := [Avoidance.solved - before[0], Avoidance.deflected - before[1], Avoidance.oriented_pairs - before[2]]
			BrainSwitches.native = true
			before = [Avoidance.solved, Avoidance.deflected, Avoidance.oriented_pairs]
			var ours := Avoidance.solve(me, position, velocity, preferred, max_speed, radius, DT, cap)
			var native_counts := [Avoidance.solved - before[0], Avoidance.deflected - before[1], Avoidance.oriented_pairs - before[2]]
			# ...and the native call itself, so a seam silently not taken cannot pass as "equal".
			var raw: Vector3 = NativeBridge.impl.avoidance_solve(me, position, velocity, preferred, max_speed, radius, DT, cap, t % 2 == 0)
			var direct := Vector2(raw.x, raw.y) if int(raw.z) != 0 else preferred
			compared += 1
			deflected_any += native_counts[1]
			if var_to_bytes(ours) != var_to_bytes(reference) or gd_counts != native_counts or var_to_bytes(direct) != var_to_bytes(reference):
				mismatches += 1
				if first == "":
					first = "table %d query %d (%s, oriented %s, cap %d): native %s (direct %s) counts %s vs gdscript %s counts %s" % [
							t, q, me, t % 2 == 0, cap, ours, direct, native_counts, reference, gd_counts]
	Movement._off = saved_off
	Movement._off_parsed = saved_parsed
	BrainSwitches.native = NativeBridge.available
	print("MEASURE native avoidance %d solves compared (%d deflected), %d mismatches" % [compared, deflected_any, mismatches])
	assert_true(deflected_any > compared / 4, "the tables are crowded enough that the solver did real work (%d of %d deflected)" % [deflected_any, compared])
	assert_eq(mismatches, 0, "every solve equal bit for bit, counters too; first mismatch: %s" % first)


func test_the_existing_avoidance_tests_run_both_ways() -> void:
	# The suite's own test_avoidance.gd runs on whichever path the switch has; this pins the two on one encounter.
	if not NativeBridge.available:
		return
	var rows := [["A", 0, 0, 0, 6, 1.8, false], ["B", 0.2, 12, 0, -6, 1.8, false]]
	Avoidance.load_rows(rows)
	BrainSwitches.native = false
	var gd := Avoidance.solve("A", Vector2.ZERO, Vector2(0, 6), Vector2(0, 6), 9.0, 1.8, DT)
	BrainSwitches.native = true
	var nat := Avoidance.solve("A", Vector2.ZERO, Vector2(0, 6), Vector2(0, 6), 9.0, 1.8, DT)
	assert_true(absf(nat.x) > 0.3, "head on, A swerves (%s)" % nat)
	assert_eq(var_to_bytes(nat), var_to_bytes(gd), "and exactly as the GDScript does (%s v %s)" % [nat, gd])
