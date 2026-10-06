extends TestCase
## Round 18 (brains): AmbushSite on parade, the map built for it ("a line abreast formation could get ambushed by another
## formation that was orthogonal"). A line coming down the middle of the floor from the Green side to the control point
## at the centre; a Rust element standing near the west bay.


func test_parade_west_bay_flanks_a_line_crossing_the_floor() -> void:
	var lab := TacticsLab.create(self, 3, "parade")
	var probe := lab.unit(Match.Team.RUST, "Rust_P_1", Vector3(-70, 0, -30), 0.0, "tank")
	await lab.start()
	var cover := CoverMap.of(probe)
	var site := AmbushSite.find(cover, Vector3(-70, 0, -30), Vector3(0, 0, 90), Vector3.ZERO, 70.0)
	print("MEASURE ambush_site parade west bay: %s" % site)
	assert_true(not site.is_empty(), "an ambush site exists on the west flank of the floor")
	if site.is_empty():
		lab.dispose()
		return
	var spot: Vector3 = site["spot"]
	var zone: Vector3 = site["zone"]
	assert_true(spot.x < -25.0, "on the flank, not the floor (spot %s)" % spot)
	assert_true(absf(zone.x) < 1.0, "its kill zone is on the line's way in (%s)" % zone)
	assert_true(not cover.clear_line(Vector3(0, 0, 90), spot), "hidden from the line where it is now")
	assert_true(cover.clear_line(spot, zone), "with a clear shot at the kill zone")
	lab.dispose()


func test_no_site_when_the_enemy_is_already_close() -> void:
	var lab := TacticsLab.create(self, 3, "parade")
	var probe := lab.unit(Match.Team.RUST, "Rust_P_1", Vector3(-70, 0, -30), 0.0, "tank")
	await lab.start()
	var site := AmbushSite.find(CoverMap.of(probe), Vector3(-70, 0, -30), Vector3(0, 0, 30), Vector3.ZERO, 70.0)
	assert_true(site.is_empty(), "an enemy 30 m from the objective has no open ground left to cross (%s)" % site)
	lab.dispose()


## Round 19 (B3): the search as round 18 built it (sorted candidates; the open test after the two sight lines), kept here
## as the reference the faster search must equal.
static func _reference_find(cover: CoverMap, element_center: Vector3, enemy_center: Vector3, objective: Vector3,
		reach_m: float) -> Dictionary:
	var enemy := Vector2(enemy_center.x, enemy_center.z)
	var goal := Vector2(objective.x, objective.z)
	var length := enemy.distance_to(goal)
	if length < AmbushSite.MIN_APPROACH_M:
		return {}
	var along_dir := (goal - enemy) / length
	var best := {}
	var best_key := []
	for index: int in cover.points_near(Vector2(element_center.x, element_center.z), AmbushSite.REACH_M):
		var point: Vector2 = cover.points[index]
		var rel := point - enemy
		var along := rel.dot(along_dir)
		var t := along / length
		if t < AmbushSite.ALONG_MIN or t > AmbushSite.ALONG_MAX:
			continue
		var lateral := (rel - along_dir * along).length()
		if lateral < AmbushSite.LATERAL_MIN_M or lateral > reach_m:
			continue
		var zone := enemy + along_dir * along
		var spot3 := Vector3(point.x, 0.0, point.y)
		var zone3 := Vector3(zone.x, 0.0, zone.y)
		if cover.clear_line(enemy_center, spot3) or not cover.clear_line(spot3, zone3):
			continue
		if not cover.points_near(zone, AmbushSite.OPEN_M).is_empty():
			continue
		var key := [snappedf(Vector2(element_center.x, element_center.z).distance_to(point), 0.01), point.x, point.y]
		if best.is_empty() or key < best_key:
			best_key = key
			best = {"spot": spot3, "zone": zone3, "lateral": lateral, "along": t}
	return best


func _equal_on(arena: String) -> void:
	var lab := TacticsLab.create(self, 3, arena)
	var probe := lab.unit(Match.Team.RUST, "Rust_P_1", Vector3(0, 0, -90), 0.0, "tank")
	await lab.start()
	var cover := CoverMap.of(probe)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var found := 0
	var fast_us := 0
	var slow_us := 0
	for i in 300:
		var element := Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-100, 40))
		var enemy := Vector3(rng.randf_range(-80, 80), 0, rng.randf_range(20, 110))
		var objective := Vector3(rng.randf_range(-70, 70), 0, rng.randf_range(-60, 30))
		var reach: float = [45.0, 60.0, 70.0][i % 3]
		# Each search timed COLD: the cover map's sight-line memo is cleared before each, so neither is handed answers
		# the other computed.
		cover._memo.clear()
		var started := Time.get_ticks_usec()
		var slow := _reference_find(cover, element, enemy, objective, reach)
		slow_us += Time.get_ticks_usec() - started
		cover._memo.clear()
		started = Time.get_ticks_usec()
		var fast := AmbushSite.find(cover, element, enemy, objective, reach)
		fast_us += Time.get_ticks_usec() - started
		if not slow.is_empty():
			found += 1
		assert_eq(fast, slow, "%s case %d: the same site (element %s, enemy %s, objective %s)" % [arena, i, element, enemy, objective])
	print("MEASURE ambush_site equal %s: 300 cases, %d with a site; sorted search %d us, fast %d us" % [arena, found,
			slow_us, fast_us])
	assert_true(found >= 10, "%s: the cases include sites (%d), so equality is not only of empties" % [arena, found])
	lab.dispose()


