extends TestCase
## Squad's deciders ask Objectives where the fight's objectives are, and Objectives reads N7's per-match list
## (Match.objectives). A layout may declare several, off the centre: a decider goes for the nearest one its team does
## not hold. Round 7: before this, the seam knew only the central zone, and arena's first above-zero maps ran a whole
## match with the CPU competing for the wrong ground (lesson 122: degraded is worse than fatal).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")

## The files whose deciders must ask Objectives, never the pre-N7 central zone.
const DECIDERS := ["res://game/ai/cpu_commander.gd", "res://game/tactics/element_commander.gd",
		"res://game/ai/tank_brain.gd", "res://game/agent/discovery_bridge.gd", "res://game/tactics/objectives.gd"]


## A match with a mirrored off-centre pair (arena's shape: one near each base), none at the centre.
func _paired() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	game_match.control_point = true
	add_to_tree(game_match)
	game_match.objectives = [
		{"name": "west", "position": Vector3(-50.0, 0.0, 40.0), "radius": 14.0, "owner": -1, "progress": 0.0},
		{"name": "east", "position": Vector3(50.0, 0.0, -40.0), "radius": 14.0, "owner": -1, "progress": 0.0}]
	return game_match


func test_a_decider_goes_for_the_nearest_objective_its_team_does_not_hold() -> void:
	var game_match := _paired()
	var south := Vector3(0, 0, 100)
	assert_eq(String(Objectives.goal(game_match, Match.Team.GREEN, south)["name"]), "west", "the nearer one first")
	assert_eq(String(Objectives.goal(game_match, Match.Team.GREEN, Vector3(60, 0, -30))["name"]), "east",
			"from somewhere else, the one nearer there")
	game_match.objectives[0]["owner"] = Match.Team.GREEN
	assert_eq(String(Objectives.goal(game_match, Match.Team.GREEN, south)["name"]), "east",
			"once it holds the near one, the one it does not hold, however far")
	assert_eq(String(Objectives.goal(game_match, Match.Team.RUST, south)["name"]), "west",
			"the enemy still goes for the one Green holds")
	game_match.objectives[1]["owner"] = Match.Team.GREEN
	assert_eq(String(Objectives.goal(game_match, Match.Team.GREEN, south)["name"]), "west",
			"holding both, it stays on the nearest")
	assert_true(Objectives.all_held(game_match, Match.Team.GREEN) and not Objectives.all_held(game_match, Match.Team.RUST),
			"all_held is per team")


func test_on_an_objective_is_any_objective_and_held_is_per_team() -> void:
	var game_match := _paired()
	game_match.objectives[1]["owner"] = Match.Team.RUST
	assert_true(Objectives.contains(game_match, Vector3(-45, 0, 45)), "inside the west zone")
	assert_true(not Objectives.contains(game_match, Vector3.ZERO), "the centre is nobody's objective on this map")
	assert_true(Objectives.held_at(game_match, Match.Team.RUST, Vector3(52, 0, -38)), "Rust stands on the one it holds")
	assert_true(not Objectives.held_at(game_match, Match.Team.GREEN, Vector3(52, 0, -38)), "Green does not hold it")


func test_the_brain_contests_the_objective_it_would_actually_go_for() -> void:
	var game_match := _paired()
	var control: Dictionary = TankBrain._control_of(game_match, Match.Team.RUST, Vector3(40, 0, -90))
	assert_eq(control["center"], Vector3(50.0, 0.0, -40.0), "a Rust tank near the east objective contests it, not the centre")
	assert_near(float(control["radius"]), 14.0, 0.001, "with its own radius")
	game_match.control_point = false
	assert_true(TankBrain._control_of(game_match, Match.Team.RUST, Vector3.ZERO) == null, "no objectives: nothing to contest")


func test_one_central_zone_is_still_the_centre() -> void:
	# Every pre-N7 arena: N7 reads a layout with no `objectives` list as the one central zone.
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	game_match.control_point = true
	add_to_tree(game_match)
	await wait_physics_frames(2)
	var target := Objectives.goal(game_match, Match.Team.GREEN, Vector3(0, 0, 100))
	assert_eq(target["position"], Match.CONTROL_CENTER, "the centre, as before")


func test_no_decider_reads_the_pre_n7_central_zone() -> void:
	# The rule, enforced (lesson 47): the constant and the static helper can only know the default central zone.
	for path: String in DECIDERS:
		var source := FileAccess.get_file_as_string(path)
		assert_true(source.length() > 0, "setup: %s reads" % path)
		for banned in ["CONTROL_CENTER", "in_control_zone(", "control_owner"]:
			assert_true(source.find(banned) < 0, "%s does not read Match.%s: ask Objectives" % [path.get_file(), banned])
