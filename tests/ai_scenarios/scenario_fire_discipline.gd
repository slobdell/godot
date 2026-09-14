extends TestCase
## Fire discipline (A4 in _agents/streams/ai.md): friendly fire is on in round 2, so a brain must never put a
## shell through a teammate. The stage is the open west lane (x ≈ -100), clear of obstacles.

const PENDING := ["test_holds_fire_while_a_friendly_crosses_the_line"]

const SHOOTER_AT := Vector3(-100, 0, 40)
const TARGET_AT := Vector3(-100, 0, 0)


## Distance from `point` to the segment a→b, and whether it lies between them (flat).
static func _lane_distance(a: Vector3, b: Vector3, point: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(point.x - a.x, point.z - a.z)
	var t := clampf(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
	if t <= 0.0 or t >= 1.0:
		return INF
	return (ap - ab * t).length()


func test_a_brain_fires_at_a_visible_enemy_with_a_clear_lane() -> void:
	var s := AiScenario.create(self)
	var target := s.dummy(Match.Team.RUST, "Rust_Target_1", TARGET_AT, PI)
	AiScenario.make_durable(target)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", SHOOTER_AT, 0.0)
	await s.start()
	for tick in 60 * 8:
		await s.step()
	print("MEASURE ai_clear_lane shots %d in 8 s" % s.shots_by(me))
	assert_true(s.shots_by(me) >= 2, "a brain tank shoots a visible enemy 40 m away (%d shots in 8 s)" % s.shots_by(me))


func test_holds_fire_while_a_friendly_crosses_the_line() -> void:
	var s := AiScenario.create(self)
	var target := s.dummy(Match.Team.RUST, "Rust_Target_1", TARGET_AT, PI)
	AiScenario.make_durable(target)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", SHOOTER_AT, 0.0)
	# A teammate shuttles across the lane at z = 20, halfway to the target, again and again.
	var ends := [Vector3(-114, 0, 20), Vector3(-86, 0, 20)]
	var friend := s.shooter(Match.Team.GREEN, "Green_Friend_1", ends[0], -PI / 2.0,
			{"type": "move_to", "x": ends[1].x, "z": ends[1].z}, {"type": "hold_fire"})
	AiScenario.make_durable(friend)
	var friend_orders := s.controller_of(friend)
	var going := 1
	var fired_through := 0
	var lane_blocked_ticks := 0
	var shots_before := 0
	await s.start()
	for tick in 60 * 16:
		await s.step()
		if friend.global_position.distance_to(ends[going]) < 4.0:
			going = 1 - going
			friend_orders.set_orders({"type": "move_to", "x": ends[going].x, "z": ends[going].z}, null)
		var blocked := _lane_distance(me.global_position, target.global_position, friend.global_position) < 2.5
		lane_blocked_ticks += 1 if blocked else 0
		if s.shots_by(me) > shots_before:
			shots_before = s.shots_by(me)
			if blocked:
				fired_through += 1
	print("MEASURE ai_friendly_lane shots %d, through the friend %d, lane blocked %d ticks" % [s.shots_by(me), fired_through, lane_blocked_ticks])
	assert_true(lane_blocked_ticks >= 60, "setup: the friend really crosses the lane (%d ticks blocked)" % lane_blocked_ticks)
	assert_true(s.shots_by(me) >= 2, "it still shoots when the lane is clear (%d shots)" % s.shots_by(me))
	assert_eq(fired_through, 0, "it never fires while the friend is in the line of fire")
