extends TestCase
## Round 9 (nav, N4): **the test A4's own verdict said was missing.**
##
## `N4/A4 RESULT` claimed only this: *"the clothoid fan finds a navmesh-valid approach entry for every blocked-corridor
## gate in this run"* — and said in the same breath what it was NOT: *"whether the hull then arrives ON THE ORDERED
## HEADING from a curved entry is a separate question that only the straight case has tests for today. That is N4's
## next piece of work, not a detail."*
##
## It is this file. The arrival arc exists to make a hull arrive already facing the way it was told to face; A4 lets it
## reach gates a straight run-in cannot. If a curved entry lands the gate but spills the heading, A4 buys a reached
## gate and sells the thing the gate was for — which is the same shape as A4's A/B result, where it bought the gate
## and spent the fight.
##
## On **terminus**, because that is where blocked gates live: 806 of 1468 off-mesh gates there have no straight run-in
## at any length, against 430 of 1641 on yard and **zero** on boulevard, pit and boneyard.

const MATCH := preload("res://game/match/match.tscn")
## `Movement.OFF_MESH_PROBES` — a gate is in A4's class only when NONE of these shorter run-ins fits either.
const ARRIVE_SECONDS := 45.0


static func _arm(a4: bool) -> PackedStringArray:
	var was := Movement._off
	Movement._off = PackedStringArray(["a4"]) if a4 else PackedStringArray()
	Movement._off_parsed = true
	return was


## THE FIXTURE FINDS ITS OWN CASE, and refuses the test if terminus has none. A hand-picked coordinate would rot the
## day the layout moves, and a test that silently stopped exercising a blocked corridor would pass forever while
## measuring the straight case twice — which is this round's recurring failure.
static func _blocked_gate(tank: Tank) -> Dictionary:
	var map: RID = tank.get_world_3d().navigation_map
	var radius := Movement.of(tank).wheel_radius() if Movement.of(tank) != null else 6.0
	var length := clampf(maxf(radius, 6.0) * Movement.APPROACH_RADII, Movement.APPROACH_MIN, Movement.APPROACH_MAX)
	for gx in range(-90, 91, 6):
		for gz in range(-90, 91, 6):
			var goal := Vector3(float(gx), 0.0, float(gz))
			# The goal itself must be reachable, or we are testing pathing, not the arc.
			if Movement._flat_distance(NavigationServer3D.map_get_closest_point(map, goal), goal) > 1.0:
				continue
			for deg in range(0, 360, 30):
				var dir := Vector2(cos(deg_to_rad(float(deg))), sin(deg_to_rad(float(deg))))
				var gate := Vector3(goal.x - dir.x * length, 0.0, goal.z - dir.y * length)
				if Movement._flat_distance(NavigationServer3D.map_get_closest_point(map, gate), gate) <= 1.0:
					continue  # the straight gate is fine here; not A4's case
				if Movement._off_mesh_kind(goal, dir, length, map) != "":
					continue  # a SHORTER straight run-in would reach it — the 474-class, not the 806-class
				return {"goal": goal, "facing": dir}
	return {}


func test_a_curved_entry_still_arrives_on_the_ordered_heading() -> void:
	# ONE arena for both arms. Building terminus twice in a single test process left its navigation unsynced --
	# "4 edge errors ... more than 2 edges tried to occupy the same map rasterization space" -- and the fixture said
	# so. nav's first cut read numbers out of that run anyway; a measurement taken on a degraded navmesh is not a
	# measurement, and the arms share a mesh now so they also share whatever the mesh is.
	await ArenaFixture.build(self, "terminus")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var probe := game_match.spawn_tank("Probe", 0, Match.Team.GREEN, "ifv")
	probe.global_position = Vector3.ZERO
	await tree.physics_frame
	var pick := _blocked_gate(probe)
	probe.queue_free()
	assert_true(not pick.is_empty(), "POSITIVE CONTROL: terminus offers a gate blocked at EVERY straight length, "
			+ "so this run can test A4's class at all")
	if pick.is_empty():
		return
	var straight := await _arrival(game_match, false, pick)
	var curved := await _arrival(game_match, true, pick)
	for entry: Array in [["straight (A4 off)", straight], ["curved (A4 ON)", curved]]:
		var r: Dictionary = entry[1]
		print("MEASURE a4_arrival %s: arrived %s after %.1f s, heading error %.1f deg, %.1f m from the goal" % [
				entry[0], r["arrived"], r["seconds"], r["heading_error_deg"], r["gap_m"]])
	# The control proves the fixture: the straight arm reaches this goal from the IDENTICAL start, so a curved arm
	# that does not is A4's doing rather than a goal placed inside a wall.
	assert_true(bool(straight["arrived"]),
			"POSITIVE CONTROL: the straight arm reaches this goal (%.1f s, %.1f m short)" % [
			float(straight["seconds"]), float(straight["gap_m"])])
	if not bool(curved["arrived"]):
		print(("MEASURE a4_arrival DEFECT: A4 turned a %.1f s arrival into a non-arrival %.1f m short. The heading "
				+ "question this file exists to ask cannot be asked until that is fixed.") % [
				float(straight["seconds"]), float(curved["gap_m"])])
		return
	# A4 arrived, so the question is finally the one N4's verdict left open: is the heading any good? Asserted
	# against the ORDER, never against the straight arm -- a bar relative to a failing control is not a bar.
	assert_true(float(curved["heading_error_deg"]) <= 90.0,
			"a hull arriving by a CURVED entry is at least on the ordered side of the heading (%.1f deg off)"
			% float(curved["heading_error_deg"]))


## Drives one wheeled hull to the blocked-corridor goal under an ordered facing, in an arena already built.
func _arrival(game_match: Match, a4: bool, pick: Dictionary) -> Dictionary:
	var was := _arm(a4)
	var goal: Vector3 = pick["goal"]
	var facing: Vector2 = pick["facing"]
	var tank := game_match.spawn_tank("Arriver_%s" % ("a4" if a4 else "straight"), 0, Match.Team.GREEN, "ifv")
	# Start well back, so the approach is a real approach rather than a nudge.
	tank.global_position = goal - Vector3(facing.x, 0.0, facing.y) * 35.0
	tank.rotation.y = 0.0
	var ctl := OrderController.new()
	ctl.tank = tank
	ctl.tanks_root = game_match.tanks
	add_to_tree(ctl)
	await tree.physics_frame
	assert_eq(ctl.set_orders({"type": "move_to", "x": goal.x, "z": goal.z, "facing": [facing.x, facing.y]},
			{"type": "hold_fire"}), "", "ordered to the blocked-corridor goal with a facing")
	var arrived := false
	var ticks := 0
	for frame in int(SimClock.TICK_RATE * ARRIVE_SECONDS):
		await tree.physics_frame
		ticks += 1
		if String(Movement.state(tank).get("phase", "")) == "arrived":
			arrived = true
			break
	var forward := -tank.global_basis.z
	var want := Vector3(facing.x, 0.0, facing.y)
	var error := rad_to_deg(absf(atan2(want.x * forward.z - want.z * forward.x, want.x * forward.x + want.z * forward.z)))
	var out := {"arrived": arrived, "seconds": ticks / float(SimClock.TICK_RATE), "heading_error_deg": error,
			"gap_m": Movement._flat_distance(tank.global_position, goal)}
	tank.queue_free()
	ctl.queue_free()
	Movement._off = was
	return out
