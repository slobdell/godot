extends TestCase
## Round 19 (board, S1; contract C19.4): ONE score, read everywhere. `Match.score_snapshot()` is what the HUD's score
## bug, the radar, the arena screens, the results screen and the CPU's posture read; `score_changed(snapshot)` fires
## once per change of anything on it. Reading only: the rules of winning are not touched here.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup(control := true) -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	game_match.control_point = control
	add_to_tree(game_match)
	return game_match


func _armies(game_match: Match) -> void:
	var green := {"name": "G", "squads": [{"name": "A", "units": [{"unit": "tank"}, {"unit": "scout"}]}]}
	var rust := {"name": "R", "squads": [{"name": "B", "units": [{"unit": "ifv"}, {"unit": "scout"}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, green), "", "setup: green")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, rust), "", "setup: rust")


func _two_objectives(game_match: Match) -> void:
	game_match.objectives = [
		{"name": "the west ring", "position": Vector3(-60.0, 0.0, 0.0), "radius": 16.0, "owner": -1, "progress": 0.0},
		{"name": "the west ring (far)", "position": Vector3(60.0, 0.0, 0.0), "radius": 16.0, "owner": -1, "progress": 0.0}]


func _kill(game_match: Match, victim_name: String, team: int, shooter: String) -> void:
	var victim := game_match.tanks.get_node(victim_name) as Tank
	victim.shield = 0.0
	game_match._land_hit(victim, 100000.0, Weapons.profile("cannon"), Vector3.FORWARD, team, shooter, "", true)


func test_a_fresh_match_reads_level_and_names_the_sides_by_faction() -> void:
	var game_match := _setup()
	_armies(game_match)
	await wait_physics_frames(2)
	var snap := game_match.score_snapshot()
	assert_eq(snap["points_to_win"], Match.CONTROL_POINTS_TO_WIN, "the win line is the rules' line")
	assert_true(bool(snap["control"]), "control is on")
	assert_eq(snap["leader"], -1, "nobody leads a fresh match")
	assert_eq((snap["sides"] as Array).size(), 2, "two sides")
	for team in 2:
		var side: Dictionary = snap["sides"][team]
		assert_eq(side["team"], team, "side %d is team %d" % [team, team])
		assert_eq(side["points"], 0, "no points yet")
		assert_eq(side["to_win"], Match.CONTROL_POINTS_TO_WIN, "the whole way to go")
		assert_eq(side["kills"], 0, "no kills yet")
		assert_eq(side["points_destroyed"], 0, "no credits destroyed yet")
		assert_eq(side["units_alive"], 2, "two units each")
		assert_eq(side["zones_held"], 0, "no zones held")
		assert_eq(side["faction"], "condemned", "the faction it fields")
	# Both field the Condemned here, so the screens' rule names them HOME and AWAY, never by colour.
	assert_eq([snap["sides"][0]["name"], snap["sides"][1]["name"]], ["HOME", "AWAY"], "same faction: home and away")
	assert_eq((snap["objectives"] as Array).size(), 1, "the default arena has one zone")
	assert_eq(snap["objectives"][0]["label"], "the centre", "and it is called the centre, because it is one")


