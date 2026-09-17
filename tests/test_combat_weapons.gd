extends TestCase
## Round 3 combat X2: the weapons rebuilt for feel (the lead: tanks "shoot at very low frequency and … land devastating
## hit, but a miss is also quite costly"; the IFV a 25 mm Bradley cannon firing bursts; the scout a machine-gun stream
## that only fires where the hull points). Targets from _agents/streams/archive/round3/combat.md X2, measured in a real match scene.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const LANE_X := -100.0


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(5, 0.0)
	return game_match


func _dispose(game_match: Match) -> void:
	for node: Node in tree.root.get_children():
		if node is Match or node is Arena:
			node.queue_free()
	await wait_physics_frames(2)


func _fired_ticks(game_match: Match) -> Array:
	var ticks: Array = []
	game_match.weapon_fired.connect(func(event: Dictionary) -> void: ticks.append(int(event["tick"])))
	return ticks


# ---- The profiles hit the design targets ------------------------------------------------------

func test_the_tank_cannon_is_slow_heavy_and_visible() -> void:
	var cannon := Weapons.profile("cannon")
	assert_true(float(cannon["reload_s"]) >= 4.0 and float(cannon["reload_s"]) <= 6.0, "reload 4-6 s (%.1f)" % cannon["reload_s"])
	assert_true(float(cannon["projectile_speed_mps"]) >= 60.0 and float(cannon["projectile_speed_mps"]) <= 90.0,
			"a shell you can see and dodge: 60-90 m/s (%.0f)" % cannon["projectile_speed_mps"])
	assert_eq(int(cannon["burst_count"]), 1, "one shell per pull")


func test_the_ifv_fires_fast_bursts() -> void:
	var gun := Weapons.profile("autocannon")
	assert_true(int(gun["burst_count"]) >= 3 and int(gun["burst_count"]) <= 5, "3-5 rounds a burst (%d)" % gun["burst_count"])
	assert_true(float(gun["reload_s"]) >= 1.5 and float(gun["reload_s"]) <= 2.0, "1.5-2 s between bursts (%.2f)" % gun["reload_s"])
	assert_true(float(gun["projectile_speed_mps"]) >= 2.0 * float(Weapons.profile("cannon")["projectile_speed_mps"]),
			"25 mm rounds are far faster than a tank shell")
	assert_true(float(gun["penetration"]) < float(Units.armor("tank", "front")), "and can't get through a tank's front")


func test_the_scout_fires_a_stream() -> void:
	var gun := Weapons.profile("machine_gun")
	var rounds_per_second := 1.0 / float(gun["reload_s"])
	assert_true(rounds_per_second >= 8.0 and rounds_per_second <= 12.0, "8-12 rounds/s (%.1f)" % rounds_per_second)
	assert_true(float(gun["spread_deg"]) > 0.0, "a wall of bullets spreads")
	assert_eq(gun["fire_model"], "stream", "a stream")
	assert_eq(Units.profile("scout")["mount"], "fixed", "only where the hull points")


# ---- Firing mechanics -----------------------------------------------------------------------

func test_an_ifv_burst_fires_its_rounds_then_waits_for_the_reload() -> void:
	var game_match := _setup()
	var ticks := _fired_ticks(game_match)
	var ifv := game_match.spawn_tank("Ifv", 0, Match.Team.GREEN, "ifv")
	ifv.global_position = Vector3(LANE_X, 0.0, 40.0)
	await wait_physics_frames(2)
	var gun := Weapons.profile("autocannon")
	var cycle := roundi(float(gun["reload_s"]) * float(SimClock.TICK_RATE))
	for tick in cycle + 30:  # trigger held for one full cycle and a bit
		ifv.command = TankCommand.new(0.0, 0.0, ifv.global_position + Vector3(0.0, 1.0, -40.0), true)
		await tree.physics_frame
	var burst := int(gun["burst_count"])
	assert_eq(ticks.size(), 2 * burst, "two bursts of %d in one cycle + half a second (%s)" % [burst, ticks])
	if ticks.size() >= burst + 1:
		var interval := roundi(float(gun["burst_interval_s"]) * float(SimClock.TICK_RATE))
		for i in range(1, burst):
			assert_eq(ticks[i] - ticks[i - 1], interval, "rounds %d apart inside a burst" % interval)
		assert_eq(ticks[burst] - ticks[0], cycle, "the next burst starts one reload after the first")


func test_a_burst_finishes_after_the_trigger_is_released() -> void:
	var game_match := _setup()
	var ticks := _fired_ticks(game_match)
	var ifv := game_match.spawn_tank("Ifv", 0, Match.Team.GREEN, "ifv")
	ifv.global_position = Vector3(LANE_X, 0.0, 40.0)
	await wait_physics_frames(2)
	var aim := ifv.global_position + Vector3(0.0, 1.0, -40.0)
	ifv.command = TankCommand.new(0.0, 0.0, aim, true)
	await tree.physics_frame
	for tick in SimClock.TICK_RATE:
		ifv.command = TankCommand.new(0.0, 0.0, aim, false)
		await tree.physics_frame
	assert_eq(ticks.size(), int(Weapons.profile("autocannon")["burst_count"]), "a started burst is committed")


