extends TestCase
## Round 5 combat X1: EngagementStats measures the SHAPE of a fight (how far apart the armies stand, whether they move,
## where kills come from, whether cover is used) without touching the simulation. The lead: "it's just these 2 masses
## shooting at each other". These tests pin the definitions the numbers in balance.md rest on.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _wall(x: float, z: float, rotation_deg := 0.0) -> Dictionary:
	return {"position": Vector3(x, 0.0, z), "size": Vector3(18.0, 3.0, 1.5), "rotation": deg_to_rad(rotation_deg),
			"height": 3.0, "type": "wall"}


func test_distance_to_cover_is_measured_to_the_footprint_not_its_center() -> void:
	var wall := _wall(0.0, 0.0)
	assert_near(EngagementStats.distance_to_feature(Vector3(0, 0, 0), wall), 0.0, 0.001, "inside the footprint is 0")
	assert_near(EngagementStats.distance_to_feature(Vector3(0, 0, 4.75), wall), 4.0, 0.001, "4 m off the long face")
	assert_near(EngagementStats.distance_to_feature(Vector3(12, 0, 0), wall), 3.0, 0.001, "3 m past the end")
	var turned := _wall(0.0, 0.0, 90.0)
	assert_near(EngagementStats.distance_to_feature(Vector3(4.75, 0, 0), turned), 4.0, 0.001,
			"a wall turned 90 degrees has its long face along z")


func test_near_cover_uses_the_cover_radius() -> void:
	var stats := EngagementStats.new([_wall(0.0, 0.0)])
	assert_true(stats.near_cover(Vector3(0, 0, 0.75 + EngagementStats.COVER_RADIUS - 0.1)), "just inside the radius")
	assert_true(not stats.near_cover(Vector3(0, 0, 0.75 + EngagementStats.COVER_RADIUS + 0.1)), "just outside it")
	assert_true(not EngagementStats.new([]).near_cover(Vector3.ZERO), "an empty arena has no cover")


func test_kills_split_into_front_flank_rear_and_indirect() -> void:
	var stats := EngagementStats.new([])
	stats.record_kill(0, "front", false, 40.0, false, false)
	stats.record_kill(0, "side", false, 30.0, true, false)
	stats.record_kill(1, "rear", false, 20.0, false, true)
	stats.record_kill(1, "side", true, 100.0, false, false)
	var summary := stats.summary()
	assert_eq(summary["kills"], {"front": 1, "side": 1, "rear": 1, "indirect": 1}, "an arc's kill is indirect, not side")
	assert_near(float(summary["flank_rear_kill_share"]), 2.0 / 3.0, 0.001, "shares count direct kills only")
	assert_near(float(summary["kill_distance_median"]), 35.0, 0.001, "median of 20, 30, 40, 100")
	assert_near(float(summary["kills_by_cover_shooters_share"]), 0.25, 0.001, "one killer of four stood by cover")
	assert_near(float(summary["deaths_near_cover_share"]), 0.25, 0.001, "one victim of four died by cover")


func test_a_standing_exchange_reads_static_and_a_maneuver_does_not() -> void:
	var standing := EngagementStats.new([])
	var moving := EngagementStats.new([])
	for second in 20:
		var green := [{"position": Vector3(0, 0, 40), "speed": 0.2, "near_cover": false}]
		var rust := [{"position": Vector3(0, 0, -40), "speed": 0.0, "near_cover": false}]
		standing.sample([green, rust], 5)
		var green_moving := [{"position": Vector3(second * 4.0, 0, 40 - second * 2.0), "speed": 4.5, "near_cover": true}]
		moving.sample([green_moving, rust], 5)
	var still := standing.summary()
	var move := moving.summary()
	assert_near(float(still["static_share"]), 1.0, 0.001, "nobody moved while shooting")
	assert_near(float(still["engaged_distance_median"]), 80.0, 0.001, "they traded from 80 m")
	assert_near(float(move["static_share"]), 0.0, 0.001, "one side maneuvering is not a static exchange")
	assert_true(float(move["centroid_travel"][0]) > 80.0, "Green's centre of mass travelled (%s)" % [move["centroid_travel"]])
	assert_near(float(move["centroid_travel"][1]), 0.0, 0.001, "Rust's did not")
	assert_near(float(move["unit_seconds_near_cover_share"]), 0.5, 0.001, "half the unit-seconds were spent by cover")


