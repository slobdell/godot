extends TestCase
## Round 11: the Syndicate broadcast airship. Its second pass answers *"it's just moving in straight lines … make it
## appear floating … splining or circling behavior … fly to where the action is … its own PID controller … slightly
## bad PID tunes … high rotational inertia"*, so what is held here is the FLIGHT, not a route:
## it is deterministic on the fixed tick, it circles rather than translates, it follows the fight, it overshoots the
## way a heavy hull does, and it does not fly through buildings.
##
## It is art and must stay art: no collider, and the sim baseline is pre-registered unmoved.

const SHIPPING := ["terminus", "yard", "pit", "boneyard", "boulevard", "crossing", "sumps", "maze", "barriers"]


func _layout(name := "terminus") -> Dictionary:
	return Arena.load_layout(name)["layout"]


func _airship() -> SyndicateAdAirship:
	var ship := SyndicateAdAirship.new(_layout())
	add_to_tree(ship)
	return ship


## Fly a pilot for `seconds` toward a fixed action centre, returning every position it passed through.
func _fly(centre: Vector2, seconds: float, start := Vector2(0.0, -90.0)) -> Array:
	var pilot := AirshipPilot.new()
	pilot.reset(start, 0.0)
	var dt := 1.0 / SimClock.TICK_RATE
	var path: Array = []
	for i in int(seconds * SimClock.TICK_RATE):
		pilot.step(dt, AirshipPilot.carrot(pilot.position, centre))
		path.append({"at": pilot.position, "heading": pilot.heading, "yaw": pilot.yaw_rate, "bank": pilot.bank})
	return path


func test_the_airship_carries_no_collision_of_any_kind() -> void:
	var ship := _airship()
	for class_kind in ["CollisionObject3D", "CollisionShape3D", "StaticBody3D", "Area3D", "CharacterBody3D"]:
		assert_eq(ship.find_children("*", class_kind, true, false).size(), 0, "no %s under the airship" % class_kind)
	assert_true(ship.find_children("*", "MeshInstance3D", true, false).size() > 0, "but it does draw something")


func test_every_shipping_map_gets_one_and_it_starts_clear_of_the_buildings() -> void:
	for name: String in SHIPPING:
		var layout := _layout(name)
		assert_true(SyndicateAdAirship.flies_on(layout), "%s flies an airship" % name)
		var start := SyndicateAdAirship.start_position(layout)
		assert_true(SyndicateAdAirship.clearance_at(layout, start) > 0.0,
				"%s starts it clear of every tall prop (%.1f m)" % [name, SyndicateAdAirship.clearance_at(layout, start)])
	assert_true(not SyndicateAdAirship.flies_on({}), "but no layout means no airship")


func test_the_same_ticks_always_fly_the_same_path() -> void:
	## The round-9 rule: the pose comes from the FIXED tick, so 30 fps and 144 fps look identical. A PID is an
	## integrator and cannot be a pure function of a tick, so this is the property that replaces purity -- and it is
	## the one a frame-rate-driven `_process` would silently break.
	var a := _fly(Vector2(20.0, 10.0), 40.0)
	var b := _fly(Vector2(20.0, 10.0), 40.0)
	assert_eq(a.size(), b.size(), "same number of ticks")
	for i in a.size():
		assert_true((a[i]["at"] as Vector2).is_equal_approx(b[i]["at"]), "tick %d is the same place" % i)


func test_it_circles_the_action_instead_of_flying_at_it() -> void:
	## "splining or circling behavior throughout the match". Once it has arrived, it must ORBIT: a hull that flew at
	## the centre would park on top of the fight, and its belly cannot go that low.
	var centre := Vector2(0.0, 0.0)
	var path := _fly(centre, 140.0)
	var settled: Array = path.slice(int(path.size() * 0.5))
	var near := INF
	var far := -INF
	for point: Dictionary in settled:
		var r: float = (point["at"] as Vector2).distance_to(centre)
		near = minf(near, r)
		far = maxf(far, r)
	assert_true(near > AirshipPilot.ORBIT_RADIUS * 0.45,
			"it never dives at the centre once settled (closest %.1f m of a %.0f m orbit)" % [near, AirshipPilot.ORBIT_RADIUS])
	assert_true(far < AirshipPilot.ORBIT_RADIUS * 2.0, "…and does not wander off (furthest %.1f m)" % far)
	# ...and it goes ROUND: the bearing from the centre must sweep most of a turn.
	var swept := 0.0
	for i in range(1, settled.size()):
		var before: Vector2 = (settled[i - 1]["at"] as Vector2) - centre
		var after: Vector2 = (settled[i]["at"] as Vector2) - centre
		swept += wrapf(after.angle() - before.angle(), -PI, PI)
	assert_true(absf(swept) > TAU * 0.5, "it sweeps round the action (%.2f turns in 70 s)" % (absf(swept) / TAU))


