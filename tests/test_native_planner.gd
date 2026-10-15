extends TestCase
## Round 31 (planner CP-P0): **the C++ planner is the GDScript planner, bit for bit.** Every offline fixture of
## tests/test_planner_fixtures.gd (the same budgets and epsilons) and the lab's four navmesh fixtures
## (tests/planner/planner_lab.gd, on the real Terminus and yard) are planned both ways from one request, and the
## legs, code, cost, expansions, nodes, `why` and the traced end pose must be equal; the free-space table per hull
## class equal bit for bit; and the per-tick SLICE (P6: `begin` / `step(n)` / `result`) must give the whole plan at
## 50, 200 and 1000 expansions a step. Each fixture prints both paths' microseconds (the machine named): the cost line
## CP-P0 owes. Skipped (said) without the library.

const SLICES: Array[int] = [50, 200, 1000]

var _impl: Object = null
var _rows: PackedStringArray = []


## The machine every number here is quoted with (HOSTNAME is unset in some shells: /etc/hostname then).
static func _host() -> String:
	var host := OS.get_environment("HOSTNAME")
	if host == "" and FileAccess.file_exists("/etc/hostname"):
		host = FileAccess.get_file_as_string("/etc/hostname").strip_edges()
	return host if host != "" else "unknown-host"


func _skip() -> bool:
	if not NativeBridge.available or not ClassDB.class_exists("PlannerNative"):
		print("native: absent, the planner equality is not exercised in this run")
		return true
	if _impl == null:
		_impl = ClassDB.instantiate("PlannerNative")
	return false


## The offline fixtures, exactly as test_planner_fixtures.gd requests them.
static func _offline() -> Array:
	var out: Array = []
	var f6a := PlannerFixtures.turn_round("gang_tank", 20.0)
	f6a.budget = 6000
	f6a.epsilon = 2.0
	out.append(["F6a rig turn-round 20 m", f6a])
	var f6b := PlannerFixtures.turn_round("gang_tank", 12.0)
	f6b.budget = 4000
	f6b.fine_retry = false
	out.append(["F6b rig turn-round 12 m", f6b])
	var ifv := PlannerFixtures.turn_round("ifv", 12.0)
	ifv.budget = 3000
	ifv.epsilon = 2.0
	out.append(["F6b IFV turn-round 12 m", ifv])
	var tj := PlannerFixtures.t_junction("gang_tank")
	tj.budget = 3000
	out.append(["T-junction rig", tj])
	var mouth := PlannerFixtures.mouth_with_hull("ifv")
	mouth.budget = 3000
	out.append(["mouth IFV", mouth])
	var mouth_rig := PlannerFixtures.mouth_with_hull("gang_tank")
	mouth_rig.budget = 3000
	out.append(["mouth rig", mouth_rig])
	var yard := PlannerFixtures.yard_corner("gang_tank")
	yard.budget = 4000
	out.append(["yard corner rig", yard])
	var slot := PlannerFixtures.slot_180("law_scout", 14.0)
	slot.budget = 3000
	out.append(["slot 180 scout, 14 m causeway", slot])
	var open_slot := PlannerFixtures.slot_180("law_scout")
	open_slot.budget = 600
	open_slot.epsilon = 2.0
	out.append(["slot 180 scout, open ground", open_slot])
	var wedge := PlannerFixtures.wedge("gang_tank")
	wedge.budget = 3000
	out.append(["wedge rig", wedge])
	for i in 4:
		var packed := PlannerFixtures.packed_line("gang_tank", 12.0, i, 4.0)
		packed.budget = 800
		packed.epsilon = 2.0
		out.append(["packed line rig %d" % i, packed])
	out.append(["blocked start", PlannerFixtures.packed_line("gang_tank", 3.0, 1, 4.0)])
	var goal_in_wall := PlannerFixtures.turn_round("gang_tank", 20.0)
	goal_in_wall.to(12.0, 0.0, 0.0, 1.0, 1.0, 8.0)
	out.append(["goal in a wall", goal_in_wall])
	var there := PlannerFixtures.turn_round("gang_tank", 20.0)
	there.to(0.5, 0.0, 0.0, -1.0, 1.0, 8.0)
	out.append(["already there", there])
	return out