func test_quiet_seconds_before_contact_do_not_count_as_fighting() -> void:
	var stats := EngagementStats.new([])
	for second in 10:
		stats.sample([[{"position": Vector3(0, 0, 90 - second * 5.0), "speed": 5.0, "near_cover": false}],
				[{"position": Vector3(0, 0, -90), "speed": 0.0, "near_cover": false}]], 0)
	stats.sample([[{"position": Vector3(0, 0, 40), "speed": 0.0, "near_cover": false}],
			[{"position": Vector3(0, 0, -90), "speed": 0.0, "near_cover": false}]], 3)
	var summary := stats.summary()
	assert_eq(int(summary["contact_second"]), 10, "contact is the first second anyone fired")
	assert_near(float(summary["separation_at_contact"]), 130.0, 0.001, "centroids were 130 m apart at first shot")
	assert_eq(int(summary["combat_seconds"]), 1, "only seconds with shots are combat seconds")
	assert_near(float(summary["centroid_travel"][0]), 0.0, 0.001, "the approach is not counted as fight movement")


func test_a_real_match_fills_the_engagement_block() -> void:
	var arena := add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.set_meta("arena", arena)
	game_match.seed_spawns(3, 0.0)
	var army := {"name": "T", "squads": [{"name": "A", "units": [{"unit": "tank"}, {"unit": "ifv"}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, army), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, army), "", "rust loads")
	await wait_physics_frames(EngagementStats.SAMPLE_TICKS * 3)
	var engagement: Dictionary = game_match.result("time_limit")["stats"]["engagement"]
	assert_true(int(engagement["samples"]) >= 2, "sampled once a second (%s)" % engagement["samples"])
	for key in ["static_share", "engaged_distance_median", "kills", "flank_rear_kill_share", "centroid_travel",
			"shots_near_cover_share", "unit_seconds_near_cover_share"]:
		assert_true(engagement.has(key), "the summary has %s" % key)


func test_two_armies_trading_fire_in_place_read_as_a_held_line_even_while_weaving() -> void:
	var stats := EngagementStats.new([])
	for second in 20:
		# Every hull jinks at 5 m/s, but the armies' centres don't go anywhere.
		var wobble := 1.0 if second % 2 == 0 else -1.0
		stats.sample([[{"position": Vector3(wobble, 0, 40), "speed": 5.0, "near_cover": false}],
				[{"position": Vector3(-wobble, 0, -40), "speed": 5.0, "near_cover": false}]], 5)
	var summary := stats.summary()
	assert_near(float(summary["static_share"]), 0.0, 0.001, "by hull speed nobody is standing still")
	assert_true(float(summary["held_line_share"]) > 0.7, "but the line is held (%s)" % summary["held_line_share"])
	assert_near(float(summary["net_advance"][0]), 0.0, 1.5, "and neither army advanced")


func test_an_army_that_pushes_forward_advances_and_does_not_hold_a_line() -> void:
	var stats := EngagementStats.new([])
	for second in 20:
		stats.sample([[{"position": Vector3(0, 0, 60 - second * 2.0), "speed": 2.0, "near_cover": false}],
				[{"position": Vector3(0, 0, -60), "speed": 0.0, "near_cover": false}]], 5)
	var summary := stats.summary()
	assert_near(float(summary["held_line_share"]), 0.0, 0.001, "2 m/s forward is 10 m in 5 s: not a held line")
	assert_near(float(summary["net_advance"][0]), 38.0, 0.5, "Green advanced 38 m toward Rust")
	assert_near(float(summary["net_advance"][1]), 0.0, 0.001, "Rust stayed")


func test_a_kill_from_across_the_line_is_on_axis_and_one_from_the_side_is_not() -> void:
	var stats := EngagementStats.new([])
	stats.sample([[{"position": Vector3(0, 0, 40), "speed": 0.0, "near_cover": false}],
			[{"position": Vector3(0, 0, -40), "speed": 0.0, "near_cover": false}]], 1)
	stats.record_kill_bearing(0, Vector3(0, 0, 40), Vector3(10, 0, -20))  # from in front of Green's line
	stats.record_kill_bearing(0, Vector3(0, 0, 40), Vector3(60, 0, 40))  # from Green's right flank
	stats.record_kill_bearing(0, Vector3(0, 0, 40), Vector3(0, 0, 90))  # from behind Green's line
	var summary := stats.summary()
	assert_near(float(summary["off_axis_kill_share"]), 2.0 / 3.0, 0.001, "the flank and the rear are off axis")
	assert_near(float(summary["behind_line_kill_share"]), 1.0 / 3.0, 0.001, "only the rear one is behind the line")
