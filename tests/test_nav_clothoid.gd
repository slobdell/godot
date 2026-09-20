extends TestCase
## A4's primitive, checked against values that do not come from this implementation (catalogue row A4, Fraichard &
## Scheuer 2004). A lookup table that agrees with itself proves nothing, so the Fresnel integrals are checked against
## their published values and their known limit, and the geometry against cases whose answer is obvious by hand.


func test_the_fresnel_table_matches_published_values() -> void:
	# Abramowitz & Stegun 7.3: C(0.5)=0.49234, S(0.5)=0.06473; C(1)=0.77989, S(1)=0.43826;
	# C(2)=0.48825, S(2)=0.34342. Independent of this implementation, which is the point.
	for row: Array in [[0.5, 0.49234, 0.06473], [1.0, 0.77989, 0.43826], [2.0, 0.48825, 0.34342]]:
		var got := Clothoid.fresnel(float(row[0]))
		assert_near(got.x, float(row[1]), 0.002, "C(%.1f)" % row[0])
		assert_near(got.y, float(row[2]), 0.002, "S(%.1f)" % row[0])


func test_the_integrals_are_odd_and_approach_one_half() -> void:
	var positive := Clothoid.fresnel(1.3)
	var negative := Clothoid.fresnel(-1.3)
	assert_near(negative.x, -positive.x, 0.000001, "C is odd")
	assert_near(negative.y, -positive.y, 0.000001, "S is odd")
	# C and S approach 1/2 only in the LIMIT, and they get there by spiralling: at x = 5 the ripple is still ~0.064,
	# which is 13% of the value. Asserting 1/2 +- 0.06 there was my arithmetic being optimistic, not the table being
	# wrong — the published-value test above is what proves the table. The consumer never goes near the end anyway:
	# an arrival clothoid evaluates at x = length / sqrt(pi / sharpness), which for a 20 m approach is about 1.0.
	var far := Clothoid.fresnel(Clothoid.X_MAX)
	assert_near(far.x, 0.5, 0.1, "C is near 1/2 and still rippling (%.3f)" % far.x)
	assert_near(far.y, 0.5, 0.1, "S likewise (%.3f)" % far.y)


func test_a_straight_clothoid_is_a_straight_line() -> void:
	var straight := Clothoid.offset(0.0, 12.0)
	assert_near(straight.x, 12.0, 0.0001, "it goes 12 m forward")
	assert_near(straight.y, 0.0, 0.0001, "and nowhere sideways")


## The property the arrival gate actually needs: a curved approach leaves the goal's heading AXIS, which is what lets
## it land on ground a straight run-in cannot reach. 361 of 835 off-mesh gates have no straight run-in at any length.
func test_a_curved_approach_leaves_the_heading_axis_and_more_curvature_leaves_it_further() -> void:
	var gentle := Clothoid.offset(0.004, 20.0)
	var sharp := Clothoid.offset(0.012, 20.0)
	assert_true(gentle.y > 0.2, "a gentle clothoid is already off the axis (%.2f m)" % gentle.y)
	assert_true(sharp.y > gentle.y, "a sharper one is further off it (%.2f > %.2f)" % [sharp.y, gentle.y])
	assert_true(sharp.x < gentle.x, "and does not reach as far forward (%.2f < %.2f)" % [sharp.x, gentle.x])
	assert_true(Clothoid.offset(-0.012, 20.0).y < 0.0, "negative sharpness curves the other way")


func test_sharpness_for_and_heading_change_are_inverses() -> void:
	var wanted := deg_to_rad(35.0)
	var sharpness := Clothoid.sharpness_for(wanted, 18.0)
	assert_near(Clothoid.heading_change(sharpness, 18.0), wanted, 0.000001,
			"asking for 35 degrees in 18 m gives a clothoid that turns 35 degrees")


## A hull cannot drive a curve tighter than its turning circle, so a caller has to be able to refuse one.
func test_peak_curvature_is_reported_so_a_hull_can_refuse_a_curve_it_cannot_drive() -> void:
	var sharpness := Clothoid.sharpness_for(deg_to_rad(90.0), 20.0)
	var peak := Clothoid.peak_curvature(sharpness, 20.0)
	assert_true(peak > 0.0, "a 90 degree turn has curvature (%.4f)" % peak)
	# Curvature ramps LINEARLY from 0, so the peak is twice the mean — and the peak is what a hull has to be able to
	# drive. Mean radius over a 90-degree turn in 20 m is 20 / (pi/2) = 12.7 m; the tightest radius is HALF that.
	# Asserting 12.7 against the peak was the mean-versus-peak mistake, and it is exactly the mistake that would ship
	# a curve a hull cannot take: a planner that checks the mean passes curves whose tightest point is twice as sharp.
	assert_near(1.0 / peak, 6.37, 0.2, "whose tightest radius is ~6.4 m (%.1f m)" % (1.0 / peak))
	var mean_radius := 20.0 / deg_to_rad(90.0)
	assert_near(peak, 2.0 / mean_radius, 0.001, "peak curvature is exactly twice the mean")


## Determinism: the table is built once with a fixed step count, so two calls are bit-identical and the build order
## cannot matter (a series evaluated to a tolerance would take a different number of steps on different inputs).
func test_the_table_is_fixed_and_repeatable() -> void:
	var a := Clothoid.fresnel(1.234)
	var b := Clothoid.fresnel(1.234)
	assert_eq(a, b, "the same input gives the same bits")
	assert_eq(Clothoid.SAMPLES, 513, "a fixed table size")