func test_it_never_flies_in_a_straight_line() -> void:
	## The lead's actual complaint. A straight run would show as a stretch of near-zero heading change; the rudder
	## should always be working, because the carrot is always off to one side.
	var path := _fly(Vector2(0.0, 0.0), 140.0)
	var settled: Array = path.slice(int(path.size() * 0.5))
	var straight := 0
	var longest := 0
	for point: Dictionary in settled:
		if absf(float(point["yaw"])) < 0.004:
			straight += 1
			longest = maxi(longest, straight)
		else:
			straight = 0
	assert_true(longest < int(SimClock.TICK_RATE * 3.0),
			"never more than 3 s of straight flight (longest %.1f s)" % (float(longest) / SimClock.TICK_RATE))


func test_the_hull_overshoots_the_way_a_heavy_one_does() -> void:
	## "slightly bad PID tunes might create a realistic effect for high rotational inertia". A critically damped
	## rudder would settle without crossing; this one must cross its target heading at least once, and must not take
	## forever about it either -- a tune that never settles is not heavy, it is broken.
	var pilot := AirshipPilot.new()
	pilot.reset(Vector2.ZERO, 0.0)
	var dt := 1.0 / SimClock.TICK_RATE
	# Dead ASTERN, in Godot's -Z-forward convention: a hull at heading 0 points toward -Z, so +Z is behind it. (This
	# line said -400 while the pilot used the opposite convention, which made the "biggest heading change there is"
	# into no turn at all -- the same convention bug that had the airship flying backwards.)
	var goal := Vector2(0.0, 400.0)
	var crossings := 0
	# Count sign changes of the LAST SIGNIFICANT error, never of the previous sample: an error sweeping through zero
	# spends several ticks inside any deadband, so comparing neighbours loses the very crossing being counted. The
	# first version of this test did exactly that and reported zero overshoot from a loop that overshoots by 12 deg.
	var last_sign := 0
	for i in int(SimClock.TICK_RATE * 90.0):
		pilot.step(dt, goal)
		var error := wrapf(AirshipPilot.heading_toward(goal - pilot.position) - pilot.heading, -PI, PI)
		if absf(error) > 0.02:
			var sign := 1 if error > 0.0 else -1
			if last_sign != 0 and sign != last_sign:
				crossings += 1
			last_sign = sign
	assert_true(crossings >= 1, "it overshoots at least once (crossings %d)" % crossings)
	assert_true(crossings < 14, "…but it does settle rather than ringing forever (crossings %d)" % crossings)


func test_it_leans_into_its_turns_and_leans_late() -> void:
	## Bank is what reads as mass. It must follow yaw rate, and it must LAG it -- a hull that snapped to its bank
	## angle would look like it was on a rail.
	var path := _fly(Vector2(0.0, 0.0), 120.0)
	var settled: Array = path.slice(int(path.size() * 0.4))
	# CORRELATION, not per-tick sign agreement. Bank is built to LAG yaw rate by ~2.2 s, so for a second or so after
	# every reversal the lean is still the old way round and disagrees -- that is the effect, not a defect, and an
	# agreement threshold just measures how much lag was dialled in. The first version of this test asserted 80 %
	# agreement and failed at exactly 80 % the moment the tune became properly under-damped.
	var correlation := 0.0
	var counted := 0
	for point: Dictionary in settled:
		if absf(float(point["yaw"])) < 0.02:
			continue
		counted += 1
		correlation += -float(point["yaw"]) * float(point["bank"])
	assert_true(counted > 100, "there are turns to measure (%d ticks)" % counted)
	assert_true(correlation / counted > 0.0, "it leans into its turns overall (correlation %.4f)" % (correlation / counted))
	# The lag: bank must trail yaw rate, so its peak comes later. Cross-correlate at zero and at a one-second shift.
	var lag := int(SimClock.TICK_RATE)
	var now := 0.0
	var later := 0.0
	for i in range(settled.size() - lag):
		now += -float(settled[i]["yaw"]) * float(settled[i]["bank"])
		later += -float(settled[i]["yaw"]) * float(settled[i + lag]["bank"])
	assert_true(later > now * 0.98, "the lean arrives after the turn, not with it")


