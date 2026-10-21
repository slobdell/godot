extends TestCase
## Round 37 (rules R2, C37.2): firing on the move is much less accurate (`RuleSwitches.spread_on`: a full-speed shot
## spreads 4x, not 2.5x, still scaled by speed), and a crew about to fire a long round on the move makes a SHORT HALT:
## it holds the round, brakes, fires steady, drives on. Close in it keeps rolling and shooting. Both paths.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func teardown() -> void:
	RuleSwitches.spread_on = RuleSwitches._on("spread")
	super.teardown()


func _setup() -> Match:
	var arena := add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.set_meta("arena", arena)
	return game_match


# ---- The spread itself ---------------------------------------------------------------

func test_moving_fire_spreads_four_times_at_full_speed() -> void:
	var cannon := Weapons.profile("cannon")
	RuleSwitches.spread_on = false
	var still := Match.shot_spread(cannon, 0.0, 0.0)
	assert_near(Match.shot_spread(cannon, 1.0, 0.0) / still, 2.5, 0.001, "OFF: full speed is 2.5x, as before")
	RuleSwitches.spread_on = true
	assert_near(Match.shot_spread(cannon, 0.0, 0.0), still, 0.000001, "ON: a halted shot is unchanged")
	assert_near(Match.shot_spread(cannon, 1.0, 0.0) / still, 4.0, 0.001, "ON: full speed is 4x")
	assert_near(Match.shot_spread(cannon, 0.5, 0.0) / still, 2.5, 0.001, "ON: still scaled by speed (half speed 2.5x)")


func test_the_fire_lanes_copy_follows_the_switch() -> void:
	RuleSwitches.spread_on = false
	assert_eq(Match.moving_spread_factor(), Match.MOVING_SPREAD_FACTOR, "OFF: the old factor")
	RuleSwitches.spread_on = true
	assert_eq(Match.moving_spread_factor(), Match.RULES_MOVING_SPREAD_FACTOR, "ON: the new one (fire_lanes reads this too)")


# ---- The short halt in the plant -----------------------------------------------------

## A standard tank (cannon: range 70 m, effective 45 m) driven by script along -Z at full throttle, the trigger held on
## a point `ahead` metres away to its side, for `ticks`. Returns [tank, the hull speed (m/s) at each round it fired].
func _drive_and_shoot(game_match: Match, ahead: float, ticks: int) -> Array:
	var tank := game_match.spawn_tank("Green_Lab_1", 0, Match.Team.GREEN, "tank")
	tank.place(Vector3(-100.0, 0.0, 80.0), 0.0)
	await wait_physics_frames(2)
	var speeds: Array[float] = []
	tank.fired.connect(func(_muzzle: Vector3, _forward: Vector3) -> void: speeds.append(absf(tank.speed())))
	for tick in ticks:
		var aim := tank.global_position + Vector3(ahead * 0.6, 0.0, -ahead * 0.8)
		tank.command = TankCommand.new(1.0, 0.0, aim, tick >= SimClock.TICK_RATE * 2)  # up to speed, then the trigger
		await wait_physics_frames(1)
	return [tank, speeds]


func test_a_long_shot_on_the_move_waits_for_the_hull_to_stop() -> void:
	RuleSwitches.spread_on = true
	var game_match := _setup()
	var result: Array = await _drive_and_shoot(game_match, 60.0, SimClock.TICK_RATE * 12)
	var tank: Tank = result[0]
	var speeds: Array = result[1]
	assert_true(speeds.size() >= 2, "it keeps shooting (%d rounds in 10 s of trigger)" % speeds.size())
	var still := Tank.SHORT_HALT_STILL * tank.max_forward_speed
	var rolling := speeds.filter(func(v: float) -> bool: return v >= still)
	assert_eq(rolling.size(), 0, "every 60 m round leaves a hull under %.1f m/s (speeds %s)" % [still, speeds])
	assert_true(tank.global_position.z < 80.0 - 30.0, "and between halts it drives on (%.0f m covered)"
			% (80.0 - tank.global_position.z))


func test_close_in_it_keeps_rolling() -> void:
	RuleSwitches.spread_on = true
	var game_match := _setup()
	var result: Array = await _drive_and_shoot(game_match, 15.0, SimClock.TICK_RATE * 5)
	var tank: Tank = result[0]
	var speeds: Array = result[1]
	var fast := speeds.filter(func(v: float) -> bool: return v > 0.5 * tank.max_forward_speed)
	assert_true(not fast.is_empty(), "a 15 m shot is fired on the move (speeds %s)" % [speeds])


func test_switched_off_long_shots_fly_on_the_move() -> void:
	RuleSwitches.spread_on = false
	var game_match := _setup()
	var result: Array = await _drive_and_shoot(game_match, 60.0, SimClock.TICK_RATE * 5)
	var tank: Tank = result[0]
	var speeds: Array = result[1]
	var fast := speeds.filter(func(v: float) -> bool: return v > 0.5 * tank.max_forward_speed)
	assert_true(not fast.is_empty(), "OFF: nobody stops to shoot (speeds %s)" % [speeds])


func test_the_halt_is_worth_it_only_where_motion_costs_hits() -> void:
	RuleSwitches.spread_on = true
	var game_match := _setup()
	var tank := game_match.spawn_tank("Green_Lab_1", 0, Match.Team.GREEN, "tank")
	assert_true(tank.short_halt_worth(60.0, 1.0), "60 m at full speed: worth a halt")
	assert_true(not tank.short_halt_worth(60.0, 0.1), "creeping: no halt")
	assert_true(not tank.short_halt_worth(15.0, 1.0), "15 m: no halt, keep rolling")