## One request planned by the GDScript search and by the C++ one; every observable compared. Returns [gd, native].
func _both(label: String, req: PlanRequest) -> Array:
	var was := Planner.native_on
	Planner.native_on = false
	var t0 := Time.get_ticks_usec()
	var gd := Planner.plan(req)
	var gd_usec := Time.get_ticks_usec() - t0
	var gd_nodes := Planner.last_nodes
	var gd_last := Planner.last_expansions
	Planner.native_on = true
	assert_true(Planner.native_usable(), "%s: the native planner is usable in this run" % label)
	t0 = Time.get_ticks_usec()
	var nat := Planner.plan(req)
	var nat_usec := Time.get_ticks_usec() - t0
	var nat_nodes := Planner.last_nodes
	var nat_last := Planner.last_expansions
	Planner.native_on = was
	var row := "%s: %s %s | cost %.6f | %d expansions, %d nodes | GDScript %d us, native %d us (%.0fx) on %s" % [
			label, nat.code, nat.describe(), nat.cost_s, nat.expansions, nat_nodes, gd_usec, nat_usec,
			float(gd_usec) / maxf(float(nat_usec), 1.0), _host()]
	print("NATIVE_PLANNER " + row)
	_rows.append(row)
	assert_eq(nat.code, gd.code, "%s: the same code (%s v %s)" % [label, nat.code, gd.code])
	assert_eq(nat.describe(), gd.describe(), "%s: the same legs" % label)
	assert_eq(nat.legs.size(), gd.legs.size(), "%s: the same number of legs" % label)
	for i in mini(nat.legs.size(), gd.legs.size()):
		assert_true(nat.legs[i] == gd.legs[i], "%s: leg %d equal bit for bit (%s v %s)" % [label, i, nat.legs[i], gd.legs[i]])
	assert_true(nat.cost_s == gd.cost_s, "%s: the same cost (%.9f v %.9f)" % [label, nat.cost_s, gd.cost_s])
	assert_eq(nat.expansions, gd.expansions, "%s: the same expansions" % label)
	assert_eq(nat_last, gd_last, "%s: the same last-search expansions" % label)
	if gd.code == PackedPlan.OK or gd.code == PackedPlan.NO_PATH or gd.code == PackedPlan.BUDGET:
		assert_eq(nat_nodes, gd_nodes, "%s: the same node count" % label)
	assert_eq(nat.why, gd.why, "%s: the same why" % label)
	assert_eq(nat.cusps, gd.cusps, "%s: the same cusps" % label)
	assert_true(nat.metres == gd.metres, "%s: the same metres" % label)
	assert_eq(nat.poses.size(), gd.poses.size(), "%s: the same trace" % label)
	assert_true(nat.end_x == gd.end_x and nat.end_z == gd.end_z and nat.end_fx == gd.end_fx and nat.end_fz == gd.end_fz,
			"%s: the same end pose" % label)
	# The lazy clearance field after the plan (the GDScript world's, filled by its search; the C++ session's, by its):
	# the same window, every cell the same bits, the same number of spilled cells. The planner's own `plan` call ran
	# the native search on `_impl`'s twin, so the field is read back from Planner's instance.
	if gd.code != PackedPlan.START_BLOCKED:
		var field: Dictionary = Planner._impl.debug_field()
		var cells: PackedFloat32Array = field["field"]
		assert_eq(int(field["x0"]), req.world._field_x0, "%s: the field window's x0" % label)
		assert_eq(int(field["z0"]), req.world._field_z0, "%s: the field window's z0" % label)
		assert_eq(int(field["n"]), req.world._field_n, "%s: the field window's size" % label)
		var shared: bool = field.get("shared", false)
		if not shared:
			assert_eq(int(field["spill"]), req.world._spill.size(), "%s: the same spilled cells" % label)
		var differ := 0
		var filled := 0
		for i in mini(cells.size(), req.world._field.size()):
			if req.world._field[i] > PlannerWorld.UNSET_BELOW:
				filled += 1
				if cells[i] != req.world._field[i]:
					differ += 1  # a shared (navmesh) cache may hold MORE cells than this plan read; never a different one
			elif not shared and cells[i] != req.world._field[i]:
				differ += 1
		assert_eq(cells.size(), req.world._field.size(), "%s: the same field size" % label)
		assert_eq(differ, 0, "%s: every field cell equal bit for bit (%d of %d filled, %d differ)" % [label, filled, cells.size(), differ])
		_rows.append("%s: field %d of %d cells read, %d spilled" % [label, filled, cells.size(), int(field["spill"])])
	return [gd, nat]