func test_it_follows_the_action_when_the_action_moves() -> void:
	## "the airship should ideally generally fly to where the action is."
	var pilot := AirshipPilot.new()
	pilot.reset(Vector2(0.0, -90.0), 0.0)
	var dt := 1.0 / SimClock.TICK_RATE
	var centre := Vector2(0.0, 0.0)
	for i in int(SimClock.TICK_RATE * 90.0):
		pilot.step(dt, AirshipPilot.carrot(pilot.position, centre))
	var settled_near: float = pilot.position.distance_to(centre)
	# The fight moves 150 m up the map; the airship must follow it there.
	centre = Vector2(0.0, 150.0)
	for i in int(SimClock.TICK_RATE * 150.0):
		pilot.step(dt, AirshipPilot.carrot(pilot.position, centre))
	var chased: float = pilot.position.distance_to(centre)
	assert_true(settled_near < AirshipPilot.ORBIT_RADIUS * 1.5, "it settles on the first fight (%.0f m)" % settled_near)
	assert_true(chased < AirshipPilot.ORBIT_RADIUS * 1.5, "and it follows the fight when it moves (%.0f m)" % chased)


func test_it_steers_around_what_it_must_not_fly_into() -> void:
	## The airship has no collider, so nothing stops it drawing through a 24 m tower except this.
	var blockers := [{"x": 0.0, "z": 0.0, "radius": 21.0}]
	var pushed := AirshipPilot.avoid(Vector2(0.0, 0.0), Vector2(6.0, 0.0), blockers, 8.0)
	assert_true(pushed.x > 6.0, "a goal inside a block is pushed out of it (x %.1f)" % pushed.x)
	var clear := AirshipPilot.avoid(Vector2(200.0, 0.0), Vector2(200.0, 0.0), blockers, 8.0)
	assert_true(clear.is_equal_approx(Vector2(200.0, 0.0)), "and a goal far away is left alone")


func test_it_floats_rather_than_translating() -> void:
	## Three rises with no common multiple, so the wander never repeats on a beat the eye can catch, plus attitude
	## that follows the vertical motion (buoyancy, not levitation).
	var rises: Array[float] = []
	for tick in range(0, int(SimClock.TICK_RATE * 120.0), 5):
		rises.append(float(SyndicateAdAirship.float_offsets(float(tick) / SimClock.TICK_RATE)["rise"]))
	var lo := rises.min() as float
	var hi := rises.max() as float
	assert_true(hi - lo > 0.9, "it rises and falls over a metre (%.2f m)" % (hi - lo))
	assert_true(hi <= SyndicateAdAirship.FLOAT_RISE_TOTAL + 0.001, "…within the altitude budget the belly reserves")
	# Not a single sine: the longest period is 23.1 s, so a pure sine would return to its start after exactly that.
	var one := float(SyndicateAdAirship.float_offsets(0.0)["rise"])
	var later := float(SyndicateAdAirship.float_offsets(23.1)["rise"])
	assert_true(absf(one - later) > 0.05, "the wander does not repeat on its longest period")
	# Nose up when rising.
	var climbing := SyndicateAdAirship.float_offsets(3.2)
	assert_true(signf(float(climbing["pitch"])) != 0.0, "attitude moves with the float")


func test_it_stays_in_his_frame_and_clears_what_drives_under_it() -> void:
	## Two walls: the belly over the tallest hull (6.18 m) or it drives through a tank, and the flank screens under
	## the frame's top edge or he cannot read them. The second wall is what makes bigger expensive.
	assert_true(SyndicateAdAirship.belly_y() > SyndicateAdAirship.HULL_CLEARANCE - 0.01,
			"its belly (%.2f m) clears the tallest hull even at the bottom of its float" % SyndicateAdAirship.belly_y())
	# GROUND distance, not boom length: the frame's top edge drops 0.061 m per metre of horizontal run, and his boom
	# is 49 m along the slope but 45.75 m across the ground.
	var ceiling := SyndicateAdAirship.visible_ceiling_at(SyndicateAdAirship.camera_run())
	assert_near(ceiling, 14.8, 0.2, "the top of his frame over his own focus is ~14.8 m up")
	var flank_y := SyndicateAdAirship.ALTITUDE + SyndicateAdAirship.FLANK_CENTRE.y * SyndicateAdAirship.LENGTH
	var half := SyndicateAdAirship.FLANK_SIZE.y * SyndicateAdAirship.LENGTH * 0.5 * cos(deg_to_rad(32.0))
	assert_true(flank_y - half < ceiling,
			"some of the flank screen (%.1f..%.1f m) is under his frame's ceiling (%.1f m)" % [flank_y - half, flank_y + half, ceiling])


