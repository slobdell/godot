extends TestCase
## Round 16: the fire RNG (shot spread, lobbed-round scatter) is seeded when the Match is made, so a mode that never
## calls seed_spawns() (the skirmish) fires the same rounds twice. Unseeded, the same `--skirmish --seed=3` forked at
## its first shot.

const MATCH := preload("res://game/match/match.tscn")


func test_two_matches_draw_the_same_spread_without_seed_spawns() -> void:
	var a: Match = add_to_tree(MATCH.instantiate())
	var b: Match = add_to_tree(MATCH.instantiate())
	var draws_a: Array = []
	var draws_b: Array = []
	for i in 8:
		draws_a.append(a._fire_rng.randfn(0.0, 1.0))
		draws_b.append(b._fire_rng.randfn(0.0, 1.0))
	assert_eq(draws_a, draws_b, "the same spread draws, match after match")


func test_seed_spawns_still_sets_the_fire_seed() -> void:
	var a: Match = add_to_tree(MATCH.instantiate())
	a.seed_spawns(3, 0.0)
	assert_eq(a._fire_rng.seed, 3 + 7919, "the match runner's seed wins, as before")
