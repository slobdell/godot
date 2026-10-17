extends TestCase
## Round 33 (R33.3, manoeuvre's finding, a main bug): **a seam hold is released when the order that started it is
## replaced.** A War Rig taken for a face (the open-ground face-behind: the seam holds it while its search runs) is then
## told `stop` (as a declined contact face or HOLD's reverse move_to cuts it off): `take` / `hold` are never reached
## again for it, so before the fix its crew stayed in `PlannerSeam._crews` and `live()` read true to the end of the
## match (Movement.unstick skipped it; the C++ drive's `seam_live` mirror reads the same table). Released within
## STALE_TICKS + 1 now, once a tick, without the hull asking again.

const MATCH := preload("res://game/match/match.tscn")
const START := Vector3(0.0, 0.0, 15.0)


func test_a_held_face_is_released_when_its_order_is_replaced() -> void:
	PlannerSeam.reset()
	await ArenaFixture.build(self, "yard_open")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(1, 0.0)
	var tank := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	tank.place(START, 0.0)
	var controller := OrderController.new()
	controller.tank = tank
	controller.tanks_root = game_match.tanks
	add_to_tree(controller)
	await wait_physics_frames(2)
	controller.set_orders({"type": "face", "x": START.x, "z": START.z + 100.0}, {"type": "hold_fire"})
	var taken := -1
	for frame in SimClock.TICK_RATE * 3:
		await tree.physics_frame
		if PlannerSeam.live("Rig"):
			taken = frame
			break
	assert_true(taken >= 0, "the seam takes the rig's face-behind (a search pending: %s)" % PlannerSeam.report())
	controller.set_orders({"type": "stop"}, {"type": "hold_fire"})
	var released := -1
	for frame in SimClock.TICK_RATE * 2:
		await tree.physics_frame
		if not PlannerSeam.live("Rig"):
			released = frame + 1
			break
	print("SEAM_STALE taken at frame %d, released %d ticks after `stop` (%s)" % [taken, released, PlannerSeam.report()])
	assert_true(released >= 1 and released <= PlannerSeam.STALE_TICKS + 2,
			"the hold ends within %d ticks of the order being replaced (released %d; -1 = still live 2 s later)" % [
			PlannerSeam.STALE_TICKS + 2, released])
	assert_eq(PlannerSeam.stale_released, 1, "released as stale, once")
	PlannerSeam.reset()