func test_it_is_larger_than_it_was_and_says_what_that_cost() -> void:
	## "it should be at least 1.5x to 2x its current size." 1.5x ships; 2x is a TUNE, because every metre pushes the
	## flank screens further through the frame's ceiling.
	assert_true(SyndicateAdAirship.SCALE >= 1.5, "at least 1.5x the first pass (%.2fx)" % SyndicateAdAirship.SCALE)
	assert_near(SyndicateAdAirship.LENGTH, SyndicateAdAirship.BASE_LENGTH * SyndicateAdAirship.SCALE, 0.01,
			"the length is the asset times the scale")
	assert_true(SyndicateAdAirship.LENGTH > 55.0, "which is a large airship (%.1f m)" % SyndicateAdAirship.LENGTH)


func test_its_screens_join_the_arena_channel_and_sit_on_the_hull() -> void:
	var ship := _airship()
	var screens := ship.find_children("Screen*", "MeshInstance3D", true, false)
	assert_eq(screens.size(), 3, "two flanks and the deck")
	var hull := ship.find_child("Hull", true, false) as Node3D
	assert_true(hull != null, "the generated hull is in the scene")
	var bounds := _bounds(hull, ship.global_transform.affine_inverse())
	# Each panel joins the cut of the channel matching its own shape: the wide flanks take the landscape layout, the
	# tall deck panel takes the portrait one the ground screens share. Showing a 1.9:1 panel the portrait feed is
	# what the lead saw as "portrait video data … doesn't actually fill the screen".
	var tall := AdBroadcast.channel(ship, "arena").screen_material
	var landscape := AdBroadcast.channel(ship, "arena", true).screen_material
	assert_true(tall != landscape, "the two cuts are different materials")
	for screen: MeshInstance3D in screens:
		var quad_mesh := screen.mesh as QuadMesh
		var wanted: Material = landscape if quad_mesh.size.x >= quad_mesh.size.y else tall
		assert_true(screen.material_override == wanted,
				"%s (%.1f x %.1f) joins the cut that matches its shape" % [screen.name, quad_mesh.size.x, quad_mesh.size.y])
		var quad := screen.mesh as QuadMesh
		var grown := bounds.grow(SyndicateAdAirship.SCREEN_PROUD * SyndicateAdAirship.BASE_LENGTH + 0.5)
		for sx: float in [-0.5, 0.5]:
			for sy: float in [-0.5, 0.5]:
				var corner: Vector3 = screen.transform * Vector3(quad.size.x * sx, quad.size.y * sy, 0.0)
				assert_true(grown.has_point(corner), "%s's corner %v is on the hull" % [screen.name, corner])


func test_the_landscape_cut_actually_fills_the_wide_panels() -> void:
	## The lead: *"the actual video display on the airship is just portrait video data instead of landscape video so
	## it doesn't actually fill the screen."* With the portrait feed a 1.9:1 flank panel showed the ad as a narrow
	## strip with most of the panel dark; against the LANDSCAPE cut the same panel is nearly filled.
	var flank := SyndicateAdAirship.FLANK_SIZE * SyndicateAdAirship.BASE_LENGTH
	var on_portrait := SyndicateAdAirship.feed_rect_for(flank, AdBroadcast.LAYOUT)
	var on_landscape := SyndicateAdAirship.feed_rect_for(flank, AdBroadcast.WIDE_LAYOUT)
	# How much of the panel the picture covers: 1.0 fills it, 0.26 is the strip the lead saw.
	var portrait_fill := 1.0 / (on_portrait.z * on_portrait.w)
	var landscape_fill := 1.0 / (on_landscape.z * on_landscape.w)
	assert_true(portrait_fill < 0.35, "the portrait feed only covered %.0f%% of a flank panel" % (portrait_fill * 100.0))
	assert_true(landscape_fill > 0.9, "the landscape cut fills %.0f%% of it" % (landscape_fill * 100.0))
	# A panel already at the feed's aspect still shows all of it, whichever cut it joins.
	assert_near(SyndicateAdAirship.feed_rect_for(Vector2(4.0, 8.0), AdBroadcast.LAYOUT).z, 1.0, 0.001,
			"a portrait panel on the portrait cut shows the whole ad")


func test_the_deck_panel_is_honest_about_being_edge_on() -> void:
	assert_true(SyndicateAdAirship.deck_grazing_deg() > 80.0,
			"the deck panel is near edge-on at his pose (%.1f deg)" % SyndicateAdAirship.deck_grazing_deg())


