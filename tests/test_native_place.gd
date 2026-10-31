extends TestCase
## Round 47 (native N2): TacticsFormation.place natively (NativePlace -> place_native.cpp) against its LIVE GDScript
## (BrainSwitches.native_place off), bit for bit (var_to_bytes of the entries), over random elements: catalogue units and bare
## names, with and without positions, every formation and group shape, headings including none, the place options its callers
## pass (count, centered, halt / halted, seat_bound, floor_rule, shear, policy, leader, layout, keep, set_up_at, via, at, previous,
## fixed, seat_order) and every TacticsFormation switch the C++ reads (SEAT_BOUND / SEAT_ORDER / SEAT_LAST_OPEN, the seat cost's
## TRAVEL_SUM_FIRST / SHORT_SWAP_ENABLED / SQUARED_ALONG_ROUTE / NEAREST_ENABLED, LATERAL_FLOOR). His replays read the same
## equality on every real call with TANK_NATIVE_PLACE_VERIFY=1 (NativePlace._verify).

const TRIALS := 4000
const SHAPES: Array[String] = ["column", "wedge", "vee", "line", "echelon_left", "echelon_right", "herringbone", "coil", "swarm",
		"ring", "rows", "single", "block", "nonsense"]
const POLICIES: Array[String] = ["front", "travel", "exposure"]
const FLOORS: Array[String] = ["", "width", "one_turning", "both_turning", "dressing"]


func _members(rng: RandomNumberGenerator, n: int, units: PackedStringArray, anchor: Vector3) -> Array:
	var out := []
	var positioned := rng.randf() < 0.85
	for i in n:
		var m := {"name": "Green_Alpha_%d" % (i + 1)}
		var pick := rng.randf()
		if pick < 0.75:
			m["unit"] = units[rng.randi_range(0, units.size() - 1)]
		elif pick < 0.85:
			m["role"] = ["tank", "artillery", "scout", "lancer"][rng.randi_range(0, 3)]
		if positioned or rng.randf() < 0.2:
			var p := anchor + Vector3(rng.randf_range(-60.0, 60.0), 0.0, rng.randf_range(-60.0, 60.0))
			if rng.randf() < 0.15 and i > 0 and out[i - 1].has("position"):
				p = Vector3(out[i - 1]["position"]) + Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2))  # abreast
			m["position"] = p
		out.append(m)
	return out


func _opts(rng: RandomNumberGenerator, members: Array, anchor: Vector3) -> Dictionary:
	var o := {}
	var n := members.size()
	if rng.randf() < 0.2:
		o["count"] = n + rng.randi_range(0, 3)
	if rng.randf() < 0.15:
		o["centered"] = false
	if rng.randf() < 0.3:
		o["halt"] = true
	if rng.randf() < 0.1:
		o["halted"] = rng.randf() < 0.5
	if rng.randf() < 0.2:
		o["seat_bound"] = rng.randf() < 0.5
	if rng.randf() < 0.2:
		o["floor_rule"] = FLOORS[rng.randi_range(0, FLOORS.size() - 1)]
	if rng.randf() < 0.1:
		o["shear"] = rng.randf_range(-0.5, 0.5)
	if rng.randf() < 0.7:
		o["policy"] = POLICIES[rng.randi_range(0, POLICIES.size() - 1)]
	if rng.randf() < 0.3 and n > 0:
		o["leader"] = String(members[rng.randi_range(0, n - 1)]["name"])
	if rng.randf() < 0.05:
		o["layout"] = true
	if rng.randf() < 0.1 and n > 1:
		o["keep"] = {String(members[0]["name"]): rng.randi_range(0, n - 1)}
	if rng.randf() < 0.15:
		var set_up := []
		for k in rng.randi_range(1, 3):
			set_up.append(anchor + Vector3(rng.randf_range(-30.0, 30.0), 0.0, rng.randf_range(-30.0, 30.0)))
		o["set_up_at"] = set_up
	if rng.randf() < 0.1:
		o["via"] = [anchor + Vector3(rng.randf_range(-40.0, 40.0), 0.0, 30.0), anchor + Vector3(rng.randf_range(-40.0, 40.0), 0.0, 10.0)]
	if rng.randf() < 0.15:
		var at := []
		for k in n + rng.randi_range(0, 2):
			at.append(anchor + Vector3(rng.randf_range(-40.0, 40.0), 0.0, rng.randf_range(-40.0, 40.0)) if rng.randf() < 0.9 else null)
		o["at"] = at
	if rng.randf() < 0.35 and n > 0:
		var order := range(n + rng.randi_range(0, 1))
		order.shuffle()
		var previous := {}
		for i in n:
			previous[String(members[i]["name"])] = order[i] if rng.randf() < 0.95 else -1
		o["previous"] = previous
	if rng.randf() < 0.1:
		o["fixed"] = true
	if rng.randf() < 0.3:
		o["seat_order"] = true
	return o