func test_a_scout_holding_the_trigger_streams_rounds() -> void:
	var game_match := _setup()
	var ticks := _fired_ticks(game_match)
	var scout := game_match.spawn_tank("Scout", 0, Match.Team.GREEN, "scout")
	scout.global_position = Vector3(LANE_X, 0.0, 40.0)
	await wait_physics_frames(2)
	for tick in SimClock.TICK_RATE:
		scout.command = TankCommand.new(0.0, 0.0, scout.global_position + Vector3(0.0, 1.0, -30.0), true)
		await tree.physics_frame
	var expected := float(SimClock.TICK_RATE) / roundi(float(Weapons.profile("machine_gun")["reload_s"]) * float(SimClock.TICK_RATE))
	assert_near(float(ticks.size()), expected, 1.0, "one second of trigger = %.0f rounds (%d)" % [expected, ticks.size()])


func test_a_gun_fired_by_a_controller_that_waits_for_ready_keeps_its_designed_rate() -> void:
	# Round 5 (30 Hz): controllers run before the tank in a tick and pull the trigger when ready_to_fire() says so. It
	# used to read the reload as the tank published it LAST tick, so every trigger pull came a tick late: a 0.1 s
	# machine gun fired every 7 ticks at 60 Hz (8.6/s) and every 4 at 30 Hz (7.5/s), which thinned every beaten zone.
	var game_match := _setup()
	var ticks := _fired_ticks(game_match)
	var scout := game_match.spawn_tank("Scout", 0, Match.Team.GREEN, "scout")
	scout.global_position = Vector3(LANE_X, 0.0, 40.0)
	await wait_physics_frames(2)
	var aim := scout.global_position + Vector3(0.0, 1.0, -30.0)
	for tick in SimClock.TICK_RATE * 2:
		scout.command = TankCommand.new(0.0, 0.0, aim, scout.ready_to_fire())
		await tree.physics_frame
	var designed := 2.0 / float(Weapons.profile("machine_gun")["reload_s"])
	assert_near(float(ticks.size()), designed, 1.0, "two seconds of fire-when-ready = %.0f rounds (%d)" % [designed, ticks.size()])


func test_a_missed_tank_shell_costs_the_whole_reload() -> void:
	var game_match := _setup()
	var ticks := _fired_ticks(game_match)
	var tank := game_match.spawn_tank("Gunner", 0, Match.Team.GREEN, "tank")
	tank.global_position = Vector3(LANE_X, 0.0, 40.0)
	await wait_physics_frames(2)
	var aim := tank.global_position + Vector3(0.0, 1.0, -40.0)
	var reload := roundi(float(Weapons.profile("cannon")["reload_s"]) * float(SimClock.TICK_RATE))
	for tick in reload - 5:
		tank.command = TankCommand.new(0.0, 0.0, aim, true)
		await tree.physics_frame
	assert_eq(ticks.size(), 1, "one shell, then nothing for %d ticks" % reload)
	assert_true(not tank.ready_to_fire(), "still reloading")


# ---- Time to kill ---------------------------------------------------------------------------

## Shells a tank needs to destroy a full-health, shielded `unit_id` presenting `yaw` toward it at 30 m.
func _shells_to_kill(unit_id: String, target_yaw: float) -> Dictionary:
	var game_match := _setup()
	var shots := [0]
	var damage: Array = []
	game_match.weapon_fired.connect(func(_event: Dictionary) -> void: shots[0] += 1)
	game_match.projectile_impact.connect(func(event: Dictionary) -> void:
		if event.has("target"):
			damage.append(float(event["damage"])))
	var gunner := game_match.spawn_tank("Gunner", 0, Match.Team.GREEN, "tank")
	var target := game_match.spawn_tank("Target", 0, Match.Team.RUST, unit_id)
	gunner.global_position = Vector3(LANE_X, 0.0, 30.0)
	target.global_position = Vector3(LANE_X, 0.0, 0.0)
	target.rotation.y = target_yaw
	await wait_physics_frames(2)
	var effective := float(target.max_health) + target.max_shield
	var ticks := 0
	while target.is_alive() and ticks < SimClock.TICK_RATE * 30:
		gunner.command = TankCommand.new(0.0, 0.0, target.global_position + Vector3.UP, true)
		target.command = TankCommand.new()
		await tree.physics_frame
		ticks += 1
	var result := {"shots": shots[0], "alive": target.is_alive(), "first": damage[0] / effective if not damage.is_empty() else 0.0}
	await _dispose(game_match)
	return result


func test_two_to_four_shells_kill_a_tank_and_a_flank_shot_is_devastating() -> void:
	var side: Dictionary = await _shells_to_kill("tank", PI / 2.0)
	var front: Dictionary = await _shells_to_kill("tank", PI)
	var rear: Dictionary = await _shells_to_kill("tank", 0.0)
	for case: Array in [["side", side], ["front", front], ["rear", rear]]:
		var r: Dictionary = case[1]
		assert_true(not r["alive"], "%s: the tank dies" % case[0])
		assert_true(int(r["shots"]) >= 2 and int(r["shots"]) <= 4, "%s: 2-4 shells (%d)" % [case[0], r["shots"]])
	assert_true(float(side["first"]) >= 0.5, "one side hit takes most of a tank (%.0f%% of shield + hull)" % (100.0 * side["first"]))
	assert_true(float(rear["first"]) >= float(side["first"]), "the rear hurts at least as much")
	assert_true(float(front["first"]) >= 0.25, "a frontal hit still takes a big chunk (%.0f%%)" % (100.0 * front["first"]))
	assert_true(int(front["shots"]) > int(side["shots"]), "the front takes more shells than the side")
