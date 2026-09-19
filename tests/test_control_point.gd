extends TestCase
## Stretch (anti-snowball): the center control point.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	game_match.control_point = true
	add_to_tree(game_match)
	return game_match


func test_one_tank_captures_the_center_and_scores() -> void:
	var game_match := _setup()
	var green := game_match.spawn_tank("Green_1", 0, Match.Team.GREEN)
	green.global_position = Vector3(5, 0, 5)
	green.reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
	await wait_physics_frames(roundi(Match.CONTROL_CAPTURE_SECONDS * float(SimClock.TICK_RATE)) - SimClock.TICK_RATE / 2)
	assert_eq(game_match.control_owner, -1, "not captured before %.0f s" % Match.CONTROL_CAPTURE_SECONDS)
	await wait_physics_frames(SimClock.TICK_RATE)
	assert_eq(game_match.control_owner, Match.Team.GREEN, "captured after %.0f s" % Match.CONTROL_CAPTURE_SECONDS)
	await wait_physics_frames(SimClock.TICK_RATE * 3)
	assert_true(game_match.control_score[Match.Team.GREEN] >= 2, "the holder scores a point a second (%d)" % game_match.control_score[0])


func test_a_bigger_army_does_not_capture_faster_and_contesting_freezes_it() -> void:
	var game_match := _setup()
	for i in 4:
		var tank := game_match.spawn_tank("Green_%d" % i, 0, Match.Team.GREEN)
		tank.global_position = Vector3(-8 + i * 5, 0, 6)
		tank.reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
	await wait_physics_frames(roundi(Match.CONTROL_CAPTURE_SECONDS * float(SimClock.TICK_RATE)) / 2)
	assert_true(game_match.control_owner == -1, "four tanks still take the full capture time (flat rate: anti-snowball)")
	var rust := game_match.spawn_tank("Rust_1", 0, Match.Team.RUST)
	rust.global_position = Vector3(0, 0, -8)
	rust.reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
	await wait_physics_frames(Match.INTEL_EVERY_TICKS)
	var frozen := game_match.control_progress
	await wait_physics_frames(SimClock.TICK_RATE * 4)
	assert_near(game_match.control_progress, frozen, 0.001, "with both teams inside, capture stops")


func test_holding_to_the_limit_wins_the_match() -> void:
	var game_match := _setup()
	var results: Array = []
	game_match.finished.connect(func(result: Dictionary) -> void: results.append(result))
	game_match.spawn_tank("Rust_1", 0, Match.Team.RUST).global_position = Vector3(0, 0, 0)
	game_match.spawn_tank("Rust_1", 0, Match.Team.RUST).reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
	game_match.spawn_tank("Green_1", 0, Match.Team.GREEN)
	game_match.control_owner = Match.Team.RUST
	game_match.control_progress = -1.0
	game_match._control_ticks = [0, (Match.CONTROL_POINTS_TO_WIN - 1) * SimClock.TICK_RATE]
	await wait_physics_frames(SimClock.TICK_RATE * 3 / 2)
	assert_eq(results.size(), 1, "the match ends")
	assert_eq(results[0]["winner"], "Rust", "the holder wins")
	assert_eq(results[0]["reason"], "control", "by control")


func test_brains_go_take_a_center_they_dont_hold() -> void:
	var s := {
		"tick": 1000, "self": {"name": "Green_A_1", "team": 0, "position": Vector3(0, 0, 60), "forward": Vector3.FORWARD,
				"health": 300, "max_health": 300, "shield": 150.0, "max_shield": 150.0, "weapon": Weapons.profile("cannon")},
		"directives": Directives.resolve([]), "contacts": [], "allies": [], "objective": null, "objective_radius": 0.0,
		"squad_center": null, "cover": [], "rally": Vector3(0, 0, 90), "enemy_base": Vector3(0, 0, -90),
		"memory_ticks": Match.CONTACT_MEMORY_TICKS,
		"control": {"center": Vector3.ZERO, "radius": Match.CONTROL_RADIUS, "owner": -1},
	}
	assert_eq(TankBrain.label(TankBrain.decide(s, {})["choice"]), "CONTEST", "a neutral center is worth taking")
	s["control"]["owner"] = 0
	assert_eq(TankBrain.label(TankBrain.decide(s, {})["choice"]), "CONTEST", "ours but I'm outside: come hold it")
	s["control"] = null
	assert_eq(TankBrain.label(TankBrain.decide(s, {})["choice"]), "ADVANCE", "without a control point, nothing changes")


