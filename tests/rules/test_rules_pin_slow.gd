extends TestCase
## Round 37 (rules R3, C37.2, his "slow, never stop, and show it"): suppression caps a crew's drive speed, down to
## 1 - Tank.PIN_SLOW_MAX (~60 %) at full suppression, never 0; `Tank.pin_slow()` (0..1) is what feedback shows.
## `RuleSwitches.pin_slow_on`, both paths.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func teardown() -> void:
	RuleSwitches.pin_slow_on = RuleSwitches._on("pin_slow")
	super.teardown()


func _setup() -> Match:
	var arena := add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.set_meta("arena", arena)
	return game_match


## Full throttle for three seconds with suppression held at `held`: the top speed it reached (m/s).
func _top_speed(held: float) -> float:
	var game_match := _setup()
	var tank := game_match.spawn_tank("Green_Lab_1", 0, Match.Team.GREEN, "tank")
	tank.place(Vector3(-100.0, 0.0, 80.0), 0.0)
	await wait_physics_frames(2)
	var top := 0.0
	for tick in SimClock.TICK_RATE * 3:
		tank.suppression = held  # a machine gun somewhere keeps the crew's head down
		tank.command = TankCommand.new(1.0, 0.0, tank.global_position + Vector3(0, 0, -100), false)
		await wait_physics_frames(1)
		top = maxf(top, absf(tank.speed()))
	free_owned()
	return top


func test_full_suppression_slows_a_charge_but_never_stops_it() -> void:
	RuleSwitches.pin_slow_on = true
	var calm := await _top_speed(0.0)
	var pinned := await _top_speed(1.0)
	assert_near(calm, float(Units.stat("tank", "max_forward_speed")), 0.2, "calm: full speed (%.2f m/s)" % calm)
	assert_near(pinned / calm, 1.0 - Tank.PIN_SLOW_MAX, 0.05, "fully suppressed: ~60 %% of it (%.2f m/s)" % pinned)
	assert_true(pinned > 0.5 * calm, "and never anywhere near a stop")


func test_the_slow_scales_with_suppression() -> void:
	RuleSwitches.pin_slow_on = true
	var calm := await _top_speed(0.0)
	var half := await _top_speed(0.5)
	assert_near(half / calm, 1.0 - Tank.PIN_SLOW_MAX * 0.5, 0.05, "half suppressed: ~80 %% (%.2f m/s)" % half)


func test_pin_slow_reads_zero_when_off() -> void:
	var game_match := _setup()
	var tank := game_match.spawn_tank("Green_Lab_1", 0, Match.Team.GREEN, "tank")
	tank.suppression = 0.7
	RuleSwitches.pin_slow_on = true
	assert_near(tank.pin_slow(), 0.7, 0.0001, "ON: what feedback shows follows suppression")
	RuleSwitches.pin_slow_on = false
	assert_near(tank.pin_slow(), 0.0, 0.0001, "OFF: nothing is slowed, nothing to show")


func test_switched_off_suppression_never_slows_driving() -> void:
	RuleSwitches.pin_slow_on = false
	var calm := await _top_speed(0.0)
	var pinned := await _top_speed(1.0)
	assert_near(pinned, calm, 0.05, "OFF: a pinned crew drives at full speed, as before (%.2f v %.2f)" % [pinned, calm])