# ---- A CPU crew under orders ---------------------------------------------------------

## The longest direct gun in the catalog (the Syndicate tank's railgun, 110 m) on a move_to past a parked enemy ~95 m
## off its line, firing at will: the CPU halts for its shots and still arrives.
func test_a_cpu_crew_halts_to_fire_at_long_range_and_still_arrives() -> void:
	RuleSwitches.spread_on = true
	var game_match := _setup()
	var crew := game_match.spawn_tank("Green_Rail_1", 0, Match.Team.GREEN, "syn_tank")
	crew.place(Vector3(-110.0, 0.0, 90.0), 0.0)
	var enemy := game_match.spawn_tank("Rust_Target_1", 0, Match.Team.RUST, "tank")
	enemy.place(Vector3(-15.0, 0.0, 40.0), 0.0)
	enemy.max_health = 100000
	enemy.health = 100000
	var orders := OrderController.new()
	orders.tank = crew
	orders.tanks_root = game_match.tanks
	orders.spotter = func(other: Tank) -> bool: return true  # the team sees it: this case is about the shot
	add_to_tree(orders)
	orders.set_orders({"type": "move_to", "x": -110.0, "z": -10.0}, {"type": "fire_at_will"})
	var shots: Array = []
	crew.fired.connect(func(_muzzle: Vector3, _forward: Vector3) -> void:
		shots.append([crew.global_position.distance_to(enemy.global_position), absf(crew.speed())]))
	for tick in SimClock.TICK_RATE * 25:
		await wait_physics_frames(1)
		if crew.global_position.distance_to(Vector3(-110.0, 0.0, -10.0)) < 4.0 and shots.size() >= 2:
			break
	assert_true(not shots.is_empty(), "it fired at the parked enemy")
	var long_shots := shots.filter(func(s: Array) -> bool: return float(s[0]) > 80.0)
	assert_true(not long_shots.is_empty(), "some of them beyond 80 m (%s)" % [shots])
	for s: Array in long_shots:
		assert_true(float(s[1]) < Tank.SHORT_HALT_STILL * crew.max_forward_speed,
				"a %.0f m round left a nearly still hull (%.1f m/s)" % [s[0], s[1]])
	assert_true(crew.global_position.distance_to(Vector3(-110.0, 0.0, -10.0)) < 8.0,
			"and the move still completes (%.1f m short)" % crew.global_position.distance_to(Vector3(-110.0, 0.0, -10.0)))


# ---- Ruling R37.2 (b): never under his plain MOVE ------------------------------------

## His plain move on the lab tank (Orders, source player), then the scripted drive with a 60 m shot held.
func test_a_crew_under_his_plain_move_never_halts_to_shoot() -> void:
	RuleSwitches.spread_on = true
	var game_match := _setup()
	var orders := Orders.new(game_match)
	Orders.attach(game_match, orders)
	var tank := game_match.spawn_tank("Green_Lab_1", 0, Match.Team.GREEN, "tank")
	tank.place(Vector3(-100.0, 0.0, 80.0), 0.0)
	await wait_physics_frames(2)
	assert_eq(orders.issue({"units": ["Green_Lab_1"], "verb": "move", "to": [-100.0, -80.0], "source": "player"},
			Match.Team.GREEN), "", "his move order is valid")
	assert_true(ShortHalt.plain_player_move(tank), "it reads as his plain move")
	var speeds: Array[float] = []
	tank.fired.connect(func(_muzzle: Vector3, _forward: Vector3) -> void: speeds.append(absf(tank.speed())))
	for tick in SimClock.TICK_RATE * 5:
		var aim := tank.global_position + Vector3(36.0, 0.0, -48.0)
		tank.command = TankCommand.new(1.0, 0.0, aim, tick >= SimClock.TICK_RATE * 2)
		await wait_physics_frames(1)
	assert_true(not speeds.is_empty() and float(speeds[0]) > 0.5 * tank.max_forward_speed,
			"he said drive: the 60 m round goes on the move, no halt (speeds %s)" % [speeds])


func test_attack_move_and_the_cpu_may_still_halt() -> void:
	var game_match := _setup()
	var orders := Orders.new(game_match)
	Orders.attach(game_match, orders)
	var mine := game_match.spawn_tank("Green_Lab_1", 0, Match.Team.GREEN, "tank")
	var cpu := game_match.spawn_tank("Rust_Lab_1", 0, Match.Team.RUST, "tank")
	await wait_physics_frames(1)
	assert_eq(orders.issue({"units": ["Green_Lab_1"], "verb": "attack_move", "to": [0.0, -80.0], "source": "player"},
			Match.Team.GREEN), "", "attack-move is valid")
	assert_true(not ShortHalt.plain_player_move(mine), "attack-move: a halt is allowed")
	ElementCommander.install(game_match, Match.Team.RUST)
	assert_eq(orders.issue({"units": ["Rust_Lab_1"], "verb": "move", "to": [0.0, 80.0]}, Match.Team.RUST), "",
			"a CPU move is valid")
	assert_true(not ShortHalt.plain_player_move(cpu), "a CPU-commanded team's crews may always halt")
	assert_eq(orders.issue({"units": ["Green_Lab_1"], "verb": "move", "to": [0.0, -80.0], "source": "element"},
			Match.Team.GREEN), "", "a squad leader's move is valid")
	assert_true(not ShortHalt.plain_player_move(mine), "a leader's order defers to the squad's task (none here: no plain move)")