func test_every_offline_fixture_plans_the_same_both_ways() -> void:
	if _skip():
		return
	var n := 0
	for item: Array in _offline():
		_both(String(item[0]), item[1] as PlanRequest)
		n += 1
	print("MEASURE native_planner offline: %d fixtures planned both ways on %s" % [n, _host()])
	assert_true(n >= 17, "every offline fixture ran (%d)" % n)


## The lab's fixtures on the real arenas (planner_lab.gd `_fixtures`): the navmesh world, no other hulls.
func _nav_request(arena: Arena, unit: String, start: Array, goal: Array, tol_m: float) -> PlanRequest:
	var world := PlannerNavWorld.new()
	world.map = arena.get_world_3d().navigation_map
	world.bake_radius = Movement.bake_radius(arena)
	var start_f := Vector2(sin(deg_to_rad(float(start[2]))), -cos(deg_to_rad(float(start[2]))))
	var goal_f := Vector2(sin(deg_to_rad(float(goal[2]))), -cos(deg_to_rad(float(goal[2]))))
	var req := PlanRequest.for_unit(unit).at(float(start[0]), float(start[1]), start_f.x, start_f.y) \
			.to(float(goal[0]), float(goal[1]), goal_f.x, goal_f.y, tol_m, 8.0).in_world(world)
	req.budget = 6000
	return req


func test_the_lab_fixtures_on_the_navmesh_plan_the_same_both_ways() -> void:
	if _skip():
		return
	var terminus := await ArenaFixture.build(self, "terminus")
	_both("lab turnround (Terminus rig, face south)", _nav_request(terminus, "gang_tank", [-70.0, 0.0, 0.0], [-70.0, 0.0, 180.0], 2.0))
	_both("lab slot180 (Terminus scout)", _nav_request(terminus, "law_scout", [0.0, 60.0, 0.0], [0.0, 51.0, 180.0], 1.0))
	_both("lab tjunction (Terminus rig onto the ring road)", _nav_request(terminus, "gang_tank", [-70.0, 50.0, 0.0], [-48.0, 30.0, 90.0], 1.5))
	terminus.free()
	await drain_navigation()
	# The yard corner is a BUDGET answer after 12 000 expansions (6 000 coarse + 6 000 fine): 129 s of GDScript on
	# builder0 for one row, which would make this file the suite's shard floor (C31.9). It runs under `make planner-twin`
	# (PLANNER_TWIN_ALL=1) and stays out of `check`; the equality it proves is the same search on a second navmesh.
	if OS.get_environment("PLANNER_TWIN_ALL") == "":
		print("native_planner: the yard lab fixture is skipped in check (PLANNER_TWIN_ALL=1 runs it: 129 s of GDScript for a BUDGET row)")
		return
	var yard := await ArenaFixture.build(self, "yard")
	_both("lab yardcorner (yard rig)", _nav_request(yard, "gang_tank", [-34.0, 60.0, 0.0], [-8.0, 38.0, 90.0], 1.5))
	yard.free()
	await drain_navigation()


