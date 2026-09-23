extends TestCase
## Round 10 (combat's relay, nav's fix): a route requested while the navigation map is NOT synced comes back empty
## (`Pathing.query` ready=false). Movement used to wait out REPATH_SECONDS (4 s) before asking again, driving the
## hull in a straight line meanwhile; the artillery scenario was decided by exactly that on a drained frame. Now the
## request is retried on the next tick. Mutation check: drop the retry and the path arrives ~4 s late, not within 2
## ticks of the map becoming ready.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func test_a_route_asked_before_the_map_is_ready_is_retried_next_tick() -> void:
	# An earlier test's regions must be gone first, or the map is "ready" with someone else's arena on it.
	await ArenaFixture._drain_regions(self, 5.0)
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = "foundry"
	# The order goes in on the SAME frame as the arena, before the navigation map can have synced.
	add_to_tree(arena)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Early", 0, Match.Team.GREEN, "tank")
	tank.global_position = Vector3(-100, 0, 40)
	var ctl := OrderController.new()
	ctl.tank = tank
	ctl.tanks_root = game_match.tanks
	add_to_tree(ctl)
	var before := Movement.route_not_ready
	ctl.set_orders({"type": "move_to", "x": 100.0, "z": -40.0}, {"type": "hold_fire"})
	var ready_at := -1
	var routed_at := -1
	for frame in int(SimClock.TICK_RATE * 6):
		await tree.physics_frame
		if ready_at < 0 and Pathing.is_ready(tank):
			ready_at = frame
		var points: PackedVector3Array = Movement.state(tank).get("path_points", PackedVector3Array())
		if routed_at < 0 and points.size() >= 2:
			routed_at = frame
			break
	# The positive control: the first requests really did land on an unready map, or this test proves nothing.
	assert_true(Movement.route_not_ready > before,
			"the first route requests found the map unsynced (%d)" % (Movement.route_not_ready - before))
	assert_true(ready_at >= 0 and routed_at >= 0, "the map became ready (frame %d) and a route came (frame %d)" % [ready_at, routed_at])
	assert_true(routed_at - ready_at <= 2,
			"the route arrives within 2 ticks of the map being ready (ready %d, routed %d)" % [ready_at, routed_at])