# ---- N7 (round 6): the match is fought over the LAYOUT's objectives ----------------------
# Why this contract exists, from CP4's decomposition: the gates (sight, acquisition) moved kill distance -11 m and
# off-axis kills +17 points where the effective bands moved them -3 m and +2 -- and a SINGLE CENTRAL objective is the
# terrain-level version of the same problem, because it collapses the space in which acquisition and flanking can
# matter at all. The 45% off-axis kills were measured *despite* one central control point on every map.

func _two_objectives(game_match: Match, apart: float) -> void:
	game_match.objectives = [
		{"name": "west", "position": Vector3(-apart, 0.0, 0.0), "radius": 16.0, "owner": -1, "progress": 0.0},
		{"name": "east", "position": Vector3(apart, 0.0, 0.0), "radius": 16.0, "owner": -1, "progress": 0.0}]


func test_a_layout_without_objectives_still_gets_the_one_central_zone() -> void:
	# The read-through's whole claim: no shipped arena changes. `--control` is a MATCH flag, not a layout property,
	# so a layout that declares nothing must still get exactly the zone this file used to hard-code.
	var game_match := _setup()
	await wait_physics_frames(2)
	assert_eq(game_match.objectives.size(), 1, "exactly one objective")
	assert_eq(game_match.objectives[0]["position"], Match.CONTROL_CENTER, "at the arena centre")
	assert_near(float(game_match.objectives[0]["radius"]), Match.CONTROL_RADIUS, 0.001, "at the hard-coded radius")


func test_the_scalars_are_a_view_of_the_primary_objective_not_a_copy() -> void:
	# A copy is what broke this file when N7 landed: the tick overwrote a poked value and the match never ended.
	var game_match := _setup()
	await wait_physics_frames(2)
	game_match.control_owner = Match.Team.RUST
	assert_eq(game_match.objectives[0]["owner"], Match.Team.RUST, "writing the scalar writes the objective")
	game_match.objectives[0]["progress"] = -1.0
	assert_near(game_match.control_progress, -1.0, 0.001, "and reading the scalar reads the objective")


func test_each_objective_is_captured_on_its_own() -> void:
	var game_match := _setup()
	await wait_physics_frames(2)
	_two_objectives(game_match, 60.0)
	game_match.spawn_tank("Green_1", 0, Match.Team.GREEN).global_position = Vector3(-60, 0, 0)
	game_match.spawn_tank("Rust_1", 0, Match.Team.RUST).global_position = Vector3(60, 0, 0)
	await wait_physics_frames(SimClock.TICK_RATE * (Match.CONTROL_CAPTURE_SECONDS + 1.0))
	assert_eq(game_match.objectives[0]["owner"], Match.Team.GREEN, "Green took the one it is standing on")
	assert_eq(game_match.objectives[1]["owner"], Match.Team.RUST, "Rust took the other, at the same time")
	assert_eq(game_match.control_owner, Match.Team.GREEN, "the scalar still reports the primary objective")


func test_holding_half_the_objectives_scores_at_half_the_rate() -> void:
	# The rule that makes N7 a read-through rather than a balance change: score by the SHARE held, so holding them
	# all scores at exactly the pre-N7 rate and at N=1 it reduces to the old accumulation exactly.
	var both := _setup()
	await wait_physics_frames(2)
	_two_objectives(both, 60.0)
	for objective in both.objectives:
		# Owner AND progress: an owner with no progress is inconsistent, and the tick correctly clears it back to
		# neutral on the next update ("pushed back past neutral"). Holding means the capture bar is full.
		objective["owner"] = Match.Team.GREEN
		objective["progress"] = 1.0
	var half := _setup()
	await wait_physics_frames(2)
	_two_objectives(half, 60.0)
	half.objectives[0]["owner"] = Match.Team.GREEN
	half.objectives[0]["progress"] = 1.0
	var ticks := SimClock.TICK_RATE * 6
	await wait_physics_frames(ticks)
	assert_true(both.control_score[Match.Team.GREEN] > 0, "holding both scores (%d)" % both.control_score[Match.Team.GREEN])
	assert_near(float(half.control_score[Match.Team.GREEN]), float(both.control_score[Match.Team.GREEN]) / 2.0, 1.01,
			"holding one of two scores at half the rate (%d against %d)"
			% [half.control_score[Match.Team.GREEN], both.control_score[Match.Team.GREEN]])
