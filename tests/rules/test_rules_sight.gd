extends TestCase
## Round 37 (rules R1, C37.2): a crew's OWN motion sets its sight. Driving it sees ~85 % of its radius; stopped for a
## couple of seconds (a dwell: a brief halt doesn't count) it sees ~110 %; the change blends, never flickers, and composes
## with suppression's penalty. The lab case he will notice: a crew halted at a crossroads sees a column coming before
## the column sees it. Both paths: `RuleSwitches.sight_on` ON and OFF.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")

## The lane the lab case runs down (open ground in the default arena: both crews see each other along it).
const LANE_X := -100.0

func teardown() -> void:
	RuleSwitches.sight_on = RuleSwitches._on("sight")  # back to what this run's flags say
	super.teardown()


func _setup() -> Match:
	var arena := add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.set_meta("arena", arena)
	return game_match


## One standard tank a side (sight 62 m), no brains: Green parked at z = -70, Rust at z = +75 facing it (forward is -Z).
func _pair(game_match: Match) -> Array:
	var one := {"name": "T", "squads": [{"name": "A", "units": [{"unit": "tank"}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, one), "", "green loads")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, one), "", "rust loads")
	var parked := game_match.tanks.get_node("Green_A_1") as Tank
	var mover := game_match.tanks.get_node("Rust_A_1") as Tank
	for brain in game_match.brains.get_children():
		brain.queue_free()  # scripted: no brains deciding anything
	await wait_physics_frames(1)
	parked.global_position = Vector3(LANE_X, 0.0, -70.0)
	parked.rotation.y = PI  # facing +Z, toward the mover
	mover.global_position = Vector3(LANE_X, 0.0, 75.0)
	mover.rotation.y = 0.0
	return [parked, mover]


func _hold(tanks: Array, ticks: int, throttle := 0.0) -> void:
	for tick in ticks:
		(tanks[0] as Tank).command = TankCommand.new()
		(tanks[1] as Tank).command = TankCommand.new(throttle, 0.0, (tanks[0] as Tank).global_position, false)
		await wait_physics_frames(1)


func _sees(game_match: Match, team: int, enemy: Tank) -> bool:
	return bool(game_match.intel[team].get(String(enemy.name), {}).get("visible", false))


# ---- The rule on one crew ------------------------------------------------------------

func test_driving_shrinks_sight_and_a_dwell_stretches_it() -> void:
	RuleSwitches.sight_on = true
	var game_match := _setup()
	var pair: Array = await _pair(game_match)
	var mover: Tank = pair[1]
	var calm := float(Units.stat("tank", "sight_radius"))
	await _hold(pair, SimClock.TICK_RATE * 2, 1.0)
	assert_near(mover.sight_radius, calm * Tank.MOVING_SIGHT_FACTOR, 0.5,
			"two seconds of driving: it sees ~85 %% of its radius (%.1f of %.0f m)" % [mover.sight_radius, calm])
	await _hold(pair, SimClock.TICK_RATE, 0.0)
	assert_near(mover.sight_radius, calm * Tank.MOVING_SIGHT_FACTOR, 0.5,
			"a one-second halt is not a dwell: sight stays where it was (%.1f m)" % mover.sight_radius)
	await _hold(pair, SimClock.TICK_RATE * 3, 0.0)
	assert_near(mover.sight_radius, calm * Tank.HALTED_SIGHT_FACTOR, 0.5,
			"stopped long enough, it sees ~110 %% (%.1f m)" % mover.sight_radius)


func test_the_change_blends_and_never_jumps() -> void:
	RuleSwitches.sight_on = true
	var game_match := _setup()
	var pair: Array = await _pair(game_match)
	var mover: Tank = pair[1]
	await _hold(pair, SimClock.TICK_RATE * 4, 0.0)  # dwelled: ~110 %
	var biggest_step := 0.0
	var last := mover.sight_radius
	for i in SimClock.TICK_RATE * 3:
		await _hold(pair, 1, 1.0)
		biggest_step = maxf(biggest_step, absf(mover.sight_radius - last))
		last = mover.sight_radius
	var calm := float(Units.stat("tank", "sight_radius"))
	assert_near(mover.sight_radius, calm * Tank.MOVING_SIGHT_FACTOR, 0.5, "it got to the driving radius")
	assert_true(biggest_step < calm * 0.03,
			"but in steps no bigger than a few metres (largest %.2f m), not a jump of %.0f m"
			% [biggest_step, calm * (Tank.HALTED_SIGHT_FACTOR - Tank.MOVING_SIGHT_FACTOR)])


