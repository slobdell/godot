extends TestCase
## R4 (round 10, CP2): streets are lanes. Every declared lane keeps a continuous drivable width of at least twice the
## roster's widest hull after the bake radius, and every turn it asks for clears the design vehicle's corner cut (C5).
## The measurement is `ArenaLanes`; this file is the assertion.
##
## The lead (2026-09-20): "there streets are blocked with these shipping containers so there's almost no passageway."

func _asserted(layout_name: String, data: Dictionary) -> bool:
	return not ArenaLanes.REPORT_ONLY.has(layout_name) and not Arena.is_fixture(data)


func test_the_bar_is_read_from_the_roster_and_the_bake() -> void:
	var the_bar := ArenaLanes.bar()
	var widest := 0.0
	for unit_id: String in Units.ids():
		widest = maxf(widest, float(Units.profile(unit_id)["hull_size"][0]))
	assert_near(the_bar["widest_hull_m"], widest, 0.001, "the widest hull comes from Units (%s)" % the_bar["widest_hull"])
	assert_near(the_bar["drivable_bar_m"], 2.0 * widest, 0.001, "the drivable bar is two of them abreast")
	assert_near(the_bar["bake_radius_m"], Movement.NAV_AGENT_RADIUS, 0.001, "the bake radius is arena.tscn's, which nav cross-checks")
	assert_near(the_bar["physical_bar_m"], 2.0 * widest + 2.0 * Movement.NAV_AGENT_RADIUS, 0.001, "physical = drivable + both kerbs")
	assert_eq(the_bar["rig"], Units.RIG_UNIT, "the corner design vehicle is the rig (the largest turning radius)")


## Positive control (B12): the instrument must SEE a container across a street before its silence means anything.
func test_a_container_across_a_lane_fails_and_one_at_the_kerb_passes() -> void:
	var data := {"name": "probe", "half_size": 120.0, "obstacles": [],
			"lanes": [{"name": "street", "points": [[0.0, 60.0], [0.0, -60.0]], "width": 18.0}]}
	# A 20 m street: blocks either side, x in -10..10 open.
	for x: float in [-30.0, 30.0]:
		data["obstacles"].append({"type": "wall", "position": [x, 0.0], "size": [40.0, 10.0, 200.0], "rotation_deg": 0.0})
	var open: Dictionary = ArenaLanes.measure(data)[0]
	assert_near(open["narrowest_physical_m"], 20.0, 0.01, "an empty 20 m street measures 20 m")
	assert_true(open["pass"], "and passes")
	var kerb := data.duplicate(true)
	kerb["obstacles"].append({"type": "container_40", "position": [-8.78, 5.0], "size": [12.19, 2.59, 2.44], "rotation_deg": 90.0})
	var at_kerb: Dictionary = ArenaLanes.measure(kerb)[0]
	assert_near(at_kerb["narrowest_physical_m"], 20.0 - 2.44, 0.01, "a 40 ft container parallel at the kerb leaves 17.56 m")
	assert_true(at_kerb["pass"], "and still passes")
	var across := data.duplicate(true)
	across["obstacles"].append({"type": "container_40", "position": [0.0, 5.0], "size": [12.19, 2.59, 2.44], "rotation_deg": 0.0})
	var blocked: Dictionary = ArenaLanes.measure(across)[0]
	assert_true(not blocked["pass"], "a container across the street fails (%.2f m)" % blocked["narrowest_physical_m"])
	var low := data.duplicate(true)
	low["obstacles"].append({"type": "barricade", "position": [0.0, 5.0], "size": [6.0, 0.9, 0.8], "rotation_deg": 0.0})
	var barricaded: Dictionary = ArenaLanes.measure(low)[0]
	# The width is measured ACROSS the lane from its centre line, so anything standing on the line reads 0: a lane is
	# a route drivable along its whole length, and a prop across it is exactly what R4 forbids.
	assert_true(not barricaded["pass"], "a 0.9 m barricade across the street fails too: it stops a hull, whatever it does to sight")


func test_a_tight_corner_fails_the_rig_and_an_open_one_passes() -> void:
	var data := {"name": "probe", "half_size": 120.0, "obstacles": [],
			"lanes": [{"name": "dogleg", "points": [[0.0, 60.0], [0.0, 0.0], [60.0, 0.0]], "width": 18.0}]}
	var the_bar := ArenaLanes.bar()
	var open: Array = ArenaLanes.corners(data, the_bar)
	assert_eq(open.size(), 1, "one bend")
	assert_near(open[0]["delta_deg"], 90.0, 0.01, "of 90 degrees")
	var expected: float = the_bar["physical_bar_m"] / 2.0 + the_bar["rig_min_turn_m"] * (1.0 / cos(deg_to_rad(45.0)) - 1.0)
	assert_near(open[0]["r_eff_m"], expected, 0.001, "r_eff = r_a + R_min (sec(Δψ/2) − 1)")
	assert_true(open[0]["pass"], "an empty corner passes")
	data["obstacles"].append({"type": "crate", "position": [4.0, -4.0], "size": [4.5, 3.0, 4.5], "rotation_deg": 0.0})
	var tight: Array = ArenaLanes.corners(data, the_bar)
	assert_true(not tight[0]["pass"], "a crate on the corner's inside fails (clearance %.2f m < %.2f)" % [
			tight[0]["clearance_m"], tight[0]["r_eff_m"]])


func test_every_lane_is_drivable_two_abreast() -> void:
	var failures: PackedStringArray = []
	var measured := 0
	for layout_name in Arena.layout_names():
		var data: Dictionary = Arena.load_layout(layout_name)["layout"]
		if data.get("lanes", []).is_empty() or Arena.is_fixture(data):
			continue
		for line in ArenaLanes.describe(data):
			print(line)
		if not _asserted(layout_name, data):
			continue
		for lane: Dictionary in ArenaLanes.measure(data):
			measured += 1
			if not lane["pass"]:
				failures.append("%s / %s: %.2f m drivable at (%.0f, %.0f)" % [layout_name, lane["name"],
						lane["narrowest_drivable_m"], lane["at"].x, lane["at"].y])
	assert_true(measured >= 7, "the Terminus's lanes at least were measured (%d)" % measured)
	assert_true(failures.is_empty(), "every lane keeps %.2f m drivable: %s" % [ArenaLanes.bar()["drivable_bar_m"],
			"; ".join(failures)])


func test_every_lane_corner_and_junction_clears_the_rig() -> void:
	var failures: PackedStringArray = []
	for layout_name in Arena.layout_names():
		var data: Dictionary = Arena.load_layout(layout_name)["layout"]
		if not _asserted(layout_name, data):
			continue
		for corner: Dictionary in ArenaLanes.corners(data):
			if not corner["pass"]:
				failures.append("%s / %s at (%.0f, %.0f): Δψ %.0f°, clearance %.2f m < r_eff %.2f m" % [layout_name,
						" × ".join(corner["lanes"]), corner["where"].x, corner["where"].y, corner["delta_deg"],
						corner["clearance_m"], corner["r_eff_m"]])
	assert_true(failures.is_empty(), "every corner clears the rig: %s" % "; ".join(failures))


func test_the_terminus_declares_the_streets_he_drives() -> void:
	var data: Dictionary = Arena.load_layout("terminus")["layout"]
	var names: Array = data["lanes"].map(func(l: Dictionary) -> String: return String(l["name"]))
	for street in ["the avenue", "west street", "east street", "the ring road", "plaza crossing"]:
		assert_true(names.any(func(n: String) -> bool: return n.begins_with(street)), "the Terminus declares %s (%s)" % [street, names])
