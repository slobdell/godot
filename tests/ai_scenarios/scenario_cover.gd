extends TestCase
## Cover behavior (A2/A3 in _agents/streams/archive/round2/ai.md). The stage: WallWestA (x -45..-27, z ≈ -20) with a Green
## tank in the open south-east of it and Rust guns to the north whose sight lines pass east of the wall.

const PENDING := []

const GREEN_START := Vector3(-20, 0, -12)
## Behind the wall from both guns (checked by the setup assertions).
const HIDDEN_SPOT := Vector3(-36, 0, -14)


func _stage(s: AiScenario, gun_count: int) -> Array[Tank]:
	var guns: Array[Tank] = []
	var spots := [Vector3(-38, 0, -55), Vector3(-30, 0, -58)]
	for i in gun_count:
		var gun := s.shooter(Match.Team.RUST, "Rust_Gun_%d" % (i + 1), spots[i], PI)
		AiScenario.make_durable(gun)
		guns.append(gun)
	return guns


func _hidden_from_all(me: Tank, guns: Array[Tank]) -> bool:
	for gun in guns:
		if AiScenario.sees(gun, me):
			return false
	return true


func test_a_hurt_tank_under_fire_gets_out_of_sight() -> void:
	var s := AiScenario.create(self)
	var guns := _stage(s, 2)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", GREEN_START, 0.0)
	# 40% hurt. Combat X2 (round 3): a hull big enough to live through one volley of the new cannons (320 per shell);
	# at 120 of 300 the first shell killed it before any brain could react (two side hits: 640).
	me.max_health = 2000
	me.health = 800
	me.shield = 0.0
	me.ticks_since_hit = 0  # just hit: the shield stays down for its recharge delay
	var hidden_run := 0
	var longest_hidden := 0
	var first_hidden := -1
	var visible_at_start := false
	await s.start()
	for tick in range(1, 60 * 7 + 1):
		await s.step()
		if not me.is_alive():
			continue
		if tick == 1:
			visible_at_start = not _hidden_from_all(me, guns)
		if _hidden_from_all(me, guns):
			hidden_run += 1
			longest_hidden = maxi(longest_hidden, hidden_run)
			if first_hidden < 0:
				first_hidden = tick
		else:
			hidden_run = 0
	print("MEASURE ai_hurt_to_cover first hidden after %d ticks, longest hidden %d ticks, alive %s" % [first_hidden, longest_hidden, me.is_alive()])
	assert_true(visible_at_start, "setup: both guns can see the tank at the start")
	assert_true(me.is_alive(), "the tank survives 7 s under two guns")
	assert_true(first_hidden > 0 and first_hidden <= 60 * 5, "it is out of both guns' sight within 5 s (first hidden at tick %d)" % first_hidden)
	assert_true(longest_hidden >= 60, "and stays hidden for at least a second (%d ticks)" % longest_hidden)


func test_a_healthy_tank_near_a_wall_fights_from_cover() -> void:
	var s := AiScenario.create(self)
	var guns := _stage(s, 1)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", GREEN_START, 0.0)
	var samples := 0
	var hidden := 0
	var back_in_cover_after_shot := 0
	var shots_seen := 0
	var was_hidden := false
	await s.start()
	for tick in range(1, 60 * 25 + 1):
		await s.step()
		if tick < 60 * 5 or not me.is_alive():
			continue
		samples += 1
		var now_hidden := _hidden_from_all(me, guns)
		hidden += 1 if now_hidden else 0
		if s.shots_by(me) > shots_seen and not now_hidden:
			shots_seen = s.shots_by(me)
		if now_hidden and not was_hidden and shots_seen > 0:
			back_in_cover_after_shot += 1
		was_hidden = now_hidden
	var fraction := float(hidden) / maxf(samples, 1)
	print("MEASURE ai_cover_fire hidden %.0f%% of 20 s, shots %d, returns to cover %d, alive %s" % [fraction * 100.0,
			s.shots_by(me), back_in_cover_after_shot, me.is_alive()])
	assert_true(me.is_alive(), "it survives the duel (the gun is durable, so hiding is what saves it)")
	assert_true(fraction >= 0.5, "it spends most of the fight out of the gun's sight (%.0f%%)" % (fraction * 100.0))
	assert_true(s.shots_by(me) >= 4, "and still shoots back from cover (%d shots)" % s.shots_by(me))
	assert_true(back_in_cover_after_shot >= 2, "it goes back into cover after firing, repeatedly (%d times)" % back_in_cover_after_shot)
