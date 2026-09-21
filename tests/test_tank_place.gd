extends TestCase
## Round 9: **a teleported hull is driven against the world it left.**
##
## `ArmyLayout.deploy` wrote `global_position` and called `reset_physics_interpolation()`. That fixes what is DRAWN
## and says nothing about what is THERE. `PhysicsServer3D` commands queue until the step and `_physics_process` runs
## before the step applies them, so on the first tick after a teleport the solver resolves the PREVIOUS world.
##
## Measured on a full 90-unit army before the fix: **every one of the 90 hulls was 56-110 m from its own physics
## body**, each body still at `Match.spawn_position`'s jittered grid slot. The grid is itself a valid
## non-overlapping layout, so almost nothing overlapped in it and nothing looked wrong -- which is exactly why this
## survived since round 1. The two hulls that did overlap in that other layout were shoved **1.5 m** by
## `move_and_slide`'s penetration recovery, which moves a body **without touching `velocity`** and reports **no
## slide collision**. The row that started the hunt:
##
##     wanted=(0.000, 0.200) -> would move (0.0000, 0.0067) | moved=(1.5281, 0.0067) | contacts[0]
##
## No velocity to blame and no contact to point at, which is why three rounds of measurement blamed the spawner's
## spacing, then the motion model's lateral term, then the hull geometry. All three were innocent.
##
## THE REMEDY IS A TICK, NOT A FLUSH, and that is what the first test here pins. Three flushes were tried and all
## three were bit-identical: `force_update_transform()` at `_ready`, the same after deploy's write, and an explicit
## `PhysicsServer3D.body_set_state`. `Tank.place` therefore makes the hull skip its next drive instead.

const MATCH := preload("res://game/match/match.tscn")
const ARENA := preload("res://game/arena/arena.tscn")

## A hull is allowed to move by what its own velocity earns it in one tick. At the speeds a just-deployed army is
## doing (0.2-0.8 m/s) that is under 0.03 m; the shove was 1.5 m. A tenth of a metre sits two orders below the
## defect and an order above the legitimate motion, so it cannot be met by luck in either direction.
const FIRST_TICK_BUDGET_M := 0.1


func _army() -> Dictionary:
	var roster := ["tank", "ifv", "scout", "artillery", "lancer"]
	var army := {"name": "Full", "squads": []}
	var bought := 0
	for s in ceili(float(Army.MAX_ARMY_UNITS) / Doctrine.MAX_SQUAD_UNITS):
		var units: Array = []
		for u in Doctrine.MAX_SQUAD_UNITS:
			if bought >= Army.MAX_ARMY_UNITS:
				break
			units.append({"unit": roster[(s + u) % roster.size()]})
			bought += 1
		army["squads"].append({"name": "S%d" % s, "formation": "wedge", "verb": "hold", "units": units})
	return army


