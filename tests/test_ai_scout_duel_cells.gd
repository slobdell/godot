extends TestCase
## Brains B1 (C34.5, scout try 2): the DUELS A SCOUT CAN WIN, on manoeuvre's orbit stage (tests/test_manoeuvre_orbit.gd,
## `_orbit_stage`, driven from here unchanged). The stage's own cells pit the scouts against syn_scout and gang_ifv, which
## outgun them at every orbit (tuning, lab/brains-scout2, seed 50, laptop: advantage >= 1 on 207 of 5320 rule ticks and
## none in reach), so they judge only the "leaves" side. These cells are mirror and cross scout duels: law_scout and
## gang_scout circled by law_scout or gang_scout, at 15 and 24 m (inside both scouts' reach) and 35 m, post and free,
## turn-in OFF (main). Run only when SCOUT_DUEL_CELLS names the seeds ("73-79"); the stage exists only on a tree that
## carries it (lab/brains-scout2), so elsewhere the test is a no-op.
## `SCOUT_DUEL_CELLS=50-50 godot --headless --fixed-fps 30 --script res://tests/run_tests.gd -- --filter=scout_duel_cells`

const STAGE := "res://tests/test_manoeuvre_orbit.gd"


func test_scout_duel_cells() -> void:
	var spec := OS.get_environment("SCOUT_DUEL_CELLS")
	if spec == "" or not ResourceLoader.exists(STAGE):
		assert_true(true, "cells run on request only, on a tree with the orbit stage")
		return
	var stage: Variant = load(STAGE).new()
	stage.tree = tree
	var ends := spec.split("-")
	var was_native := BrainSwitches.native
	BrainSwitches.native = false  # as the stage's own cells: both arms on the GDScript path
	for seed_value in range(int(ends[0]), int(ends[-1]) + 1):
		for subject: String in ["law_scout", "gang_scout"]:
			for enemy_unit: String in ["law_scout", "gang_scout"]:
				for radius: float in [15.0, 24.0, 35.0]:
					for player: bool in [true, false]:
						var r: Dictionary = await stage._orbit_stage(enemy_unit, 30.0, radius, player, seed_value, false, subject, false)
						r.erase("kturn")
						print("C339_CELL ", JSON.stringify(r))
	BrainSwitches.native = was_native
	stage.teardown()
	assert_true(true, "cells printed")
