extends TestCase
## `--tune=match.no_damage=1`: nothing takes damage, nothing dies, nothing respawns.
##
## For timing benches that sample a LIVE battle. feel's hinge bench and show's layer bench compare per-cycle deltas,
## and the vehicle census walks down as units die (90 -> 77 in six cycles measured), so every delta disagreed in sign
## -- the benches were measuring attrition rather than the thing under test. Freezing the census is a change to the
## simulation, so the switch is combat's and not art's.
##
## `Tank.take_hit` is the single seam every source of damage passes through -- direct fire, splash and arena hazards
## -- so one guard covers all of them, and this asserts that rather than assuming it.

const MATCH := preload("res://game/match/match.tscn")


func teardown() -> void:
	Armor.no_damage = false


func _tank() -> Tank:
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	await wait_physics_frames(1)
	return game_match.spawn_tank("Green_Bench_1", 0, Match.Team.GREEN, "tank")


## The arm has to be distinguishable or the bench is measuring its own build twice (lesson 117): the SAME hit must
## take health off with the switch off, and take none with it on.
func test_a_hit_takes_health_normally_and_none_under_the_switch() -> void:
	var tank := await _tank()
	var full := tank.health
	tank.take_hit(120.0, 1.0, 1.0)
	var hurt := tank.health + tank.shield
	assert_true(hurt < full + tank.max_shield, "setup: the hit lands normally (%d)" % hurt)

	assert_eq(Units.apply_tuning("match.no_damage=1"), "", "the switch is selectable")
	assert_true(Armor.no_damage, "and selected")
	var before := tank.health + tank.shield
	for shot in 8:
		tank.take_hit(500.0, 1.0, 1.0)
	assert_eq(tank.health + tank.shield, before, "eight killing hits take nothing under the switch")
	assert_true(tank.is_alive(), "and the unit is still alive, so nothing respawns")
	Units.tuning.clear()
	Armor.no_damage = false


func test_an_unknown_match_knob_is_refused_rather_than_ignored() -> void:
	assert_true(Units.apply_tuning("match.nonsense=1").contains("no match knob"),
			"a typo in a bench's tune must fail loudly, not silently leave the census walking down")