## THE DEFECT ITSELF, asserted against the ENGINE rather than against a symptom -- and it is a positive control for
## everything below. If this ever goes green the other way (the space holding the new transform immediately), then
## Godot's command queue has changed, `_placed_settle` is no longer earning its keep, and it should be REMOVED
## rather than left in as a superstition. That is the assertion's purpose: the settle tick is not free and this is
## the evidence that it is still needed.
func test_a_write_to_a_hulls_transform_is_not_in_the_physics_space_yet() -> void:
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Mover", 0, Match.Team.GREEN, "tank")
	tank.global_position = Vector3(-100, 0, 40)
	await wait_physics_frames(2)  # let the spawn settle, so the ONLY pending write is the one below
	var far := Vector3(-40, 0, 40)
	tank.place(far, 0.0)
	var held: Transform3D = PhysicsServer3D.body_get_state(tank.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	var lag := Vector2(held.origin.x - far.x, held.origin.z - far.z).length()
	print("MEASURE place: node moved 60 m; the physics space still holds a body %.2f m from it" % lag)
	assert_near(tank.global_position.x, far.x, 0.001, "the NODE is where it was placed")
	assert_true(lag > 1.0,
			"and the SPACE is not: the body is still %.2f m away, so a drive this tick resolves the old world" % lag)
	# ...and one physics step later it agrees, which is what the settle tick waits for and why one tick is enough.
	await wait_physics_frames(1)
	var after: Transform3D = PhysicsServer3D.body_get_state(tank.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	assert_near(Vector2(after.origin.x - far.x, after.origin.z - far.z).length(), 0.0, 0.1,
			"one step later the space has it, so the hull skips ONE drive and not a settling period")


## THE SYMPTOM, on the real path that produced it: a full army, deployed, one physics frame. Without the settle tick
## this reads 1.53 m. It is deliberately the WEAKER of the two assertions and it is here because it is the one a
## reader believes -- but on its own it would go green the day someone widened the spawn spacing and left the
## desync in place, which is why the engine assertion above exists.
func test_no_hull_moves_more_than_its_velocity_earns_on_the_tick_it_is_deployed() -> void:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(9, 6.0)
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		assert_eq(game_match.load_doctrine(team, _army()), "", "a full army loads for team %d" % team)
	var tanks: Array = game_match.tanks_by_name().values()
	assert_true(tanks.size() > 50, "a full army deployed (%d hulls)" % tanks.size())
	var placed := {}
	for tank: Tank in tanks:
		placed[tank] = tank.global_position
	await wait_physics_frames(1)
	var worst := 0.0
	var who := ""
	for tank: Tank in tanks:
		var at: Vector3 = placed[tank]
		var moved := Vector2(tank.global_position.x - at.x, tank.global_position.z - at.z).length()
		if moved > worst:
			worst = moved
			who = String(tank.name)
	print("MEASURE place_army %d hulls deployed; worst first-tick movement %.4f m (%s), budget %.2f m" % [
			tanks.size(), worst, who if who != "" else "nothing moved at all", FIRST_TICK_BUDGET_M])
	assert_true(worst <= FIRST_TICK_BUDGET_M,
			"no hull is shoved on the tick it is deployed (worst %.4f m, %s; it was 1.53 m before the settle tick)"
			% [worst, who])
	# THE POSITIVE CONTROL, and it is not optional: `worst` came back at EXACTLY 0.0000 for all 90 hulls, which is
	# what a working settle tick looks like AND what a permanently broken drive looks like. The settle tick costs
	# ONE tick; if it ever costs more -- an uncleared flag, a `_motion` that never rebuilds -- this assertion is the
	# only thing between that and a silent army of statues. Three more frames, then somebody must be moving.
	for frame in 3:
		await wait_physics_frames(1)
	var driving := 0.0
	for tank: Tank in tanks:
		driving = maxf(driving, Vector2(tank.global_position.x - (placed[tank] as Vector3).x,
				tank.global_position.z - (placed[tank] as Vector3).z).length())
	print("MEASURE place_army after 3 more ticks the furthest hull has driven %.4f m" % driving)
	assert_true(driving > 0.01,
			"the army DRIVES on the ticks after the settle (furthest %.4f m), so the zero above is a hull that was "
			% driving + "not shoved and not a hull that cannot move")


## A RESPAWN IS THE SAME CLASS OF EVENT -- a placement followed by a drive in the same frame -- and it is asserted
## separately rather than argued from the deploy case, because "it is the same shape" is how the lateral term got
## blamed for something it had no part in. `respawn()` calls `place()`, so this is a test that it still does.
func test_a_respawned_hull_is_not_shoved_on_its_first_tick_either() -> void:
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Riser", 0, Match.Team.GREEN, "tank")
	var blocker := game_match.spawn_tank("Blocker", 0, Match.Team.GREEN, "gang_tank")
	tank.global_position = Vector3(-100, 0, 40)
	blocker.global_position = Vector3(-60, 0, 40)
	await wait_physics_frames(2)
	# Respawn it ONTO ground it is not currently near, with a 14 m hull parked close enough that the OLD world and
	# the new one disagree about what is around it -- which is the condition the deploy case hit by accident.
	var at := Vector3(-66.0, 0, 40)
	tank.respawn(at, 0.0)
	await wait_physics_frames(1)
	var moved := Vector2(tank.global_position.x - at.x, tank.global_position.z - at.z).length()
	print("MEASURE place_respawn respawned at %s; moved %.4f m on its first tick" % [at, moved])
	assert_true(moved <= FIRST_TICK_BUDGET_M,
			"a respawned hull is not shoved on its first tick either (%.4f m)" % moved)
	assert_true(tank.alive, "and it is alive, so `respawn` still does its own job through `place`")


## THE LANDMINE `place()` RETIRES, and it is a separate assertion because it is a separate bug that happened to live
## in the same three lines: `sync_position` was written only by `_tick`, so between a deploy and the first tick a
## replicated hull advertised the position it was SPAWNED at -- scale measured one at x -54.3 advertising +36.2.
## Harmless while `simulate` is true and catastrophic the day it is not, which is the worst kind of latent bug.
func test_a_placed_hull_advertises_where_it_is_before_its_first_tick() -> void:
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Talker", 0, Match.Team.GREEN, "tank")
	tank.global_position = Vector3(-100, 0, 40)
	await wait_physics_frames(2)
	var at := Vector3(-30.0, 0.0, 12.0)
	tank.place(at, PI / 2.0)
	# Read BEFORE any physics frame: that gap is precisely where the landmine sat.
	print("MEASURE place_sync placed at %s; advertises %s" % [at, tank.sync_position])
	assert_near(tank.sync_position.distance_to(at), 0.0, 0.001,
			"the replicated position is the placed one before a single tick has run (%s)" % tank.sync_position)
	assert_near(tank.sync_yaw, PI / 2.0, 0.001, "and so is the yaw")


## `place()` writes `at.y` WHOLE. The line it replaced read `Vector3(spot.x, tank.global_position.y, spot.z)`, which
## kept the tank's own y and threw the layout's away -- that is what made `SPAWN_LIFT_M` inert and produced a
## byte-identical A/B that was reported as evidence about the lift and was evidence about nothing. Both versions
## agree at y = 0.0, so the regression is SILENT: it measures as "the lift does nothing" rather than as a failure.
## Asserted at a non-zero y precisely because the default cannot tell the two apart.
func test_the_placed_y_is_the_one_asked_for_and_not_the_hulls_own() -> void:
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Lifter", 0, Match.Team.GREEN, "tank")
	tank.global_position = Vector3(-100, 3.5, 40)  # a y nothing else would produce, so a keep-the-old-y is visible
	await wait_physics_frames(2)
	tank.place(Vector3(-90.0, 0.75, 40.0), 0.0)
	print("MEASURE place_y asked for y=0.75 from a hull sitting at y=%.2f; placed at y=%.3f" % [
			3.5, tank.global_position.y])
	assert_near(tank.global_position.y, 0.75, 0.001,
			"the LAYOUT's y is used, not the hull's own (%.3f)" % tank.global_position.y)