func test_native_place_is_the_live_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the place equality is not exercised in this run")
		return
	var saved := [BrainSwitches.native_place, TacticsFormation.SEAT_BOUND, TacticsFormation.SEAT_ORDER, TacticsFormation.SEAT_LAST_OPEN,
			TacticsFormation.TRAVEL_SUM_FIRST, TacticsFormation.SHORT_SWAP_ENABLED, TacticsFormation.SQUARED_ALONG_ROUTE,
			TacticsFormation.NEAREST_ENABLED, TacticsFormation.LATERAL_FLOOR]
	var units := Units.ids()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4701
	var mismatches := 0
	var reseated := 0
	var bounded := 0
	var first := ""
	for trial in TRIALS:
		TacticsFormation.SEAT_BOUND = rng.randf() < 0.6
		TacticsFormation.SEAT_ORDER = rng.randf() < 0.5
		TacticsFormation.SEAT_LAST_OPEN = rng.randf() < 0.5
		TacticsFormation.TRAVEL_SUM_FIRST = rng.randf() < 0.8
		TacticsFormation.SHORT_SWAP_ENABLED = rng.randf() < 0.3
		TacticsFormation.SQUARED_ALONG_ROUTE = rng.randf() < 0.8
		TacticsFormation.NEAREST_ENABLED = rng.randf() < 0.85
		TacticsFormation.LATERAL_FLOOR = ["dressing", "width", "one_turning", "both_turning"][rng.randi_range(0, 3)] \
				if rng.randf() < 0.3 else "dressing"
		var anchor := Vector3(rng.randf_range(-150.0, 150.0), rng.randf_range(0.0, 2.0), rng.randf_range(-150.0, 150.0))
		var n := trial % 9 if trial % 17 != 3 else 12
		var members := _members(rng, n, units, anchor)
		var formation: String = SHAPES[rng.randi_range(0, SHAPES.size() - 1)]
		var heading := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.2, 0.2), rng.randf_range(-1.0, 1.0))
		if trial % 13 == 5:
			heading = Vector3.ZERO
		var spacing := [8.0, 11.0, 14.0, 18.0, rng.randf_range(0.5, 25.0)][rng.randi_range(0, 4)]
		var opts := _opts(rng, members, anchor)
		BrainSwitches.native_place = false
		var live := TacticsFormation.place(members, formation, anchor, heading, spacing, opts)
		BrainSwitches.native_place = true
		var native := TacticsFormation.place(members, formation, anchor, heading, spacing, opts)
		for entry: Dictionary in live:
			if int(entry["index"]) != members.find_custom(func(m: Dictionary) -> bool: return m["name"] == entry["unit"]):
				reseated += 1
				break
		if TacticsFormation.SEAT_BOUND and live.size() >= 2:
			bounded += 1
		if var_to_bytes(live) != var_to_bytes(native):
			mismatches += 1
			if first == "":
				first = "trial %d %s n %d opts %s: live %s native %s" % [trial, formation, n, opts, live, native]
	BrainSwitches.native_place = saved[0]
	TacticsFormation.SEAT_BOUND = saved[1]
	TacticsFormation.SEAT_ORDER = saved[2]
	TacticsFormation.SEAT_LAST_OPEN = saved[3]
	TacticsFormation.TRAVEL_SUM_FIRST = saved[4]
	TacticsFormation.SHORT_SWAP_ENABLED = saved[5]
	TacticsFormation.SQUARED_ALONG_ROUTE = saved[6]
	TacticsFormation.NEAREST_ENABLED = saved[7]
	TacticsFormation.LATERAL_FLOOR = saved[8]
	print("MEASURE native_place compared=%d mismatches=%d reseated=%d bounded=%d" % [TRIALS, mismatches, reseated, bounded])
	assert_eq(mismatches, 0, "native place = the GDScript on every element (%d); first: %s" % [TRIALS, first])
	assert_true(reseated > 1000, "the comparison exercised seatings off the members' order (%d of %d)" % [reseated, TRIALS])
