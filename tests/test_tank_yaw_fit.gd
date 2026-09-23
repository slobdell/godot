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
## ⚠ THE ARM IS SELECTED THROUGH THE TUNING KEY, not by writing `Tank.yaw_fit_enabled`, so that the thing this
## test flips is the thing production reads. Writing the static is a second source of truth: it worked while the
## static WAS the source, and the moment a `--tune=` or `TUNE=` value existed the tune outranked it -- measured,
## `TUNE=match.yaw_fit=0 make test FILTER=tank_yaw_fit` came back `1 passed, 1 failed` with `offered 0 applied 0`,
## which is correct precedence and a broken test.
func _enable() -> void:
	Units.tuning["yaw_fit"] = 1.0


## RESTORED, not zeroed: `yaw_fit_enabled` is a static, so a teardown that wrote `false` would hand the OLD default to
## every test that ran after this file in the shard -- the leak-into-the-next-test shape that cost this round two
## shards. It goes back to whatever it was.
##
## ⚠ AND IT `await`s ITS SUPER, which the first version of this override did not call AT ALL. That is not a style
## point: `TestCase.teardown()` is what frees `_owned_nodes` and drains the navigation map, so an override that
## replaces it silently leaks everything the test built. This file builds a FOUNDRY arena and a match, and on
## `396be191`'s check it ran immediately before `test_theme_city_block`, which was then charged with **44 physics
## bodies and 4 navigation regions it never created** and became the head of a 47-test cascade. The guard names the
## first OBSERVER of a residue, not its author; this file was the author.
##
## `await super.teardown()`, not `super.teardown()`: the super ends in `await drain_navigation()`, so an override
## declared `-> void` that does not await it returns to the runner immediately and detaches the drain -- the same
## defect, one step less obvious, and it is in four other files in this suite.
##
## FOLLOW-UP, named so it is not left as a permanent oddity: nav's sealed teardown (`c3df6d4a`, on main as `14c14f0b`) seals this -- the runner awaits a
## `_teardown()` that owns the free, the guards and the drain, and `teardown()` becomes a synchronous hook that
## must NEVER call its super. When that is on main, the `await super.teardown()` line below is deleted and this
## override goes back to restoring `_was_fitting` and nothing else. The same deletion is owed in control's four
## files and squad's one.
func teardown() -> void:
	Units.tuning.erase("yaw_fit")
	Units.tuning.erase("yaw_world")
	Units.tuning.erase("yaw_slide")
	await super.teardown()


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


## ROUND 10, backlog item 1's mechanism as a test: the five_squads freeze in two hulls. A tracked 8.62 m `tank` (half
## diagonal 4.48 m) beside a squadmate at five_squads' 6 m pitch is told to pivot in place about -- throttle 0, turn
## -1, exactly the command `YAW_TRACE` caught the freezers holding for ~1200 ticks, between two squadmates. Returns [longest run of refused
## ticks, degrees swept] over three seconds.
func _pivot_beside_a_squadmate(world_only: bool) -> Array:
	var game_match := await _world()
	var pivot := game_match.spawn_tank("Green_Pivot_1", 0, Match.Team.GREEN, "tank")
	pivot.global_position = Vector3(0, 0, 40)
	pivot.rotation.y = PI
	# Boxed in on both sides, 0.8 m of air each side (2.40 m hulls at a 3.2 m pitch): one end of a pivoting hull swings
	# toward each neighbour, so whichever way it turns it meets one. At five_squads' 6 m pitch a hull turning under
	# throttle drives clear before it touches, and the control would measure nothing.
	for side in [-1, 1]:
		var mate := game_match.spawn_tank("Green_Pivot_%d" % (2 if side < 0 else 3), 1 if side < 0 else 2,
				Match.Team.GREEN, "tank")
		mate.global_position = Vector3(3.2 * side, 0, 40)
		mate.rotation.y = PI
	await wait_physics_frames(2)
	_enable()
	Units.tuning["yaw_world"] = 1.0 if world_only else 0.0
	_mark()
	var before := -pivot.global_basis.z
	var longest := 0
	for tick in SimClock.TICK_RATE * 3:
		# The freezers' own history (`YAW_TRACE`): a few ticks of turning under throttle first, which puts the hull's
		# corner onto its neighbour and gives the slide a contact to report -- the constraint only arms on one -- and
		# then the pure pivot they held for ~1200 ticks. A pivot from rest never reports a contact and is never checked.
		pivot.command.throttle = 0.3 if tick < 6 else 0.0
		pivot.command.turn = -1.0
		await wait_physics_frames(1)
		longest = maxi(longest, pivot.yaw_refused_ticks)
	var swept := rad_to_deg(Vector3(before.x, 0, before.z).normalized().angle_to(
			Vector3(-pivot.global_basis.z.x, 0, -pivot.global_basis.z.z).normalized()))
	print("MEASURE yaw_fit_squadmate world_only=%s swept %.1f deg in 3 s, longest refused run %d ticks, offered %d applied %d" % [
			world_only, swept, longest, _offered(), _applied()])
	return [longest, swept]


