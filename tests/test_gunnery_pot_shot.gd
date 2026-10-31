extends TestCase
## Round 47 (engage E3, R47.17 / R47.37): POT SHOTS behind `--pot-shot` (default ON since his "Ship it ON"; `=off` is today's). A crew whose only held gate is the
## acquisition fix, laid at least POT_SHOT_AFTER_S, its target inside the band, snaps a round off with its aim off by what
## is left of the fix. Staged in the open: a gun on standing orders (fire at will) and a still target 30 m off (inside the band), on
## whichever execute path the build runs (native's NativeGun / NativeExec twin carries the pot shot, pair/native-e3).

const SHOOTER_AT := Vector3(-100.0, 0.0, 40.0)
const TARGET_AT := Vector3(-100.0, 0.0, 10.0)  # 30 m: inside the scrap cannon's 36 m band

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func teardown() -> void:
	Gunnery.POT_SHOT = Gunnery.POT_SHOT_DEFAULT
	super.teardown()


## The tick (from the start) of the shooter's first round, or -1 within `seconds`.
func _first_shot(pot: bool, seconds := 4.0) -> int:
	Gunnery.POT_SHOT = pot
	var lab := TacticsLab.create(self, 7, "")
	var shooter := lab.gun(Match.Team.GREEN, "Green_Rig", SHOOTER_AT, 0.0, "gang_tank")  # facing -z, at the target
	var target := lab.gun(Match.Team.RUST, "Rust_T", TARGET_AT, PI, "syn_ifv")
	await lab.start()
	(lab.game_match.brains.get_node("Orders_Rust_T") as OrderController).set_orders({"type": "stop"}, {"type": "hold_fire"})
	assert_true(Perception.has_line_of_sight(shooter, target), "the stage: an open line")
	var shots: Array = []
	shooter.fired.connect(func(_m: Vector3, _d: Vector3) -> void: shots.append(lab.game_match.tick))
	var start := lab.game_match.tick
	for i in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		if not shots.is_empty():
			break
	lab.dispose()
	return int(shots[0]) - start if not shots.is_empty() else -1


func test_a_pot_shot_goes_before_the_fix_completes() -> void:
	var off: int = await _first_shot(false)
	var on: int = await _first_shot(true)
	print("POT_SHOT first round: off %d ticks, on %d ticks" % [off, on])
	assert_true(off > 0, "the stage: today's crew fires inside the window (%d)" % off)
	assert_true(on > 0 and on < off, "on: the snap shot goes before today's (%d v %d ticks)" % [on, off])
	assert_true(on >= int(Gunnery.POT_SHOT_AFTER_S * SimClock.TICK_RATE), "never before POT_SHOT_AFTER_S of lay (%d ticks)" % on)


## The check's own find (d4cf542c7, test_rules_spread): a halting railgun crew's pot shot dropped its trigger for a tick, the
## plant took that as the shot gone and cancelled the halt, and the next pot shot left at 99 m on a hull doing 11 m/s. A pot
## shot never goes where R2's short halt would stop the hull for the round; close in, or still, or under his plain move it may.
func test_a_pot_shot_waits_where_the_short_halt_would_stop() -> void:
	var arena := add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.set_meta("arena", arena)
	var crew := game_match.spawn_tank("Green_Rail_1", 0, Match.Team.GREEN, "syn_tank")
	crew.place(Vector3(-110.0, 0.0, 90.0), 0.0)
	var far := Vector3(-110.0, 0.0, -9.0)  # 99 m
	var near := Vector3(-110.0, 0.0, 70.0)  # 20 m: inside SHORT_HALT_MIN_RANGE of the band
	crew._speed = 0.8 * crew.max_forward_speed
	assert_true(Gunnery.pot_shot_halts(crew, far), "rolling, 99 m: the halt's round, no pot shot")
	assert_true(not Gunnery.pot_shot_halts(crew, near), "rolling, 20 m: close in a crew rolls and shoots")
	crew._speed = 0.0
	assert_true(not Gunnery.pot_shot_halts(crew, far), "still, 99 m: nothing to halt for")
