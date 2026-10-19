extends TestCase
## Round 34 (manoeuvre M1, the hull-rest ruler; C34.4 (1)): the two granted, ADDITIVE fields in screen_playtest.gd.
## (2B) `--faced-shift-m=<m>` shifts the faced drag's destination by m metres in a direction the seed sets: 0 (the default)
## leaves every run unchanged; two seeds give two directions; the same seed always the same. (1B) `real_mps` rides on
## every crew row (judged by cpf_judge.py: a row that reports moving but made < 0.3 m/s is wedged, its own line).


func _flags(args: PackedStringArray) -> LaunchFlags:
	return LaunchFlags.parse(args)


func test_the_shift_is_off_by_default_and_seeded_when_asked() -> void:
	assert_eq(ScreenPlaytest.faced_shift_m(_flags(PackedStringArray([]))), 0.0, "no flag: no shift")
	assert_eq(ScreenPlaytest.faced_shift(_flags(PackedStringArray(["--seed=41"]))), Vector3.ZERO, "no flag: the destination is unchanged")
	var a := ScreenPlaytest.faced_shift(_flags(PackedStringArray(["--faced-shift-m=6", "--seed=41"])))
	var b := ScreenPlaytest.faced_shift(_flags(PackedStringArray(["--faced-shift-m=6", "--seed=42"])))
	var a2 := ScreenPlaytest.faced_shift(_flags(PackedStringArray(["--faced-shift-m=6", "--seed=41"])))
	assert_true(is_equal_approx(a.length(), 6.0), "the shift is the asked length (%.2f)" % a.length())
	assert_eq(a.y, 0.0, "flat")
	assert_true(a.distance_to(b) > 0.5, "two seeds, two directions (%s v %s)" % [a, b])
	assert_eq(a, a2, "the same seed, the same shift")
	var different := 0
	for seed_value in range(40, 52):
		var v := ScreenPlaytest.faced_shift(_flags(PackedStringArray(["--faced-shift-m=6", "--seed=%d" % seed_value])))
		if v.distance_to(a) > 0.5:
			different += 1
	assert_true(different >= 9, "12 seeds spread round the compass (%d differ from seed 41)" % different)