## The positive control: with vehicles counted as walls the pivot ratchets into the fixed point and stays there. If
## this ever passes as "not frozen", the test below has stopped measuring anything.
func test_a_squadmate_counted_as_a_wall_freezes_a_pivot() -> void:
	var got := await _pivot_beside_a_squadmate(false)
	assert_true(int(got[0]) > 3, "vehicles in the yaw mask: the pivot freezes against its squadmate (longest refused run %d ticks, swept %.1f deg)" % [got[0], got[1]])


## The fix the mechanism implies: a squadmate yields (the slide depenetrates the pair), a wall does not, so only the
## world may refuse a yaw. CP4's fourth bar (research B2): no run of more than 3 consecutive refused ticks.
func test_a_squadmate_does_not_freeze_a_pivot_under_the_world_mask() -> void:
	var got := await _pivot_beside_a_squadmate(true)
	assert_true(int(got[0]) <= 3, "world-only mask: no refused run over 3 ticks (longest %d)" % got[0])
	assert_true(float(got[1]) > 90.0, "and the hull actually turns about (%.1f deg in 3 s)" % got[1])


## The world-only mask must keep what the constraint is FOR: the rig against the crate still cannot turn through it.
func test_the_world_mask_still_stops_a_turn_through_a_wall() -> void:
	Units.tuning["yaw_world"] = 1.0
	await test_a_hull_against_a_wall_cannot_turn_through_it()


## ROUND 10, CP4's fourth bar: a bus side-flush against one wall, told to pivot toward it (the five_squads freezers
## at Crate_7 / Crate_17 / Wall_16 were each flush against ONE world collider wanting a ~2 deg trim). Returns
## [longest refused run, degrees swept, slide-offs, ends inside the crate].
func _pivot_against_one_wall(slide: bool) -> Array:
	var game_match := await _world()
	# A wall of our own, in open ground (foundry's centre crate did not reproduce it: a bus nosed into it pivoted
	# freely, sliding along the crate's face). 30 m long, on the world layer, its face at x = 40.0.
	var wall := StaticBody3D.new()
	wall.collision_layer = Perception.WORLD_MASK
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 4.0, 30.0)
	shape.shape = box
	wall.add_child(shape)
	add_to_tree(wall)
	wall.global_position = Vector3(40.5, 2.0, 40.0)
	var tank := game_match.spawn_tank("Green_Flush_1", 0, Match.Team.GREEN, "tank")
	# Parallel to the wall, its right side 1 cm off the face; driven sideways-in by a nudge toward it below.
	var half_width := float((Units.stat("tank", "hull_size") as Array)[0]) / 2.0
	tank.place(Vector3(40.0 - half_width - 0.01, 0.0, 40.0), 0.0)
	await wait_physics_frames(3)
	# A few ticks turning INTO the wall under throttle (the freezers' own history: they arrived touching), which gives
	# the slide the contact and the hull the flush pose.
	for tick in 8:
		tank.command.throttle = 0.4
		tank.command.turn = -1.0
		await wait_physics_frames(1)
	_enable()
	Units.tuning["yaw_world"] = 1.0
	Units.tuning["yaw_slide"] = 1.0 if slide else 0.0
	_mark()
	var slid_at := Tank.slide_offs
	var before := -tank.global_basis.z
	var longest := 0
	for tick in SimClock.TICK_RATE * 2:
		tank.command.throttle = 0.0
		tank.command.turn = -1.0  # keep turning INTO the wall: the corner swings toward the face
		await wait_physics_frames(1)
		longest = maxi(longest, tank.yaw_refused_ticks)
	var swept := rad_to_deg(Vector3(before.x, 0, before.z).normalized().angle_to(
			Vector3(-tank.global_basis.z.x, 0, -tank.global_basis.z.z).normalized()))
	var inside := _overlaps(tank)
	print("MEASURE yaw_fit_flush slide=%s swept %.1f deg in 2 s, longest refused run %d, slide-offs %d, offered %d, inside %s, at %s" % [
			slide, swept, longest, Tank.slide_offs - slid_at, _offered(), inside, tank.global_position])
	return [longest, swept, Tank.slide_offs - slid_at, inside]


## The positive control: without the slide-off, the flush hull is refused and holds (the five_squads 80-92 tick runs).
func test_a_hull_flush_against_one_wall_freezes_without_the_slide_off() -> void:
	var got := await _pivot_against_one_wall(false)
	assert_true(int(got[0]) > 3, "no slide-off: the flush pivot is refused and holds (longest run %d, %.1f deg)" % [got[0], got[1]])


## The treatment: the hull scrapes off the one wall and turns, never ending inside it; CP4's no-run-over-3 bar.
func test_a_hull_flush_against_one_wall_slides_off_and_turns() -> void:
	var got := await _pivot_against_one_wall(true)
	assert_true(int(got[2]) > 0, "the slide-off engaged (%d)" % got[2])
	assert_true(int(got[0]) <= 3, "no refused run over 3 ticks (longest %d)" % got[0])
	assert_true(float(got[1]) > 20.0, "and it turns (%.1f deg in 2 s)" % got[1])
	assert_true(not bool(got[3]), "without ending inside the crate")


## True when the hull is overlapping world geometry where it stands. NOT named `test_*`: the runner collects every
## method with that prefix and would call this one with no argument.
func _overlaps(tank: Tank) -> bool:
	return tank.test_move(tank.global_transform, Vector3.ZERO, null, 0.001, true)