func test_the_snapshot_follows_one_zone_being_taken_and_scoring() -> void:
	var game_match := _setup()
	var green := game_match.spawn_tank("Green_1", 0, Match.Team.GREEN)
	green.global_position = Vector3(5, 0, 5)
	green.reset_physics_interpolation()
	await wait_physics_frames(roundi(Match.CONTROL_CAPTURE_SECONDS * 0.5 * float(SimClock.TICK_RATE)))
	var half := game_match.score_snapshot()
	var zone: Dictionary = half["sides"][0]["zones"][0]
	assert_true(not bool(zone["held"]), "half way through the capture it is not held yet")
	assert_near(float(zone["fill"]), 0.5, 0.08, "and the fill reads about half")
	assert_near(float(half["sides"][1]["zones"][0]["fill"]), 0.0, 0.0001, "the other side's fill is empty")
	await wait_physics_frames(roundi(Match.CONTROL_CAPTURE_SECONDS * 0.5 * float(SimClock.TICK_RATE)) + SimClock.TICK_RATE * 4)
	var snap := game_match.score_snapshot()
	assert_eq(game_match.control_owner, Match.Team.GREEN, "setup: Green holds it")
	assert_true(bool(snap["sides"][0]["zones"][0]["held"]), "the snapshot says Green holds it")
	assert_eq(snap["sides"][0]["zones_held"], 1, "one zone held")
	assert_eq(snap["sides"][0]["points"], game_match.control_score[0], "points are the rules' points")
	assert_eq(snap["sides"][0]["to_win"], Match.CONTROL_POINTS_TO_WIN - game_match.control_score[0], "and the rest to go")
	assert_true(int(snap["sides"][0]["points"]) >= 2, "and they are scoring (%d)" % snap["sides"][0]["points"])
	assert_near(float(snap["sides"][0]["rate"]), 1.0, 0.0001, "holding every zone scores a point a second")
	assert_eq(snap["leader"], Match.Team.GREEN, "Green leads on points")


func test_two_zones_are_read_one_by_one_with_the_maps_names() -> void:
	var game_match := _setup()
	await wait_physics_frames(2)
	_two_objectives(game_match)
	game_match.objectives[1]["owner"] = Match.Team.RUST
	game_match.objectives[1]["progress"] = -1.0
	game_match.objectives[0]["progress"] = 0.25
	var snap := game_match.score_snapshot()
	var labels: Array = (snap["objectives"] as Array).map(func(o: Dictionary) -> String: return String(o["label"]))
	assert_eq(labels, ["the west ring", "the east ring"], "the mirror is named for where it is, the map's own word kept")
	var green: Dictionary = snap["sides"][0]
	var rust: Dictionary = snap["sides"][1]
	assert_eq(green["zones_held"], 0, "Green holds none")
	assert_near(float(green["zones"][0]["fill"]), 0.25, 0.0001, "but is a quarter of the way into the west ring")
	assert_eq(rust["zones_held"], 1, "Rust holds one")
	assert_true(bool(rust["zones"][1]["held"]), "the east ring")
	assert_eq(rust["zones"][1]["name"], "the west ring (far)", "the map's own name rides along")
	assert_near(float(rust["rate"]), 0.5, 0.0001, "holding one of two scores half a point a second")
	assert_near(float(green["rate"]), 0.0, 0.0001, "holding none scores nothing")


func test_zone_labels() -> void:
	assert_eq(MatchScore.zone_label("control point", ["control point"]), "the centre", "the one central zone")
	assert_eq(MatchScore.zone_label("the depot (far)", ["the depot", "the depot (far)"]), "the far depot",
			"a mirror with no compass word")
	assert_eq(MatchScore.zone_label("the far quay (far)", ["the far quay", "the far quay (far)"]), "the far quay (far)",
			"a name that already says far keeps the map's word")
	assert_eq(MatchScore.zone_label("the west yard (far)", ["the west yard", "the west yard (far)"]), "the east yard",
			"compass words swap")
	assert_eq(MatchScore.zone_label("the band", ["the band", "the band (far)"]), "the band", "the authored one as written")