func test_the_fast_search_equals_the_sorted_one_on_parade() -> void:
	await _equal_on("parade")


func test_the_fast_search_equals_the_sorted_one_on_the_open_yard() -> void:
	await _equal_on("yard_open")


func test_the_fast_search_equals_the_sorted_one_on_the_sumps() -> void:
	await _equal_on("sumps")


# ---- Round 20 (brains M3): the ambush hides the LINE, not a point ------------------------------------------------------
# Round 19's known issue 1: the spot was hidden as one point, but the line lying there is ~40 m wide, and on parade his
# line saw the outer crews from parts of the floor, so the ambush sprang before the kill zone. Given the line's slot
# offsets, every slot (laid as the plan lays the ambush: a line at the spot facing the kill zone) must be hidden too.

func test_given_its_line_every_slot_of_the_site_is_hidden() -> void:
	var lab := TacticsLab.create(self, 3, "parade")
	var probe := lab.unit(Match.Team.RUST, "Rust_P_1", Vector3(-70, 0, -30), 0.0, "tank")
	await lab.start()
	var cover := CoverMap.of(probe)
	var enemy := Vector3(0, 0, 90)
	var line := TacticsFormation.centered(TacticsFormation.offsets_at("line", 4, Vector2(14, 14)))
	var point_site := AmbushSite.find(cover, Vector3(-70, 0, -30), enemy, Vector3.ZERO, 70.0)
	var line_site := AmbushSite.find(cover, Vector3(-70, 0, -30), enemy, Vector3.ZERO, 70.0, line)
	print("MEASURE ambush_site parade west bay, a point %s | a line of four %s" % [point_site, line_site])
	var exposed_before := AmbushSite.exposed_slots(cover, point_site, enemy, line) if not point_site.is_empty() else -1
	print("MEASURE round 19's site leaves %d of 4 slots in sight of the line" % exposed_before)
	assert_true(not line_site.is_empty(), "a site exists that hides a whole line (%s)" % line_site)
	if not line_site.is_empty():
		assert_eq(AmbushSite.exposed_slots(cover, line_site, enemy, line), 0, "every slot hidden from where the enemy is")
		assert_eq(int(line_site.get("exposed", -1)), 0, "and the site says so")
	var one := AmbushSite.find(cover, Vector3(-70, 0, -30), enemy, Vector3.ZERO, 70.0, [Vector2.ZERO])
	assert_eq(one["spot"], point_site["spot"], "a one-slot line is round 19's search exactly")
	# Within a Law tank's shorter reach there may be no spot that hides all four: the least exposed one still serves.
	var short := AmbushSite.find(cover, Vector3(-70, 0, -30), enemy, Vector3.ZERO, 45.0, line)
	var short_point := AmbushSite.find(cover, Vector3(-70, 0, -30), enemy, Vector3.ZERO, 45.0)
	print("MEASURE at 45 m reach: a point %s | a line %s" % [short_point, short])
	assert_eq(short.is_empty(), short_point.is_empty(), "the line never loses a site the point search has")
	if not short.is_empty():
		assert_true(int(short["exposed"]) <= AmbushSite.exposed_slots(cover, short_point, enemy, line),
				"and leaves no more crews in sight than round 19's spot")
	lab.dispose()


## Round 20 (M3): what the line test costs a search (cold sight-line memo, 300 random cases on each map, a line of four
## at pitch 14, the in-time rule on): printed, and bounded so a later change cannot make it ten times dearer unseen.
func test_the_line_search_costs_little_more_than_the_point_search() -> void:
	var line := Array(TacticsFormation.centered(TacticsFormation.offsets_at("line", 4, Vector2(14, 14))))
	for arena in ["parade", "yard_open", "sumps"]:
		var lab := TacticsLab.create(self, 3, arena)
		var probe := lab.unit(Match.Team.RUST, "Rust_P_1", Vector3(0, 0, -90), 0.0, "tank")
		await lab.start()
		var cover := CoverMap.of(probe)
		var rng := RandomNumberGenerator.new()
		rng.seed = 20
		var point_us := 0
		var line_us := 0
		for i in 300:
			var element := Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-100, 40))
			var enemy := Vector3(rng.randf_range(-80, 80), 0, rng.randf_range(20, 110))
			var objective := Vector3(rng.randf_range(-70, 70), 0, rng.randf_range(-60, 30))
			var timing := {"from": element, "speed": 8.0, "enemy_mps": 9.0, "margin_s": 4.0}
			cover._memo.clear()
			var started := Time.get_ticks_usec()
			AmbushSite.find(cover, element, enemy, objective, 60.0)
			point_us += Time.get_ticks_usec() - started
			cover._memo.clear()
			started = Time.get_ticks_usec()
			AmbushSite.find(cover, element, enemy, objective, 60.0, line, timing)
			line_us += Time.get_ticks_usec() - started
		print("MEASURE ambush_site cost %s: 300 searches, a point %d us, a line of four %d us (x%.2f)" % [arena, point_us,
				line_us, float(line_us) / maxf(point_us, 1.0)])
		assert_true(line_us < point_us * 4, "%s: the line test stays the same order of cost (%d vs %d us)" % [arena, line_us, point_us])
		lab.dispose()