func test_it_composes_with_suppression() -> void:
	RuleSwitches.sight_on = true
	var game_match := _setup()
	var pair: Array = await _pair(game_match)
	var parked: Tank = pair[0]
	var calm := float(Units.stat("tank", "sight_radius"))
	await _hold(pair, SimClock.TICK_RATE * 4, 0.0)
	parked.suppression = 1.0
	parked.settle_suppression(1.0, 0.0)
	await _hold(pair, Match.SUPPRESSION_SAMPLE_TICKS, 0.0)
	parked.suppression = 1.0  # the field around it is quiet; hold the crew's head down for the reading
	parked.settle_suppression(1.0, 0.0)
	parked.settle_motion_sight(0.0)
	assert_near(parked.sight_radius, calm * (1.0 - Tank.SUPPRESSION_SIGHT_PENALTY) * Tank.HALTED_SIGHT_FACTOR, 0.5,
			"a halted crew with its head down: both factors (%.1f m)" % parked.sight_radius)
	parked.suppression = 0.0
	parked.settle_suppression(0.0, 0.0)
	parked.settle_motion_sight(0.0)
	assert_near(parked.sight_radius, calm * Tank.HALTED_SIGHT_FACTOR, 0.5,
			"and the radius it gets back is its own, not a compounded one (%.1f m)" % parked.sight_radius)


func test_switched_off_sight_ignores_motion() -> void:
	RuleSwitches.sight_on = false
	var game_match := _setup()
	var pair: Array = await _pair(game_match)
	var calm := float(Units.stat("tank", "sight_radius"))
	await _hold(pair, SimClock.TICK_RATE * 2, 1.0)
	assert_near((pair[1] as Tank).sight_radius, calm, 0.001, "OFF: a driving crew sees its catalog radius")
	await _hold(pair, SimClock.TICK_RATE * 4, 0.0)
	assert_near((pair[0] as Tank).sight_radius, calm, 0.001, "OFF: so does a parked one")


# ---- The lab case: halted at a crossroads, a column coming ---------------------------

## Drive Rust at Green until both have seen each other; the gap (m) at which each first saw the other.
func _approach(game_match: Match, pair: Array) -> Dictionary:
	var parked: Tank = pair[0]
	var mover: Tank = pair[1]
	await _hold(pair, SimClock.TICK_RATE * 3, 0.0)  # both parked long enough to dwell
	var spotted := {}
	for tick in SimClock.TICK_RATE * 15:
		await _hold(pair, 1, 1.0)
		var gap := parked.global_position.distance_to(mover.global_position)
		if not spotted.has("parked") and _sees(game_match, Match.Team.GREEN, mover):
			spotted["parked"] = gap
		if not spotted.has("mover") and _sees(game_match, Match.Team.RUST, parked):
			spotted["mover"] = gap
		if spotted.size() == 2 or gap < 30.0:
			break
	return spotted


func test_a_halted_crew_spots_an_oncoming_one_first() -> void:
	RuleSwitches.sight_on = true
	var game_match := _setup()
	var pair: Array = await _pair(game_match)
	var spotted: Dictionary = await _approach(game_match, pair)
	var calm := float(Units.stat("tank", "sight_radius"))
	assert_true(spotted.has("parked") and spotted.has("mover"), "both crews see each other in the end (%s)" % spotted)
	assert_near(float(spotted.get("parked", 0.0)), calm * Tank.HALTED_SIGHT_FACTOR, 2.0,
			"the halted crew sees the column at ~110 %% of its radius (%.1f m)" % float(spotted.get("parked", 0.0)))
	assert_near(float(spotted.get("mover", 0.0)), calm * Tank.MOVING_SIGHT_FACTOR, 2.0,
			"the driving crew only at ~85 %% (%.1f m)" % float(spotted.get("mover", 0.0)))
	assert_true(float(spotted.get("parked", 0.0)) - float(spotted.get("mover", 0.0)) > 0.2 * calm,
			"the halted crew has the first look by %.1f m" % (float(spotted.get("parked", 0.0))
			- float(spotted.get("mover", 0.0))))


func test_switched_off_both_crews_spot_at_the_same_range() -> void:
	RuleSwitches.sight_on = false
	var game_match := _setup()
	var pair: Array = await _pair(game_match)
	var spotted: Dictionary = await _approach(game_match, pair)
	var calm := float(Units.stat("tank", "sight_radius"))
	assert_near(float(spotted.get("parked", 0.0)), calm, 2.0, "OFF: the halted crew sees at its radius (%s)" % spotted)
	assert_near(float(spotted.get("mover", 0.0)), calm, 2.0, "OFF: and so does the driving one")
