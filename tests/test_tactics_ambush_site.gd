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