func test_only_the_flanks_can_ever_be_seen_and_the_size_is_capped_by_that() -> void:
	## His camera (17.56 m) sits INSIDE this hull's height range (belly 6.2 m, deck 22.8 m), so it sees the hull
	## edge-on: a panel facing up and a panel facing down both face away from him. Only the flanks work -- and every
	## metre of extra length lifts them further through the top of his frame, which is what caps the size. This test
	## exists because a belly screen was built on the opposite assumption and could not be seen from anywhere.
	assert_true(SyndicateAdAirship.camera_height() > SyndicateAdAirship.belly_y(), "the camera is above the belly")
	assert_true(SyndicateAdAirship.camera_height() < SyndicateAdAirship.deck_y(), "…and below the deck")
	var ceiling := SyndicateAdAirship.visible_ceiling_at(SyndicateAdAirship.camera_run())
	var flank := SyndicateAdAirship.ALTITUDE + SyndicateAdAirship.FLANK_CENTRE.y * SyndicateAdAirship.LENGTH
	var half := SyndicateAdAirship.FLANK_SIZE.y * SyndicateAdAirship.LENGTH * 0.5 * cos(deg_to_rad(32.0))
	assert_true(flank - half < ceiling,
			"some flank screen (%.1f..%.1f m) is under his ceiling (%.1f m) -- a bigger SCALE ends this" % [
			flank - half, flank + half, ceiling])


func _bounds(node: Node3D, into: Transform3D) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null:
			continue
		var box := (into * instance.global_transform) * instance.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func test_it_climbs_over_what_it_cannot_fly_around() -> void:
	## At 1.5x the beam is 22.2 m and the Terminus streets are 18 m, so the hull no longer fits between the city
	## blocks -- and steering alone did not save it: the goal was bent away from the block and the deliberately heavy
	## rudder flew the hull straight through anyway. So it climbs. Over open ground it comes back down, which is the
	## most airship-like motion it makes and the reason this is a behaviour rather than a fixed cruise height.
	var layout := _layout()
	var blockers := SyndicateAdAirship.blockers(layout)
	assert_true(blockers.size() > 0, "the Terminus has tall props")
	var block: Dictionary = blockers[0]
	var over := Vector2(float(block["x"]), float(block["z"]))
	var roof: float = float(block["height"])
	var above := SyndicateAdAirship.required_altitude(over, blockers)
	var belly_above := above + SyndicateAdAirship.BELLY_FRACTION * SyndicateAdAirship.LENGTH - SyndicateAdAirship.FLOAT_RISE_TOTAL
	assert_true(belly_above >= roof,
			"over a %.0f m block its belly is at %.1f m, above the roof" % [roof, belly_above])
	# ...and far from anything it returns to the low cruise, which is where it can actually be seen.
	var open := Vector2(1000.0, 1000.0)
	assert_near(SyndicateAdAirship.required_altitude(open, blockers), SyndicateAdAirship.ALTITUDE, 0.01,
			"over open ground it settles back to its cruise height")


func test_it_never_leaves_the_arena() -> void:
	## The lead, watching it: *"the airship flew into the crowd and disappeared."* The venue's grandstands stand just
	## outside `half_size`, and nothing used to pull the hull back -- the orbit carries it outward and `avoid` pushes
	## it further out every time it passes a perimeter floodlight. Flown here for four minutes on every shipping map,
	## including with the fight itself sitting in a corner, which is the case that used to throw it over the wall.
	for name: String in SHIPPING:
		var layout := _layout(name)
		var half := float(layout.get("half_size", 120.0))
		var radius := SyndicateAdAirship.play_radius(layout)
		var blockers := SyndicateAdAirship.blockers(layout)
		var pilot := AirshipPilot.new()
		pilot.reset(SyndicateAdAirship.start_position(layout), 0.0)
		var dt := 1.0 / SimClock.TICK_RATE
		var worst := 0.0
		for corner: Vector2 in [Vector2(half * 0.9, half * 0.9), Vector2(-half * 0.9, 0.0)]:
			var centre := corner
			var room := maxf(0.0, radius - AirshipPilot.ORBIT_RADIUS)
			if centre.length() > room:
				centre = centre.normalized() * room
			for i in int(SimClock.TICK_RATE * 120.0):
				var goal := AirshipPilot.carrot(pilot.position, centre)
				goal = AirshipPilot.avoid(goal, pilot.position, blockers,
						SyndicateAdAirship.BEAM * 0.5 + SyndicateAdAirship.AVOID_CLEARANCE)
				goal = AirshipPilot.contain(goal, pilot.position, radius)
				pilot.step(dt, goal)
				worst = maxf(worst, pilot.position.length())
		assert_true(worst < half,
				"%s: the hull's centre stays inside the wall (furthest %.1f m of %.0f m)" % [name, worst, half])
