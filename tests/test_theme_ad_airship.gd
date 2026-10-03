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
		var solids := AirshipFlight.solids_of(layout)
		var start := AirshipFlight.start_of(layout, solids)
		var clear := AirshipFlight.clearance(start["at"], start["heading"], solids)
		assert_true(clear > 0.0, "%s starts its whole footprint clear of every solid it would climb over (%.1f m)" % [name, clear])
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
	var blockers := [{"centre": Vector2.ZERO, "half": Vector2(20.0, 20.0), "yaw": 0.0}]
	var pushed := AirshipPilot.avoid(Vector2(0.0, 0.0), Vector2(6.0, 0.0), blockers, 8.0)
	assert_true(pushed.x > 6.0, "a goal inside a block is pushed out of it (x %.1f)" % pushed.x)
	# Off a CORNER, the push is measured from the corner -- 28 m from the centre, where the circle table was 7 m short.
	var cornered := AirshipPilot.avoid(Vector2(24.0, 24.0), Vector2(24.0, 24.0), blockers, 8.0)
	assert_true(cornered.x > 24.0 and cornered.y > 24.0, "a goal just off a corner is pushed away from it (%v)" % cornered)
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
	var blockers := AirshipFlight.solids_of(layout)
	assert_true(blockers.size() > 0, "the Terminus has tall props")
	var block: Dictionary = blockers.filter(func(s: Dictionary) -> bool: return s["type"] == "block")[0]
	var over: Vector2 = block["centre"]
	var roof: float = float(block["top"])
	var above := AirshipFlight.need_at(over, 0.0, blockers)
	var belly_above := above + SyndicateAdAirship.BELLY_FRACTION * SyndicateAdAirship.LENGTH - SyndicateAdAirship.FLOAT_RISE_TOTAL
	assert_true(belly_above >= roof,
			"over a %.0f m block its belly is at %.1f m, above the roof" % [roof, belly_above])
	# ...and far from anything it returns to the low cruise, which is where it can actually be seen.
	var open := Vector2(1000.0, 1000.0)
	assert_near(AirshipFlight.need_at(open, 0.0, blockers), SyndicateAdAirship.ALTITUDE, 0.01,
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
		var flight := AirshipFlight.new(layout)
		var pilot := flight.pilot
		var worst := 0.0
		for corner: Vector2 in [Vector2(half * 0.9, half * 0.9), Vector2(-half * 0.9, 0.0)]:
			var centre := corner
			var room := maxf(0.0, radius - AirshipPilot.ORBIT_RADIUS)
			if centre.length() > room:
				centre = centre.normalized() * room
			flight.action = centre
			for i in int(SimClock.TICK_RATE * 120.0):
				flight.step(false)
				worst = maxf(worst, pilot.position.length())
		assert_true(worst < half,
				"%s: the hull's centre stays inside the wall (furthest %.1f m of %.0f m)" % [name, worst, half])


# ---- Round 11 (airship stream): it flies THROUGH the Terminus, and nothing here used to fly ----------------------
#
# The lead: *"It also looks like the airship itself ends up intersecting with the buildings in Terminus as it flies
# around."* Every test above either looks up a height at a block's own centre or checks distance from the ORIGIN; none
# of them flies the hull past a building and asks whether it went through. These do, and the ground truth they use
# is deliberately NOT the airship's own model (`AirshipTruth`): the layout's real rotated boxes grown to the kit's own
# meshes -- because the lead sees the mast, not the collision box under it -- and the hull's own mesh, cell by cell.

## The worst intrusion of the flying hull into anything drawn, over a flight of `legs` ([action centre, seconds]):
## {depth (m of solid above the hull's underside; <= 0 is clear), where, type, tick, inside_pct}.
func _worst_intrusion(layout: Dictionary, legs: Array) -> Dictionary:
	var ship := SyndicateAdAirship.new(layout)
	add_to_tree(ship)
	var solids := AirshipTruth.drawn_solids(layout)
	var worst := {"depth": -INF, "where": Vector2.ZERO, "type": "", "tick": 0, "top": 0.0}
	var tick := 0
	var inside := 0
	var sampled := 0
	for leg: Array in legs:
		ship.fly_toward(leg[0])
		for i in int(float(leg[1]) * SimClock.TICK_RATE):
			tick += 1
			ship.advance_to(tick)
			if tick % 3 != 0:
				continue
			sampled += 1
			var hit := false
			for solid: Dictionary in solids:
				var depth := AirshipTruth.intrusion(ship.pilot.position, ship.pilot.heading, ship.hull_centre_y(), solid)
				hit = hit or depth > 0.0
				if depth > float(worst["depth"]):
					worst = {"depth": depth, "where": ship.pilot.position, "type": solid["type"], "tick": tick,
							"top": solid["top"], "solid": solid["centre"]}
			inside += int(hit)
	worst["inside_pct"] = 100.0 * inside / maxi(sampled, 1)
	return worst


func test_it_flies_the_terminus_for_four_minutes_without_entering_a_building() -> void:
	## His sentence, as a flight. Four legs of a minute each with the fight in the middle and then pushed toward each
	## side, which is what carries the orbit over the city blocks and past the (+-100, 0) pair by the wall.
	var legs := [[Vector2.ZERO, 60.0], [Vector2(36.0, 0.0), 60.0], [Vector2(-36.0, 0.0), 60.0], [Vector2(0.0, 36.0), 60.0]]
	var worst := _worst_intrusion(_layout("terminus"), legs)
	assert_true(float(worst["depth"]) <= 0.0,
			"the hull never enters anything drawn (it was inside something %.1f%% of the flight): worst was %.1f m of a %s (top %.1f m, centred %v) above the hull's underside, with the hull at %v, t=%.1f s" % [
			float(worst["inside_pct"]), float(worst["depth"]), worst["type"], float(worst["top"]), worst.get("solid", Vector2.ZERO),
			worst["where"], float(worst["tick"]) / SimClock.TICK_RATE])


func test_the_flights_hull_model_is_never_below_the_drawn_hull() -> void:
	## The flight climbs over things with a two-part hull (a keel down to the belly, wings eight metres higher). That is
	## only safe if every drawn cell of the underside is covered by a part whose underside is at or below it.
	var underside := AirshipTruth.underside()
	assert_true(underside.size() > 500, "setup: the mesh rasterised to %d cells" % underside.size())
	var worst := -INF
	var at := Vector2i.ZERO
	for key: Vector2i in underside:
		var point := Vector2(key.x + 0.5, key.y + 0.5)
		# The lowest underside among the parts covering this cell (INF: no part covers it at all).
		var covered := INF
		for part: Array in AirshipFlight.HULL_PARTS:
			var half := Vector2(float(part[1]), float(part[2])) * SyndicateAdAirship.SCALE
			if absf(point.x) <= half.x + 0.71 and absf(point.y - float(part[0]) * SyndicateAdAirship.SCALE) <= half.y + 0.71:
				covered = minf(covered, -float(part[3]) * SyndicateAdAirship.SCALE)
		var miss := covered - float(underside[key])  # > 0: the drawn hull hangs below every part over it
		if miss > worst:
			worst = miss
			at = key
	assert_true(worst <= 0.05, "no drawn cell hangs below the flight's model (worst %.2f m, cell %v)" % [worst, at])


func test_the_flights_table_of_drawn_props_covers_what_the_kit_draws() -> void:
	## The flight grows a floodlight to its mast, a sign to its board and an ad screen to its beacon (`DRAWN`). If the
	## kit art changes, this is where the table is found out.
	var layout := {"name": "t", "half_size": 60.0, "obstacles": [], "props": [
			{"type": "floodlight", "position": [0.0, 0.0]}, {"type": "sign", "position": [20.0, 0.0]},
			{"type": "ad_screen", "position": [-20.0, 0.0]}]}
	var truth := AirshipTruth.drawn_solids(layout)
	var flight := AirshipFlight.solids_of(layout)
	assert_eq(truth.size(), 3, "setup: three props drawn tall enough to matter")
	for drawn: Dictionary in truth:
		var mine: Array = flight.filter(func(s: Dictionary) -> bool: return s["type"] == drawn["type"])
		assert_eq(mine.size(), 1, "the flight knows about the %s" % drawn["type"])
		if mine.is_empty():
			continue
		assert_true(float(mine[0]["top"]) >= float(drawn["top"]) - 0.01,
				"%s: the flight's top %.2f m covers the drawn %.2f m" % [drawn["type"], float(mine[0]["top"]), float(drawn["top"])])
		assert_true((mine[0]["half"] as Vector2).x >= (drawn["half"] as Vector2).x - 0.01
				and (mine[0]["half"] as Vector2).y >= (drawn["half"] as Vector2).y - 0.01,
				"%s: the flight's footprint %v covers the drawn %v" % [drawn["type"], mine[0]["half"], drawn["half"]])


func test_by_the_wall_it_stays_inside_and_goes_over_the_outer_blocks() -> void:
	## The Terminus's (+-100, 0) blocks stand 80-120 m out, entirely inside the band where containment bites (from 72 %
	## of the play radius, 85.6 m), and containment ran last and erased the avoidance push there. The composition now:
	## CONTAINMENT WINS SIDEWAYS, HEIGHT WINS OVER BUILDINGS -- the wall has a crowd behind it and only steering can
	## keep the hull off it, while a building is a constraint height alone can satisfy. So with the fight pushed as far
	## toward each block as the orbit ever follows it, the hull must stay inside the wall AND out of both blocks.
	var layout := _layout("terminus")
	var radius := SyndicateAdAirship.play_radius(layout)
	var room := radius - AirshipPilot.ORBIT_RADIUS - AirshipPilot.TRACK_MARGIN
	var ship := SyndicateAdAirship.new(layout)
	add_to_tree(ship)
	var outer := AirshipTruth.drawn_solids(layout).filter(
			func(solid: Dictionary) -> bool: return solid["type"] == "block" and absf((solid["centre"] as Vector2).x) > 90.0)
	assert_eq(outer.size(), 2, "setup: the two outer blocks")
	var worst_depth := -INF
	var furthest := 0.0
	var near := 0
	var tick := 0
	for side: float in [1.0, -1.0]:
		ship.fly_toward(Vector2(room * side, 0.0))
		for i in int(SimClock.TICK_RATE * 120.0):
			tick += 1
			ship.advance_to(tick)
			furthest = maxf(furthest, ship.pilot.position.length())
			if tick % 3 != 0:
				continue
			for block: Dictionary in outer:
				var depth := AirshipTruth.intrusion(ship.pilot.position, ship.pilot.heading, ship.hull_centre_y(), block)
				worst_depth = maxf(worst_depth, depth)
				if depth > -12.0:
					near += 1
	assert_true(near > 0, "setup: the flight actually came near the outer blocks (%d samples within 12 m of a roof)" % near)
	assert_true(worst_depth <= 0.0, "it never enters either outer block (worst %.1f m)" % worst_depth)
	assert_true(furthest < radius, "and its centre stays inside the play radius (furthest %.1f of %.1f m)" % [furthest, radius])


func test_it_starts_down_as_soon_as_it_is_past_and_spends_the_rest_at_cruise() -> void:
	## The converse of climbing early: a hull that stays up after the roof has passed spends the match where he cannot
	## see it. One block on its orbit, nothing else: every crossing must be clear, it must start down within a second
	## and a half of its footprint leaving the roof, and most of the flight must be at the low cruise.
	var layout := {"name": "one_block", "half_size": 140.0, "obstacles": [],
			"props": [{"type": "block", "position": [AirshipPilot.ORBIT_RADIUS, 0.0]}]}
	var flight := AirshipFlight.new(layout)
	var block: Dictionary = AirshipTruth.drawn_solids(layout)[0]
	var was_over := false
	var left_at := -1
	var slow_starts: Array = []
	var crossings := 0
	var cruising := 0
	var worst := -INF
	var previous := flight.altitude
	var ticks := int(SimClock.TICK_RATE * 240.0)
	for tick in ticks:
		flight.step()
		var over := AirshipFlight.need_at(flight.pilot.position, flight.pilot.heading, flight.solids) > SyndicateAdAirship.ALTITUDE
		if was_over and not over:
			left_at = tick
			crossings += 1
		if left_at >= 0 and flight.altitude < previous - 0.001:
			if tick - left_at > int(SimClock.TICK_RATE * 1.5):
				slow_starts.append((tick - left_at) / float(SimClock.TICK_RATE))
			left_at = -1
		was_over = over
		previous = flight.altitude
		cruising += int(flight.altitude <= SyndicateAdAirship.ALTITUDE + 0.5)
		if tick % 3 == 0:
			worst = maxf(worst, AirshipTruth.intrusion(flight.pilot.position, flight.pilot.heading, flight.altitude, block))
	assert_true(crossings >= 2, "setup: it crossed the block more than once in four minutes (%d)" % crossings)
	assert_true(worst <= 0.0, "every crossing clears the roof (worst %.1f m)" % worst)
	assert_true(slow_starts.is_empty(), "it starts down within 1.5 s of leaving the roof every time (late: %s s)" % [slow_starts])
	assert_true(cruising > ticks * 0.5, "and it is at cruise most of the flight (%.0f %%)" % (100.0 * cruising / ticks))


func test_the_camera_box_reaches_the_top_of_what_is_drawn() -> void:
	## A camera parked "over the hull" by a box whose top is the deck screen sat inside the fins. The box must reach the
	## mesh's own top.
	var node := (load(SyndicateAdAirship.MESH) as PackedScene).instantiate() as Node3D
	var top := -INF
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var box := AirshipTruth.to_root(child as MeshInstance3D, node) * (child as MeshInstance3D).mesh.get_aabb()
		top = maxf(top, box.end.y)
	node.free()
	var hull := AirshipFlight.hull_box(Vector2.ZERO, 0.0, 0.0)
	assert_true(float(hull["top"]) >= top * SyndicateAdAirship.SCALE - 0.02,
			"the camera's box top (%.2f m above centre) covers the drawn top (%.2f m)" % [float(hull["top"]), top * SyndicateAdAirship.SCALE])


## --- round 14: the player's view (AirshipSight is what both the instrument and the pilot read) -----------------------

## His pose: 21 deg below the horizon, 49 m boom, FOV 35 (vertical), 16:9, looking north at the origin.
func _his_camera(focus := Vector3.ZERO, heading := 0.0) -> Transform3D:
	return RtsCamera.pose_at(focus, heading, 49.0, 21.0)


func _box_at(at: Vector2, heading := 0.0) -> Dictionary:
	return AirshipFlight.hull_box(at, heading, SyndicateAdAirship.ALTITUDE)


func test_a_hull_between_the_camera_and_the_fight_is_in_front_of_it() -> void:
	var camera := _his_camera()
	var screen := Vector2(1920, 1080)
	# The camera is 45.7 m south (+z) of the focus; half way along is in front of the fight.
	var near := AirshipSight.measure(camera, 35.0, screen, _box_at(Vector2(0.0, 22.0), PI * 0.5))
	assert_true(near["in_frame"], "a hull half way to the fight is in his frame")
	assert_true(near["between"], "and it is in FRONT of the fight: the disruptive case")
	assert_true(float(near["cover"]) > 0.3, "and it spans a big share of the screen (%.2f)" % near["cover"])
	var beyond := AirshipSight.measure(camera, 35.0, screen, _box_at(Vector2(0.0, -80.0), PI * 0.5))
	assert_true(beyond["in_frame"], "a hull 80 m beyond the fight is still seen (the venue's ship)")
	assert_true(not beyond["between"], "but it is behind the fight, not in front of it")
	var behind := AirshipSight.measure(camera, 35.0, screen, _box_at(Vector2(0.0, 120.0), PI * 0.5))
	assert_true(not behind["in_frame"], "a hull behind the camera is not in his frame")
	var aside := AirshipSight.measure(camera, 35.0, screen, _box_at(Vector2(110.0, 0.0), 0.0))
	assert_true(not aside["in_frame"], "a hull far off to the side is not in his frame")


func test_the_sight_turns_with_the_camera() -> void:
	## Every camera heading: the same hull placed half way along the boom is always `between`, and the same hull on the
	## far side of the fight never is. A convention slip (the airship once flew its whole flight backwards) fails here.
	var screen := Vector2(1920, 1080)
	for i in 8:
		var heading := TAU * i / 8.0
		var camera := _his_camera(Vector3(10.0, 0.0, -5.0), heading)
		var back := Vector2(camera.origin.x - 10.0, camera.origin.z + 5.0).normalized()
		var focus := Vector2(10.0, -5.0)
		assert_true(AirshipSight.measure(camera, 35.0, screen, _box_at(focus + back * 22.0, heading))["between"],
				"heading %d: in front of the fight" % i)
		assert_true(not AirshipSight.measure(camera, 35.0, screen, _box_at(focus - back * 90.0, heading))["between"],
				"heading %d: beyond it" % i)


## Fly the flight over `map` round a fixed fight at the origin for `seconds`, watched by his camera from `heading`, with
## the view term on or off; the share of ticks in his frame and in front of the fight.
func _watched(map: String, on: bool, seconds := 120.0, heading := 0.0, climb: Variant = null) -> Dictionary:
	var was := AirshipFlight.view_avoid
	var was_climb := AirshipFlight.view_climb
	AirshipFlight.view_avoid = on
	AirshipFlight.view_climb = on if climb == null else bool(climb)
	var flight := AirshipFlight.new(_layout(map))
	var camera := _his_camera(Vector3.ZERO, heading)
	var view := {"camera": camera, "fov": 35.0, "screen": Vector2(1920, 1080)}
	var counts := {"n": 0, "frame": 0, "between": 0}
	for i in int(seconds * SimClock.TICK_RATE):
		flight.view = view
		flight.step()
		var seen := AirshipSight.measure(camera, 35.0, view["screen"], AirshipFlight.hull_box(flight.pilot.position,
				flight.pilot.heading, flight.altitude))
		counts["n"] += 1
		counts["frame"] += int(seen["in_frame"])
		counts["between"] += int(seen["between"])
	AirshipFlight.view_avoid = was
	AirshipFlight.view_climb = was_climb
	return {"frame": 100.0 * counts["frame"] / counts["n"], "between": 100.0 * counts["between"] / counts["n"]}


func test_it_keeps_out_of_the_wedge_between_his_camera_and_the_fight() -> void:
	## The lead, round 14: *"make the aircraft choose its flight path such that it doesn't go directly into the
	## player's view"* -- and he still wants it SEEN (round 10: better than transparent, in the venue).
	for heading: float in [0.0, PI * 0.5]:
		var off := _watched("yard", false, 120.0, heading)
		var on := _watched("yard", true, 120.0, heading)
		assert_true(float(off["between"]) > 5.0, "heading %.1f: round 13's flight does cross in front of the fight (%.1f %%)" % [heading, off["between"]])
		assert_true(float(on["between"]) <= float(off["between"]) * 0.4,
				"heading %.1f: in front of the fight %.1f %% -> %.1f %% (must fall by most of itself)" % [heading, off["between"], on["between"]])
		assert_true(float(on["frame"]) >= 15.0, "heading %.1f: and it is still in his frame %.1f %% of the time" % [heading, on["frame"]])


func test_it_climbs_over_his_view_rather_than_through_it() -> void:
	## Sight lines only descend from the lens, so a belly over the camera is over every one of them: with the climb
	## alone (no steering) the hull stops hiding the fight at his pose, and rises over his camera to do it.
	for heading: float in [0.0, PI * 0.5]:
		var off := _watched("yard", false, 120.0, heading, false)
		var climb := _watched("yard", false, 120.0, heading, true)
		assert_true(float(climb["between"]) <= float(off["between"]) * 0.4,
				"heading %.1f: climbing over the view, in front of the fight %.1f %% -> %.1f %%" % [heading, off["between"], climb["between"]])
	assert_true(AirshipFlight.over_camera(SyndicateAdAirship.camera_height()) > SyndicateAdAirship.ALTITUDE,
			"over his camera is above the cruise: it has to climb to do it")


func test_with_no_camera_it_flies_round_13s_line() -> void:
	## No camera (the report, a headless run) means no view term: the switch-off arm and the no-camera arm are the
	## same flight, tick for tick.
	var a := AirshipFlight.new(_layout("terminus"))
	var was := AirshipFlight.view_avoid
	var was_climb := AirshipFlight.view_climb
	AirshipFlight.view_avoid = false
	AirshipFlight.view_climb = false
	var b := AirshipFlight.new(_layout("terminus"))
	AirshipFlight.view_avoid = was
	AirshipFlight.view_climb = was_climb
	for i in 1800:
		a.step()
		b.step()
	assert_true(a.pilot.position.is_equal_approx(b.pilot.position), "same place after a minute")


func test_the_same_camera_track_always_flies_the_same_path() -> void:
	## Determinism survives the camera: the pose is sampled at the tick, so the same ticks and the same camera track
	## fly the same line.
	var paths: Array = []
	for run in 2:
		var flight := AirshipFlight.new(_layout("yard"))
		var path: Array = []
		for i in 900:
			flight.view = {"camera": _his_camera(Vector3.ZERO, i * 0.002), "fov": 35.0, "screen": Vector2(1920, 1080)}
			flight.step()
			path.append(flight.pilot.position)
		paths.append(path)
	for i in 900:
		assert_true((paths[0][i] as Vector2).is_equal_approx(paths[1][i]), "tick %d is the same place" % i)


## --- round 15 B2: the levers that buy back the seen-share (switches, measured live by `make airship-view`) ----------

func test_climbing_only_over_the_sight_lines_still_hides_nothing() -> void:
	## `viewlow`'s height must be a real answer for the camera it was computed for: at it, the hull cuts none of the
	## fight's sight lines, at every heading and anywhere along the wedge it could hide the fight from.
	var tested := 0
	for i in 8:
		var heading := TAU * i / 8.0
		var camera := _his_camera(Vector3(10.0, 0.0, -5.0), heading)
		var back := Vector2(camera.origin.x - 10.0, camera.origin.z + 5.0).normalized()
		for along: float in [8.0, 16.0, 24.0, 32.0, 40.0]:
			for hull_heading: float in [heading, heading + PI * 0.5]:
				var at := Vector2(10.0, -5.0) + back * along
				if AirshipSight.hidden(camera, _box_at(at, hull_heading)) <= 0.0:
					continue
				tested += 1
				# What `view_need` asks for with the switch on: the lower of the two (a 57 m hull is often over the lens itself,
				# where the sight lines are at the eye and the margin would put it above the old climb).
				var low := minf(AirshipFlight.over_lines(camera, at, hull_heading), AirshipFlight.over_camera(camera.origin.y))
				var box := AirshipFlight.hull_box(at, hull_heading, low - SyndicateAdAirship.FLOAT_RISE_TOTAL)
				assert_eq(AirshipSight.hidden(camera, box), 0.0, "heading %d, %.0f m out: at the low climb it hides nothing" % [i, along])
	assert_true(tested >= 20, "and the cases were real ones: %d poses hid the fight at cruise" % tested)
	# Further from the lens it is lower: what buys back the seen-share.
	var camera := _his_camera()
	assert_true(AirshipFlight.over_lines(camera, Vector2(0.0, 10.0), PI * 0.5) < AirshipFlight.over_camera(camera.origin.y) - 3.0,
			"half way to the fight the low climb is metres under the lens climb")


func test_sinking_faster_never_makes_a_climb_late() -> void:
	## `viewsink`: 1.5x the rate down, the same rate up -- the climb into his view is not slowed, the return to cruise
	## is quicker.
	var was := AirshipFlight.view_sink
	AirshipFlight.view_sink = true
	var dt := 1.0 / SimClock.TICK_RATE
	var down := AirshipFlight.new()
	down.altitude = SyndicateAdAirship.ALTITUDE + 10.0
	var before := down.altitude
	down.step(false)
	assert_true(absf((before - down.altitude) - SyndicateAdAirship.CLIMB_MPS * AirshipFlight.SINK_FACTOR * dt) < 1e-4,
			"with the switch on it sinks %.3f m a tick" % (before - down.altitude))
	var up := AirshipFlight.new()
	up.wanted_altitude = SyndicateAdAirship.ALTITUDE + 10.0
	before = up.altitude
	up.step(false)
	assert_true(absf((up.altitude - before) - SyndicateAdAirship.CLIMB_MPS * dt) < 1e-4, "and climbs at the old rate")
	AirshipFlight.view_sink = false
	var slow := AirshipFlight.new()
	slow.altitude = SyndicateAdAirship.ALTITUDE + 10.0
	before = slow.altitude
	slow.step(false)
	assert_true(absf((before - slow.altitude) - SyndicateAdAirship.CLIMB_MPS * dt) < 1e-4, "off, it sinks at the climb rate")
	AirshipFlight.view_sink = was


## --- round 15 B1: the 39-49 s cluster was the camera's lift and the climb chasing each other (`viewrest`) -----------

func _with_rest(on: bool, body: Callable) -> void:
	var was_rest := AirshipFlight.view_rest
	var was_climb := AirshipFlight.view_climb
	AirshipFlight.view_rest = on
	AirshipFlight.view_climb = true
	body.call()
	AirshipFlight.view_rest = was_rest
	AirshipFlight.view_climb = was_climb


func test_a_hull_climbed_over_the_lens_no_longer_sets_off_the_lift() -> void:
	## Round 14's climb parked the belly 1.5 m over the lens, inside the lift's own 2 m reach under the belly
	## (`RtsCamera.SOLID_CLEAR_M`): the camera lifted over a hull that had already got out of its way. The floor of the
	## float is the worst case, so the box is drawn there.
	var camera := _his_camera()
	for on: bool in [false, true]:
		_with_rest(on, func() -> void:
			var centre := AirshipFlight.over_camera(camera.origin.y) - SyndicateAdAirship.FLOAT_RISE_TOTAL
			var box := AirshipFlight.hull_box(Vector2(camera.origin.x, camera.origin.z), 0.0, centre)
			var lifts := not RtsCamera.hull_hit(camera.origin, [box], RtsCamera.HULL_LEAD_M).is_empty()
			if on:
				assert_true(not lifts, "with viewrest the camera stays down under a hull that climbed over it")
			else:
				assert_true(lifts, "round 14's clearance is inside the lift's reach (the defect this fixes)"))


func test_a_hull_passing_beside_the_camera_climbs_before_it_sets_off_the_lift() -> void:
	## The cluster's moment: the first lap's near arc passes BESIDE the camera, hides nothing from where it rests (so
	## round 14's climb was never asked), but its footprint reaches the camera and the lift fires.
	var camera := _his_camera()
	var cam2 := Vector2(camera.origin.x, camera.origin.z)
	var found := 0
	for side: float in [-1.0, 1.0]:
		for out: float in [14.0, 16.0, 18.0]:
			# Beside and mostly behind the lens, flying north like the camera looks: the nose is level with the camera.
			var at := cam2 + Vector2(side * out, 25.0)
			var box := AirshipFlight.hull_box(at, 0.0, SyndicateAdAirship.ALTITUDE)
			if AirshipSight.hidden(camera, box) > 0.0 or not AirshipFlight.in_lift_zone(camera.origin, box):
				continue
			found += 1
			var flight := AirshipFlight.new()
			flight.view = {"camera": camera, "fov": 35.0, "screen": Vector2(1920, 1080)}
			_with_rest(false, func() -> void:
				assert_eq(flight.view_need(at, 0.0), SyndicateAdAirship.ALTITUDE, "round 14 was not asked to climb"))
			_with_rest(true, func() -> void:
				assert_eq(flight.view_need(at, 0.0), AirshipFlight.over_camera(camera.origin.y), "viewrest climbs over it"))
	assert_true(found >= 2, "the case is real: %d poses beside the lens hide nothing yet would lift the camera" % found)


func test_the_rest_pose_is_the_camera_without_the_hull_lift() -> void:
	## `RtsCamera.rest_transform` (round 15, the one accessor): with the airship sitting on the camera the live camera
	## lifts, and the rest pose stays where the camera would be without it.
	var camera := Camera3D.new()
	add_to_tree(camera)
	var rig := RtsCamera.new()
	rig.camera = camera
	rig.edge_pan = false
	add_to_tree(rig)
	rig.focus = Vector3.ZERO
	rig.yaw = 0.0
	rig.pitch = 21.0
	rig.zoom = RtsCamera.level_for(49.0)
	rig.snap()
	rig._process(0.1)
	var rest := RtsCamera.rest_transform(camera)
	assert_true(rest.origin.distance_to(camera.global_position) < 0.05, "no hull: the rest pose is the live pose")
	# The lift is round 11's arm (`AIRSHIP_ON=cameralift`); the lead's option C ships with it OFF, so the test turns it
	# on to exercise the accessor, and restores the default.
	var was := AirshipFlight.camera_lift
	AirshipFlight.camera_lift = true
	var ship := _airship()
	AirshipFlight.camera_lift = was
	ship.flight.pilot.position = Vector2(camera.global_position.x, camera.global_position.z)
	ship._place(0)
	for i in 20:
		rig._process(0.1)
	assert_true(rig.hull_lift_m > 1.0, "the hull on the camera lifts it (%.1f m)" % rig.hull_lift_m)
	assert_true(camera.global_position.y > RtsCamera.rest_transform(camera).origin.y + 1.0,
			"and the rest pose stays below the lifted camera (%.1f vs %.1f m)" % [RtsCamera.rest_transform(camera).origin.y, camera.global_position.y])
	assert_true(absf(RtsCamera.rest_transform(camera).origin.y - rest.origin.y) < 0.5, "where it was before the hull came")
	var plain := Camera3D.new()
	add_to_tree(plain)
	assert_true(RtsCamera.rest_transform(plain).is_equal_approx(plain.global_transform), "any other camera: its live transform")


class _TickSource extends Node:
	var tick := 0


func test_the_lead_view_runs_ahead_of_a_following_camera_and_ignores_a_jump() -> void:
	## `viewlead`: a camera following a squad at 5 m/s is climbed for where it will be LEAD_S on; a jump to another
	## squad is not a velocity.
	var ship := _airship()
	var source := _TickSource.new()
	add_to_tree(source)
	ship.follow_match(source)
	var pose := _his_camera()
	var lead := Transform3D()
	for i in 90:
		source.tick = i
		lead = ship._lead_view(Transform3D(pose.basis, pose.origin + Vector3(5.0 * i / SimClock.TICK_RATE, 0.0, 0.0)))
	var ahead := lead.origin.x - (pose.origin.x + 5.0 * 89 / SimClock.TICK_RATE)
	assert_true(absf(ahead - 5.0 * AirshipFlight.LEAD_S) < 3.0, "it runs %.1f m ahead (%.1f expected)" % [ahead, 5.0 * AirshipFlight.LEAD_S])
	assert_true(absf(lead.origin.y - pose.origin.y) < 0.001 and absf(lead.origin.z - pose.origin.z) < 0.5, "along the ground, the way it moves")
	source.tick = 90
	var jumped := ship._lead_view(Transform3D(pose.basis, pose.origin + Vector3(80.0, 0.0, 0.0)))
	assert_true(absf(jumped.origin.x - (pose.origin.x + 80.0)) < 0.001, "a jump resets it: no lead after a recall")


func test_the_camera_lifts_over_the_hull_only_when_the_cameralift_arm_says_so() -> void:
	## The lead's option C (2026-10-03, `game_design.md` *Round 15: the airship's "what gives way"*): by default the
	## airship is NOT in the camera's occluder group, so the camera never lifts over it and the airship does all the
	## giving way. `AIRSHIP_ON=cameralift` restores round 11's lift.
	var was := AirshipFlight.camera_lift
	assert_true(not AirshipFlight.camera_lift, "option C: the camera's lift over the hull ships OFF")
	assert_true(not _airship().is_in_group(RtsCamera.OCCLUDER_GROUP), "by default the camera does not lift over it")
	AirshipFlight.camera_lift = true
	assert_true(_airship().is_in_group(RtsCamera.OCCLUDER_GROUP), "the cameralift arm: it does")
	AirshipFlight.camera_lift = was