func test_the_free_space_table_is_the_same_bit_for_bit() -> void:
	if _skip():
		return
	for unit: String in ["gang_tank", "ifv", "law_scout"]:
		var req := PlanRequest.for_unit(unit)
		var t0 := Time.get_ticks_usec()
		var gd := PlannerHeuristic.table_for(req)
		var gd_usec := Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec()
		var nat: PackedFloat32Array = _impl.table(req.to_native())
		var nat_usec := Time.get_ticks_usec() - t0
		assert_eq(nat.size(), gd.size(), "%s: the table has the same size" % unit)
		var differ := 0
		var first := ""
		var reached := 0
		for i in mini(nat.size(), gd.size()):
			if gd[i] != INF:
				reached += 1
			if nat[i] != gd[i]:
				differ += 1
				if first == "":
					first = "index %d: native %s v GDScript %s" % [i, nat[i], gd[i]]
		print("MEASURE native_planner table %s: %d cells, %d reached, %d differ; GDScript %d us (cached: %s), native %d us (build %d us) on %s" % [
				unit, gd.size(), reached, differ, gd_usec, "yes" if gd_usec < 50000 else "no", nat_usec, int(_impl.table_build_usec()),
				_host()])
		assert_eq(differ, 0, "%s: every table cell equal bit for bit; first: %s" % [unit, first])
		assert_true(reached > 1000, "%s: the table is populated (%d reached)" % [unit, reached])


func test_the_slice_returns_the_whole_plan() -> void:
	if _skip():
		return
	var picks: Array = []
	for item: Array in _offline():
		var label := String(item[0])
		if label.begins_with("T-junction") or label.begins_with("wedge") or label.begins_with("slot 180 scout, 14") \
				or label.begins_with("F6b rig") or label.begins_with("packed line rig 1") or label.begins_with("F6a"):
			picks.append(item)
	assert_eq(picks.size(), 6, "six fixtures sliced (%d)" % picks.size())
	for item: Array in picks:
		var label := String(item[0])
		var req := item[1] as PlanRequest
		var whole: Dictionary = _impl.plan(req.to_native())
		for slice in SLICES:
			assert_true(_impl.begin(req.to_native()), "%s: a session begins" % label)
			var steps := 0
			while not _impl.step(slice):
				steps += 1
				assert_true(steps < 100000, "%s: the sliced search ends" % label)
			steps += 1
			var sliced: Dictionary = _impl.result()
			print("NATIVE_PLANNER_SLICE %s at %d a step: %d steps, %s %s, %d expansions (whole: %s, %d)" % [label, slice, steps,
					String(sliced["code"]), str(sliced["legs"]), int(sliced["expansions"]), String(whole["code"]), int(whole["expansions"])])
			assert_eq(String(sliced["code"]), String(whole["code"]), "%s at %d: the same code" % [label, slice])
			assert_true(sliced["legs"] == whole["legs"], "%s at %d: the same legs" % [label, slice])
			assert_true(float(sliced["cost_s"]) == float(whole["cost_s"]), "%s at %d: the same cost" % [label, slice])
			assert_eq(int(sliced["expansions"]), int(whole["expansions"]), "%s at %d: the same expansions" % [label, slice])
			assert_eq(int(sliced["nodes"]), int(whole["nodes"]), "%s at %d: the same nodes" % [label, slice])
			assert_eq(int(sliced["first_at"]), int(whole["first_at"]), "%s at %d: the same first plan" % [label, slice])
			# ceil(expansions / slice) steps per search phase, plus one for the pass that finishes.
			assert_true(steps <= int(ceil(float(whole["expansions"]) / float(slice))) + 2, "%s at %d: %d steps for %d expansions" % [
					label, slice, steps, int(whole["expansions"])])
