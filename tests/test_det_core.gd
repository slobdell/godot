extends TestCase
## Netcode N2 spike: integer math (Fixed) and the deterministic simulation (DetSim).
## Cross-platform agreement (native vs WebAssembly) is `make det-spike`.


func test_cordic_trig_matches_real_trig_closely() -> void:
	for degrees in [0, 30, 45, 90, 135, 180, 225, 270, 315, 359]:
		var angle: int = degrees * Fixed.TURN / 360
		var cs := Fixed.cos_sin(angle)
		var radians := angle * TAU / Fixed.TURN
		assert_near(cs[0] / 65536.0, cos(radians), 0.0005, "cos(%d°) in fixed point" % degrees)
		assert_near(cs[1] / 65536.0, sin(radians), 0.0005, "sin(%d°) in fixed point" % degrees)


func test_atan2_inverts_cos_sin() -> void:
	for degrees in [1, 44, 89, 91, 179, 181, 269, 271, 359]:
		var angle: int = degrees * Fixed.TURN / 360
		var cs := Fixed.cos_sin(angle)
		var back := Fixed.atan2(cs[1], cs[0])
		assert_true(absi(Fixed.wrap_angle(back - angle)) <= 2,
				"atan2 recovers %d° to within 2/65536 of a turn (got %d, want %d)" % [degrees, back, angle])


func test_integer_square_root_is_exact_floor() -> void:
	for n in [0, 1, 2, 3, 4, 15, 16, 17, 65535, 65536, 1 << 40, (1 << 40) + 12345, 999999999999]:
		var r: int = Fixed.isqrt(n)
		assert_true(r * r <= n and (r + 1) * (r + 1) > n, "isqrt(%d) = %d is the floor of the root" % [n, r])


func test_fixed_point_multiply_and_divide() -> void:
	assert_eq(Fixed.mul(Fixed.from_int(3), Fixed.ONE / 2), Fixed.from_int(3) / 2, "3 × 0.5 = 1.5")
	assert_eq(Fixed.mul(-Fixed.ONE, Fixed.ONE / 2), -Fixed.ONE / 2, "negative products keep their sign")
	assert_eq(Fixed.div(Fixed.from_int(7), Fixed.from_int(2)), Fixed.from_int(7) / 2, "7 ÷ 2 = 3.5")
	assert_eq(Fixed.wrap_angle(Fixed.TURN - 1), -1, "angles wrap to the short way round")


func test_same_command_log_gives_identical_state() -> void:
	var commands := DetSim.command_log(99, 6, 600)
	var a := DetSim.new(6)
	var b := DetSim.new(6)
	a.run(commands, 600)
	b.run(commands, 600)
	assert_eq(a.state_hash(), b.state_hash(), "two runs of one log agree bit for bit")
	var other := DetSim.new(6)
	other.run(DetSim.command_log(100, 6, 600), 600)
	assert_true(other.state_hash() != a.state_hash(), "a different log gives a different state")


func test_the_spike_is_a_real_fight() -> void:
	# Guards against a "deterministic" sim that is trivially static (nothing moves, nobody shoots).
	var sim := DetSim.new(20)
	sim.run(DetSim.command_log(12345, 20, 2400), 2400)
	assert_true(sim.shots > 10, "tanks find each other and shoot (%d shots)" % sim.shots)
	assert_true(sim.hits > 0, "shells hit (%d hits)" % sim.hits)
	var moved := 0
	for i in sim.count:
		if absi(sim.pos_z[i]) < 80 * Fixed.ONE:
			moved += 1
	assert_true(moved > 0, "tanks leave their bases (%d of %d away from spawn rows)" % [moved, sim.count])


func test_state_hash_matches_the_recorded_baseline() -> void:
	# If this changes on purpose (new rules), update tests/baselines/det_spike_hash.txt.
	# If it changes on another platform, lockstep would desync there: that is the finding.
	var sim := DetSim.new(20)
	sim.run(DetSim.command_log(12345, 20, 900), 900)
	var expected := FileAccess.get_file_as_string("res://tests/baselines/det_spike_hash.txt").strip_edges()
	assert_eq(sim.state_hash(), expected, "20 tanks, seed 12345, 900 ticks")
