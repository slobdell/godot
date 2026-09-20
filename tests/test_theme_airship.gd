extends TestCase
## Feel X7: the Syndicate airship (the lead, round 9). It is art and it must stay art -- no collision of any kind,
## no wall clock, and absent where its draws cannot be spared.


func test_the_airship_carries_no_collision_of_any_kind() -> void:
	## Visual-only should leave the simulation alone. Asserted by construction here, and pre-registered against
	## `make sim-baseline` on the branch, because arena's _build_perimeter() once moved the baseline with
	## geometrically identical walls in a different body creation order (workstreams Invariant 2).
	var airship := SyndicateAirship.new()
	add_to_tree(airship)
	for class_kind in ["CollisionObject3D", "CollisionShape3D", "StaticBody3D", "Area3D", "CharacterBody3D"]:
		assert_eq(airship.find_children("*", class_kind, true, false).size(), 0,
				"no %s anywhere under the airship" % class_kind)
	assert_true(airship.find_children("*", "MeshInstance3D", true, false).size() > 0, "but it does draw something")


func test_its_drift_comes_from_the_fixed_tick_and_is_a_closed_orbit() -> void:
	## A replay has to draw it where it was, so the pose is a pure function of the match tick. Never Time.
	var lap := int(SyndicateAirship.ORBIT_TICKS)
	var start := SyndicateAirship.pose_at(0)
	assert_true(start.origin.is_equal_approx(SyndicateAirship.pose_at(lap).origin),
			"one lap of %d ticks returns it to the same place" % lap)
	assert_true(not start.origin.is_equal_approx(SyndicateAirship.pose_at(lap / 4).origin), "and it moves in between")
	for tick in [0, 137, lap / 3, lap - 1]:
		var pose := SyndicateAirship.pose_at(tick)
		assert_near(Vector2(pose.origin.x, pose.origin.z).length(), SyndicateAirship.ORBIT_RADIUS, 0.01,
				"tick %d is on the orbit" % tick)
		assert_near(pose.origin.y, SyndicateAirship.ORBIT_ALTITUDE, 0.01, "at its altitude")
	# The nose leads the turn: forward (-Z) is tangent to the circle, so the dot with the radius is ~0.
	var quarter := SyndicateAirship.pose_at(lap / 4)
	var radial := Vector3(quarter.origin.x, 0.0, quarter.origin.z).normalized()
	var nose := -quarter.basis.z
	assert_near(Vector3(nose.x, 0.0, nose.z).normalized().dot(radial), 0.0, 0.05, "it flies along its own orbit")


func test_it_is_taller_than_the_arena_and_shorter_than_the_skyline() -> void:
	## A sanity bound on the two numbers that decide whether he ever sees it, so a later edit cannot quietly park it
	## on the floor or in orbit. What "sometimes visible" actually MEASURES is `make airship-look`, not this.
	assert_true(SyndicateAirship.ORBIT_ALTITUDE > 40.0, "well clear of the stands and towers")
	assert_true(SyndicateAirship.ORBIT_ALTITUDE < 140.0, "and not a dot")
	assert_true(SyndicateAirship.ORBIT_RADIUS > Match.ARENA_HALF_SIZE * 0.5, "orbiting outside the fighting")
	assert_true(SyndicateAirship.ORBIT_RADIUS < Match.ARENA_HALF_SIZE * 1.6, "and not over the next postcode")


func test_its_screens_join_the_existing_channel_rather_than_opening_one() -> void:
	## "Ten screens cost one layout": every screen on a channel shares one material, so the eleventh is about free.
	## A second channel would be a second 2D viewport and a second ad playing out of step with the ground screens.
	var airship := SyndicateAirship.new()
	add_to_tree(airship)
	assert_eq(airship.channel_name, "arena", "the airship rides the arena channel the ground screens use")
	var screens := airship.find_children("Screen*", "MeshInstance3D", true, false)
	assert_eq(screens.size(), 2, "a screen a side")
	var shared: Variant = null
	for screen: MeshInstance3D in screens:
		assert_true(screen.material_override != null, "%s is showing the channel" % screen.name)
		if shared == null:
			shared = screen.material_override
		assert_true(screen.material_override == shared, "and both sides share ONE material")
	assert_true(airship.broadcast == AdBroadcast.channel(airship, "arena"), "which is the channel's own")


func test_it_is_absent_on_LOW_where_its_draws_cannot_be_spared() -> void:
	var previous := FxQuality.tier()
	var dressing := ArenaDressing.new()
	add_to_tree(dressing)
	FxQuality.set_tier(FxQuality.Tier.LOW)
	dressing.call("_build_airship")
	assert_eq(dressing.airship, null, "no airship on LOW (the web build and phones)")
	FxQuality.set_tier(FxQuality.Tier.HIGH)
	dressing.call("_build_airship")
	assert_true(dressing.airship != null, "and one on HIGH")
	FxQuality.set_tier(previous)
