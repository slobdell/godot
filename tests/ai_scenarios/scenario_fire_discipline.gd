extends TestCase
## Fire discipline (A4 in _agents/streams/archive/round2/ai.md): friendly fire is on in round 2, so a brain must never put a
## shell through a teammate. The stage is the open west lane (x ≈ -100), clear of obstacles.

const PENDING := []

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
	for tick in SimClock.TICK_RATE * 8:
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
	for tick in SimClock.TICK_RATE * 16:
		await s.step()
		if friend.global_position.distance_to(ends[going]) < 4.0:
			going = 1 - going
			friend_orders.set_orders({"type": "move_to", "x": ends[going].x, "z": ends[going].z}, null)
		var blocked := _lane_distance(me.global_position, target.global_position, friend.global_position) < 2.0
		lane_blocked_ticks += 1 if blocked else 0
		if s.shots_by(me) > shots_before:
			shots_before = s.shots_by(me)
			if blocked:
				fired_through += 1
	var blocked_s := float(lane_blocked_ticks) / SimClock.TICK_RATE
	print("MEASURE ai_friendly_lane shots %d, through the friend %d, lane blocked %.1f s" % [s.shots_by(me), fired_through, blocked_s])
	# In seconds (lesson 30): the bar was 60 TICKS, written at 60 Hz for one second; at 30 Hz the same crossing measured
	# 42 ticks (1.4 s) and failed the setup check until round 7.
	assert_true(blocked_s >= 1.0, "setup: the friend really crosses the lane (%.1f s blocked)" % blocked_s)
	assert_true(s.shots_by(me) >= 2, "it still shoots when the lane is clear (%d shots)" % s.shots_by(me))
	assert_eq(fired_through, 0, "it never fires while the friend is in the line of fire")


# REASON (CP3, round 10; combat's ruling, 2026-09-22): RED ON PURPOSE -- combat's row: parked-friend lane vs the bigger
# bus, lof-site arm pending. The shooter and the friend are both the default unit, the bus grew to 2.90 x 9.70 m (R6),
# and the friendly-fire disc of its diagonal (5.06 m, was 4.47) refuses the second shot. A behaviour claim on the `lof`
# disc site, so the bar (shots >= 2) is NOT loosened; combat takes it once CP3 is on main.
func test_a_tank_blocked_by_a_parked_friend_moves_to_clear_the_lane() -> void:
	var s := AiScenario.create(self)
	var target := s.dummy(Match.Team.RUST, "Rust_Target_1", TARGET_AT, PI)
	AiScenario.make_durable(target)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", SHOOTER_AT, 0.0)
	var friend := s.dummy(Match.Team.GREEN, "Green_Parked_1", Vector3(-100, 0, 20), 0.0)
	AiScenario.make_durable(friend)
	var fired_through := 0
	var shots_before := 0
	var first_shot := -1
	await s.start()
	for tick in SimClock.TICK_RATE * 12:
		await s.step()
		if s.shots_by(me) > shots_before:
			shots_before = s.shots_by(me)
			if first_shot < 0:
				first_shot = tick
			if _lane_distance(me.global_position, target.global_position, friend.global_position) < 2.0:
				fired_through += 1
	print("MEASURE ai_parked_friend first shot after %d ticks, %d shots, through the friend %d, moved %.1f m (last: %s, held %d ticks)" % [
			first_shot, s.shots_by(me), fired_through, me.global_position.distance_to(SHOOTER_AT), s.brain_of(me).tank.intent,
			s.brain_of(me).lane_blocked_ticks])
	assert_eq(fired_through, 0, "it never fires through the parked friend")
	assert_true(first_shot >= 0 and first_shot <= SimClock.TICK_RATE * 6, "it finds a clear lane and fires within 6 s (first shot at tick %d)" % first_shot)
	assert_true(s.shots_by(me) >= 2, "and keeps firing from there (%d shots)" % s.shots_by(me))


func _artillery_shots(friend_at: Vector3) -> int:
	var s := AiScenario.create(self)
	var target := s.dummy(Match.Team.RUST, "Rust_Target_1", Vector3(-100, 0, -40), PI)
	AiScenario.make_durable(target)
	var friend := s.dummy(Match.Team.GREEN, "Green_Spotter_1", friend_at, PI)
	AiScenario.make_durable(friend)
	var battery := s.brain_tank(Match.Team.GREEN, "Green_Battery_1", Vector3(-100, 0, 60), 0.0, {}, "artillery")
	await s.start()
	for tick in SimClock.TICK_RATE * 15:
		await s.step()
	var shots := s.shots_by(battery)
	s.dispose()
	return shots


func test_artillery_holds_fire_on_an_enemy_brawling_with_a_friend() -> void:
	var clear := await _artillery_shots(Vector3(-100, 0, 10))
	var crowded := await _artillery_shots(Vector3(-97, 0, -44))
	print("MEASURE ai_artillery_splash shots with the spotter 50 m off %d, with the friend 5 m from the target %d" % [clear, crowded])
	assert_true(clear >= 1, "setup: with the spotter well clear, the battery shells the target (%d rounds)" % clear)
	assert_eq(crowded, 0, "it won't drop rounds on an enemy a friend is touching")