func test_an_enemy_kill_counts_its_price_and_signals_once() -> void:
	var game_match := _setup(false)
	_armies(game_match)
	await wait_physics_frames(2)
	var seen: Array = []
	game_match.score_changed.connect(func(snapshot: Dictionary) -> void: seen.append(snapshot))
	await wait_physics_frames(SimClock.TICK_RATE / 2)
	assert_eq(seen.size(), 0, "nothing changes, nothing fires")
	_kill(game_match, "Rust_B_1", Match.Team.GREEN, "Green_A_1")
	await wait_physics_frames(3)
	assert_eq(seen.size(), 1, "a kill fires the signal once")
	if seen.is_empty():
		return
	var green: Dictionary = seen[0]["sides"][0]
	assert_eq(green["kills"], 1, "Green has a kill")
	assert_eq(green["points_destroyed"], int(Units.stat("ifv", "cost", 0)), "worth what the victim cost")
	assert_eq(seen[0]["sides"][1]["units_alive"], 1, "Rust is a unit down")
	assert_eq(seen[0]["leader"], Match.Team.GREEN, "without control, the side that destroyed more leads")
	assert_true(int(seen[0]["version"]) > 0, "the snapshot carries a version")
	_kill(game_match, "Rust_B_2", Match.Team.GREEN, "Green_A_1")
	await wait_physics_frames(3)
	assert_eq(seen.size(), 2, "and once again for the next")
	assert_true(int(seen[1]["version"]) > int(seen[0]["version"]), "a newer version")
	assert_eq(seen[1]["sides"][0]["points_destroyed"], int(Units.stat("ifv", "cost", 0)) + int(Units.stat("scout", "cost", 0)),
			"the credits add up")


func test_friendly_and_hazard_kills_are_not_credited() -> void:
	var game_match := _setup(false)
	_armies(game_match)
	await wait_physics_frames(2)
	var seen: Array = []
	game_match.score_changed.connect(func(snapshot: Dictionary) -> void: seen.append(snapshot))
	_kill(game_match, "Green_A_2", Match.Team.GREEN, "Green_A_1")
	await wait_physics_frames(3)
	var snap := game_match.score_snapshot()
	assert_eq(snap["sides"][0]["kills"], 0, "killing a teammate is no kill")
	assert_eq(snap["sides"][1]["kills"], 0, "nor the enemy's")
	assert_eq(snap["sides"][0]["points_destroyed"] + snap["sides"][1]["points_destroyed"], 0, "and no credits")
	assert_eq(snap["sides"][0]["units_alive"], 1, "but the unit is gone")
	assert_eq(seen.size(), 1, "which is a change, once")
	var victim := game_match.tanks.get_node("Rust_B_1") as Tank
	victim.shield = 0.0
	victim.take_hit(100000.0, 1.0, 1.0)
	game_match._announce_destroyed(victim, "hazard:fire")
	await wait_physics_frames(3)
	snap = game_match.score_snapshot()
	assert_eq(snap["sides"][0]["kills"] + snap["sides"][1]["kills"], 0, "the arena's kills are nobody's")
	assert_eq(snap["sides"][1]["units_alive"], 1, "Rust is a unit down")


func test_the_snapshot_is_a_copy() -> void:
	var game_match := _setup()
	await wait_physics_frames(2)
	var snap := game_match.score_snapshot()
	snap["sides"][0]["points"] = 80
	(snap["objectives"] as Array).clear()
	assert_eq(game_match.score_snapshot()["sides"][0]["points"], 0, "a reader cannot write the score")
	assert_eq((game_match.score_snapshot()["objectives"] as Array).size(), 1, "nor the zones")


func test_the_final_score_is_filled_before_finished_is_heard() -> void:
	## Round 19 (garage's finding at the close): Match emitted `finished` before `final_score` was filled, so a results
	## screen reading it from its `finished` handler saw {} and had to take its own snapshot.
	var game_match := _setup(false)
	_armies(game_match)
	game_match.elimination = true
	var seen := {}
	game_match.finished.connect(func(_result: Dictionary) -> void: seen["final_score"] = game_match.final_score.duplicate(true))
	for tank_name in ["Rust_B_1", "Rust_B_2"]:
		if game_match.tanks.has_node(tank_name):
			_kill(game_match, tank_name, Match.Team.GREEN, "Green_A_1")
	game_match._check_finished()
	assert_true(seen.has("final_score"), "the match finished")
	assert_true(not (seen["final_score"] as Dictionary).is_empty(), "final_score is filled before finished is heard")
	assert_eq(int((seen["final_score"]["sides"][0] as Dictionary).get("kills", -1)), 2, "the sheet carries the kills")

