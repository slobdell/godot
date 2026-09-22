extends TestCase
## Round 10 (terrain's report, relayed by the orchestrator): the radar and the tactical map drew the control-point ring at
## Match.CONTROL_CENTER whenever --control was on, but a layout with an objective pair (yard, pit, terminus) is scored
## on ITS objectives. The player saw a ring at a centre nobody fights over and none at the real objectives. The rings
## drawn are now exactly the zones Match scores: Radar.objective_rings(match) == match.objectives, on every layout.

const MATCH := preload("res://game/match/match.tscn")


func test_the_drawn_rings_are_the_scored_objectives_on_every_layout() -> void:
	var was: Dictionary = Arena.active
	var off_centre := 0
	for file in DirAccess.get_files_at("res://arenas"):
		if not file.ends_with(".json"):
			continue
		var layout_name := file.get_basename()
		var loaded := Arena.load_layout(layout_name)
		if loaded.has("error"):
			continue
		Arena.active = loaded["layout"]
		var game_match := MATCH.instantiate() as Match
		game_match.load_objectives()
		var scored: Array = game_match.objectives.map(func(o: Dictionary) -> Vector3: return o["position"])
		var drawn: Array = Radar.objective_rings(game_match).map(func(r: Dictionary) -> Vector3: return r["position"])
		assert_eq(drawn, scored, "%s: one ring per scored objective, where it is scored" % layout_name)
		for ring: Dictionary in Radar.objective_rings(game_match):
			if (ring["position"] as Vector3).distance_to(Match.CONTROL_CENTER) > 1.0:
				off_centre += 1
		game_match.free()
	Arena.active = was
	assert_true(off_centre >= 2, "the objective-pair layouts put rings away from the centre (%d)" % off_centre)


func test_a_layout_without_objectives_still_gets_the_central_zone() -> void:
	var game_match := MATCH.instantiate() as Match
	game_match.objectives = []
	var rings := Radar.objective_rings(game_match)
	assert_eq(rings.size(), 1, "one ring")
	assert_eq(rings[0]["position"], Match.CONTROL_CENTER, "at the centre, as --control always meant")
	game_match.free()
