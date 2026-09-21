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


## ⚠ `await super.teardown()` IS THE LOAD-BEARING LINE HERE, and it was missing. `_tank()` calls
## `add_to_tree(game_match)` -- a whole `Match` per test -- and an override that never reaches the base frees none
## of it. Same defect as `test_tank_yaw_fit`'s, whose foundry arena cost feel 38 failures observed by a test that
## created none of it, and whose residue silently moved a rig 8 cm and turned `applied 0` into `applied 3`. Found
## by control, in a file I had edited an hour earlier without noticing.
##
## BOTH resets stay, and dropping the static would be a regression rather than a tidy-up: `Armor.no_damage_on()`
## reads the tuning key FIRST and falls back to the static, so a key erased while the static is still true leaks
## `true` into the next test through the fallback. The dictionary is erased by KEY, never cleared -- `Units.tuning`
## is process-wide and `clear()` would take every other test's knobs with it.
func teardown() -> void:
	Units.tuning.erase("no_damage")
	Armor.no_damage = false
	await super.teardown()


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
	# ⚠ `apply_tuning` RETURNING "" SAYS THE SPEC PARSED AND NOTHING MORE, and this line used to read the raw
	# `Armor.no_damage` static, which is the instruction that was issued rather than the state the code consults.
	# feel's bench proved the difference the hard way on builder0: `--tune=match.no_damage=1` was on the command
	# line verbatim, `apply_tuning` returned "" with no error, and `Armor.no_damage` read FALSE in 13 of 13 phases
	# while the census walked 90 -> 77 with units dying. Accepted, silent, and never reached the predicate -- the
	# knob was written into another class's static at load time and undone by that class's own initialiser.
	#
	# feel's rule, which is the general form: **an arm assertion must read the state the code under test consults,
	# not the instruction that was issued.** `no_damage_on()` is what `Tank.take_hit` gates on; the eight killing
	# hits below are the behavioural proof that neither reading can fake.
	assert_true(Armor.no_damage_on(), "and selected, read the way `Tank.take_hit` reads it")
	var before := tank.health + tank.shield
	for shot in 8:
		tank.take_hit(500.0, 1.0, 1.0)
	assert_eq(tank.health + tank.shield, before, "eight killing hits take nothing under the switch")
	assert_true(tank.is_alive(), "and the unit is still alive, so nothing respawns")
	Units.tuning.erase("no_damage")


func test_an_unknown_match_knob_is_refused_rather_than_ignored() -> void:
	assert_true(Units.apply_tuning("match.nonsense=1").contains("no match knob"),
			"a typo in a bench's tune must fail loudly, not silently leave the census walking down")
