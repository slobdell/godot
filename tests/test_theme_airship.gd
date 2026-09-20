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


func test_the_orbit_is_where_his_camera_can_actually_see_it() -> void:
	## The guard that `make airship-look`'s first run earned. Its 768 samples returned **0.0% visible at every
	## reachable tilt** against the original orbit, for one line of geometry: the top of the frame sits at
	## `FOV/2 - pitch` degrees above the horizon, so at the lead's 21 deg it is 3.5 deg BELOW it and nothing in the
	## sky is drawable at any altitude. This asserts the geometry that makes it visible, so a later edit cannot put
	## it back in the blind spot and leave the sweep to discover it again.
	const FOV_DEG := 35.0
	const BOOM_M := 49.0
	# Where his camera is, and how high it can see, at the LOWEST tilt he can reach (control: 8-70).
	var camera_y: float = BOOM_M * sin(deg_to_rad(8.0))
	var frame_top_deg: float = FOV_DEG / 2.0 - 8.0
	assert_true(frame_top_deg > 0.0, "at 8 deg of tilt the horizon is on screen at all (%.1f deg above it)" % frame_top_deg)
	# The airship at its FARTHEST from a camera parked over a base about 77 m out, which is the easiest case.
	var far_m: float = SyndicateAirship.ORBIT_RADIUS + 77.0
	var near_m: float = absf(SyndicateAirship.ORBIT_RADIUS - 77.0)
	var rise: float = SyndicateAirship.ORBIT_ALTITUDE - camera_y
	var nearest_elevation: float = rad_to_deg(atan(rise / near_m))
	assert_true(nearest_elevation < frame_top_deg,
			"even at its closest the airship is below the top of the frame at 8 deg (%.1f deg against %.1f)"
					% [nearest_elevation, frame_top_deg])
	# And it must NOT be visible at his own 21 deg -- not because that would be bad, but because it is impossible,
	# and a test that claimed otherwise would be lying about the camera.
	assert_true(FOV_DEG / 2.0 - 21.0 < 0.0, "at his pose the horizon is off the top of the frame, so the sky never is")
	# In front of the city backdrop and well inside what the camera draws.
	assert_true(SyndicateAirship.ORBIT_RADIUS < CitySkyline.RADIUS,
			"in front of the skyline ring (%.0f m), not behind it" % CitySkyline.RADIUS)
	assert_true(SyndicateAirship.ORBIT_RADIUS + 77.0 < 1200.0, "inside RtsCamera's far plane")
	assert_true(SyndicateAirship.ORBIT_ALTITUDE > 40.0, "clear of the arena's stands and towers")
	# Big enough to read: the hull's angular size at its farthest, over the horizontal FOV, in pixels at 1080p.
	var horizontal_fov: float = 2.0 * rad_to_deg(atan(tan(deg_to_rad(FOV_DEG / 2.0)) * 16.0 / 9.0))
	var px: float = 2.0 * rad_to_deg(atan(SyndicateAirship.ENVELOPE_LENGTH / 2.0 / far_m)) / horizontal_fov * 1920.0
	assert_true(px > 120.0, "a readable silhouette at its farthest, not a speck (%.0f px wide)" % px)


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
	# The dressing has no class_name -- it is reached through its scene -- so this instantiates the scene the game
	# instantiates. (`make lint` caught the class_name assumption; remote lint would not have, per lesson 157.)
	var previous := FxQuality.tier()
	var scene := load("res://game/theme/cyberpunk/arena_dressing.tscn") as PackedScene
	assert_true(scene != null, "the cyberpunk dressing scene loads")
	var dressing := scene.instantiate() as Node3D
	add_to_tree(dressing)
	FxQuality.set_tier(FxQuality.Tier.LOW)
	dressing.call("_build_airship")
	assert_eq(dressing.get("airship"), null, "no airship on LOW (the web build and phones)")
	FxQuality.set_tier(FxQuality.Tier.HIGH)
	dressing.call("_build_airship")
	assert_true(dressing.get("airship") != null, "and one on HIGH")
	# The player can change tier mid-match, so the airship follows rather than being decided once at build time.
	FxQuality.set_tier(FxQuality.Tier.LOW)
	dressing.call("_build_airship")
	assert_eq(dressing.get("airship"), null, "and it goes away again when the tier drops")
	FxQuality.set_tier(previous)
