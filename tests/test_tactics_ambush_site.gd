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
