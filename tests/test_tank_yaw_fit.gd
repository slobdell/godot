extends TestCase
## Round 9: a hull may only rotate through space it fits in.
##
## `Tank._drive` assigns `global_basis` directly and `move_and_slide` resolves TRANSLATION ONLY, so before this the
## yaw was never offered to the physics at all: a hull pinned against geometry kept turning straight through it. nav
## measured a 14 m `gang_tank` in a 4.8 m corridor turning 44 deg while still 4.4 m off centre -- a hull that long
## needs 12.1 m of lateral room for that. It is the lead's round-8 complaint exactly ("the semi trucks are yawing in
## place, should be impossible, they're not a tracker vehicle"), because a partially pinned wheeled hull that yaws
## freely looks like a tracked pivot.
##
## The two things that must BOTH hold, and the second is why the first is not enough on its own: a hull against a wall
## must not turn through it, and a hull in the open must turn exactly as it always did. A constraint that quietly
## refuses everything would pass the first test and ruin the game.

const MATCH := preload("res://game/match/match.tscn")
const ARENA := preload("res://game/arena/arena.tscn")


## The counters are static and accumulate for the life of the process, so a test that reads them raw is reading every
## test before it. Snapshot and subtract -- this is how the wall case caught itself proving nothing.
var _offered_at := 0
var _applied_at := 0


func _mark() -> void:
	_offered_at = Tank.refusals_offered
	_applied_at = Tank.refusals_applied


func _offered() -> int:
	return Tank.refusals_offered - _offered_at


func _applied() -> int:
	return Tank.refusals_applied - _applied_at


## The constraint is ON by default as of the enable commit (`Tank.yaw_fit_enabled`, `--tune=match.yaw_fit=0` turns it
## off). These tests still select it EXPLICITLY rather than leaning on the default: a test that measured whichever way
## the default happened to point would be testing the thing it was written to compare against and saying nothing
## about it (lesson 156), and the default has already flipped once this round.
var _was_fitting := false


func _enable() -> void:
	_was_fitting = Tank.yaw_fit_enabled
	Tank.yaw_fit_enabled = true


## RESTORED, not zeroed: `yaw_fit_enabled` is a static, so a teardown that wrote `false` would hand the OLD default to
## every test that ran after this file in the shard -- the leak-into-the-next-test shape that cost this round two
## shards. It goes back to whatever it was.
func teardown() -> void:
	Tank.yaw_fit_enabled = _was_fitting


func _world() -> Match:
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = "foundry"
	add_to_tree(arena)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	await wait_physics_frames(2)
	return game_match


## A hull in open ground turns freely: the constraint must cost nothing where there is nothing to hit.
func test_a_hull_in_the_open_turns_exactly_as_it_did() -> void:
	var game_match := await _world()
	var tank := game_match.spawn_tank("Green_Open_1", 0, Match.Team.GREEN, "tank")
	tank.global_position = Vector3(0, 0, 40)  # open lane, nothing within a hull length
	await wait_physics_frames(2)
	_enable()
	_mark()
	var before := -tank.global_basis.z
	tank.command.throttle = 0.2
	tank.command.turn = 1.0
	await wait_physics_frames(SimClock.TICK_RATE)
	var turned := rad_to_deg(Vector3(before.x, 0, before.z).normalized().angle_to(
			Vector3(-tank.global_basis.z.x, 0, -tank.global_basis.z.z).normalized()))
	print("MEASURE yaw_fit_open turned %.1f deg in 1 s, refusals offered %d applied %d" % [
			turned, _offered(), _applied()])
	assert_true(turned > 20.0, "a hull with room turns (%.1f deg in a second)" % turned)
	assert_eq(tank.yaw_refused_ticks, 0, "and is never refused outright")


## The defect itself: a hull wedged against a wall must not rotate through it.
##
## THE FIRST VERSION OF THIS TEST PROVED NOTHING and said so only because the counters were visible: the rig never
## made contact, so `_fitting_forward` never ran, and "it does not end up inside the crate" passed because the rig had
## barely moved. A test of a constraint has to show the constraint ENGAGED (lesson 147), so it asserts that first.
func test_a_hull_against_a_wall_cannot_turn_through_it() -> void:
	var game_match := await _world()
	var tank := game_match.spawn_tank("Green_Wall_1", 0, Match.Team.GREEN, "gang_tank")  # the 14 m rig
	# Foundry's centre crate blocks the line (-5,1.3,0) -> (5,1.3,0). Drive the rig into it, broadside on, so the
	# slide reports contact, and only then ask for the turn that would sweep through it.
	tank.global_position = Vector3(0, 0, 14.0)
	tank.global_basis = Basis.looking_at(Vector3(0, 0, -1), Vector3.UP)
	await wait_physics_frames(2)
	tank.command.throttle = 1.0
	tank.command.turn = 0.0
	await wait_physics_frames(SimClock.TICK_RATE * 2)  # close and wedge
	_enable()
	_mark()
	var before := -tank.global_basis.z
	tank.command.throttle = 0.1
	tank.command.turn = 1.0
	await wait_physics_frames(SimClock.TICK_RATE)
	var swept := rad_to_deg(Vector3(before.x, 0, before.z).normalized().angle_to(
			Vector3(-tank.global_basis.z.x, 0, -tank.global_basis.z.z).normalized()))
	print("MEASURE yaw_fit_wall 14 m rig at %s swept %.1f deg; offered %d applied %d, refused ticks %d, contacts %d" % [
			tank.global_position, swept, _offered(), _applied(), tank.yaw_refused_ticks,
			tank.get_slide_collision_count()])
	assert_true(_offered() > 0, "setup: the rig is in contact, so the yaw constraint actually ran (%d offers)" % _offered())
	# Not "it never turns": it may turn as far as it fits. What it may not do is pass through.
	assert_true(not _overlaps(tank), "the rig does not end a turn inside the crate")


## True when the hull is overlapping world geometry where it stands. NOT named `test_*`: the runner collects every
## method with that prefix and would call this one with no argument.
func _overlaps(tank: Tank) -> bool:
	return tank.test_move(tank.global_transform, Vector3.ZERO, null, 0.001, true)
