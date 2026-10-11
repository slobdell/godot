extends TestCase
## Round 26 (brains, the orchestrator's finding): `make nav-orders` printed the same numbers at seeds 1, 2 and 3, because
## `--seed` reached only random streams nothing drew from (no spawn jitter, nobody firing): every "series over seeds"
## was n = 1. The probe's setup now jitters the spawns when a seed is given. These tests lay the probe's own squads with
## its own seeding (and its post-deploy nudge: ArmyLayout.deploy re-lays a doctrine army whatever the spawn jitter) and
## compare where they stand: two seeds must be two different starts, the same seed the same start,
## and no `--seed` the historical start (no jitter).

const PROBE := preload("res://tests/nav/order_probe.gd")
const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _spawned(args: PackedStringArray) -> String:
	var arena := ARENA.instantiate() as Arena
	arena.layout_name = "yard"
	add_to_tree(arena)
	var game_match := MATCH.instantiate() as Match
	add_to_tree(game_match)
	var seed_value: int = PROBE.seed_match(game_match, args)
	var squads: Array = []
	for s in PROBE.TARGETS.size():
		squads.append({"name": "S%d" % s, "units": PROBE.ROSTER.map(func(unit: String) -> Dictionary: return {"unit": unit})})
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "NavOrders", "squads": squads}), "", "setup")
	var tanks: Array = game_match.tanks.get_children()
	PROBE.nudge(tanks, seed_value)
	var digest := PROBE.spawn_digest(tanks)
	return digest


func test_two_seeds_are_two_different_starts() -> void:
	var one := _spawned(PackedStringArray(["--seed=1"]))
	var two := _spawned(PackedStringArray(["--seed=2"]))
	assert_true(one != two, "seed 1 and seed 2 lay the squads differently (%s vs %s)" % [one, two])
	assert_eq(_spawned(PackedStringArray(["--seed=2"])), two, "the same seed lays them the same way")


func test_a_seed_also_shifts_the_order_tick() -> void:
	assert_eq(PROBE.extra_ticks(0), 0, "no seed: the orders go at the historical tick")
	var ticks := {}
	for seed_value in [1, 2, 3, 4]:
		ticks[PROBE.extra_ticks(seed_value)] = true
	assert_eq(ticks.size(), 4, "seeds 1-4 issue their orders on four different ticks (%s)" % [ticks.keys()])


func test_no_seed_is_the_historical_start() -> void:
	var plain := _spawned(PackedStringArray())
	var seeded := _spawned(PackedStringArray(["--seed=1"]))
	assert_true(plain != seeded, "without --seed nobody is nudged (the run every recorded number came from): %s vs %s"
			% [plain, seeded])
	assert_eq(_spawned(PackedStringArray()), plain, "and it is the same start every time")
