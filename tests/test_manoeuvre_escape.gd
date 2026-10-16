extends TestCase
## Round 31, manoeuvre H1 (C31.4, `--nav-off=unstickback` = ON, opt-in until CP-H): **the stall escape redesigned as a
## consumer of the honest reading.** A hull pinned under a routed goal asks the friend that pins it, then backs STRAIGHT
## (no lock) as far as its outline sweep and the hulls behind allow, ended by the real backoff; with no room it stands
## and the phase machinery reports it blocked by name. Round 30's two pair-check regressions are stages here: a hull
## under a raw `drive` order never backs off a wall, and an 8x8 in single file never reverses on lock into its column.
##
## `Movement.unstick` is driven directly on the plant (the controllers' own ticks are off), so the GDScript rule runs on
## either native switch.

const MATCH := preload("res://game/match/match.tscn")


static func _controller_of(lab: TacticsLab, tank: Tank) -> OrderController:
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == tank:
			return child
	return null


static func _arms(names: Array) -> PackedStringArray:
	var was := Movement._off
	Movement._off = PackedStringArray(names)
	Movement._off_parsed = true
	return was


static func _yaw_deg(tank: Tank) -> float:
	return rad_to_deg(tank.global_rotation.y)


## B, `behind` metres south of A, both facing north (-Z); B drives at its goal 40 m north through A (A holds still).
## `tail` > 0 puts a third hull C that far south of B (single file). Returns what B did after the stall rule fired.
func _pin(on: bool, unit_id: String, behind: float, seconds: float, tail := 0.0, real_on := true) -> Dictionary:
	var was_native := BrainSwitches.native
	var was_real := Tank.real_velocity_on
	var was_off := _arms(["unstickback"] if on != Movement.UNSTICK_BACK_DEFAULT else [])
	Tank.real_velocity_on = real_on
	BrainSwitches.native = false
	Movement.reset_escape_arms()
	var lab := TacticsLab.create(self, 31)
	var a := lab.gun(Match.Team.GREEN, "Green_A_1", Vector3(TacticsScenarios.LANE_X, 0, 20), 0.0, unit_id)
	var b := lab.gun(Match.Team.GREEN, "Green_A_2", Vector3(TacticsScenarios.LANE_X, 0, 20 + behind), 0.0, unit_id)
	var c: Tank = null
	if tail > 0.0:
		c = lab.gun(Match.Team.GREEN, "Green_A_3", Vector3(TacticsScenarios.LANE_X, 0, 20 + behind + tail), 0.0, unit_id)
	await lab.start()
	_controller_of(lab, a).set_physics_process(false)
	var cb := _controller_of(lab, b)
	cb.set_physics_process(false)
	if c != null:
		_controller_of(lab, c).set_physics_process(false)
	var mover := cb.movement
	var goal := b.global_position + Vector3(0, 0, -40)
	var order := {"type": "move_to", "x": goal.x, "z": goal.z}
	var fires_before := Movement.unstick_fires
	var fired_at := -1.0
	var pinned_at := Vector3.INF
	var yaw0 := 0.0
	var max_back := 0.0
	var max_yaw := 0.0
	var reverse_ticks := 0
	var full_throttle_pinned := 0
	var delta := 1.0 / float(SimClock.TICK_RATE)
	for tick in int(SimClock.TICK_RATE * seconds):
		var cmd := TankCommand.new(1.0, 0.0, goal)
		mover.unstick(cmd, order, delta)
		b.command = cmd
		a.command = TankCommand.new(0.0, 0.0, a.global_position + Vector3(0, 0, -20))
		if c != null:  # the column closes up behind B (C drives into its tail and stays there)
			c.command = TankCommand.new(1.0, 0.0, c.global_position + Vector3(0, 0, -20))
		if fired_at < 0.0 and Movement.unstick_fires > fires_before:
			fired_at = tick * delta
			pinned_at = b.global_position
			yaw0 = _yaw_deg(b)
		if pinned_at != Vector3.INF and cmd.throttle < 0.0:
			reverse_ticks += 1
		if tick >= SimClock.TICK_RATE and cmd.throttle > 0.5 and b.real_velocity.length() < 0.5:
			full_throttle_pinned += 1  # after the first second (B meets A): pressing a hull it cannot move
		await lab.step()
		if pinned_at == Vector3.INF:
			continue
		max_back = maxf(max_back, b.global_position.z - pinned_at.z)  # south = backing off
		max_yaw = maxf(max_yaw, absf(angle_difference(deg_to_rad(_yaw_deg(b)), deg_to_rad(yaw0))))
	var out := {"fires": Movement.unstick_fires - fires_before, "fired_at": fired_at, "max_back": max_back,
			"max_yaw_deg": rad_to_deg(max_yaw), "reverse_ticks": reverse_ticks, "pressing_ticks": full_throttle_pinned,
			"arms": Movement.escape_arms(), "phase": mover.phase, "blocked_by": mover.blocked_by,
			"tail_gap": (c.global_position.z - b.global_position.z) if c != null else -1.0}
	lab.dispose()
	BrainSwitches.native = was_native
	Tank.real_velocity_on = was_real
	Movement._off = was_off
	return out


func test_an_ifv_pinned_on_a_squadmate_asks_then_backs_straight() -> void:
	var now := await _pin(true, "ifv", 11.0, 8.0)
	var base := await _pin(false, "ifv", 11.0, 8.0)
	print("MEASURE h1_escape ifv on a squadmate: fires %d at %.2f s, backed %.2f m, yaw %.1f deg, pressing ticks %d, arms %s | base: fires %d, pressing %d" % [
			now["fires"], now["fired_at"], now["max_back"], now["max_yaw_deg"], now["pressing_ticks"], now["arms"], base["fires"], base["pressing_ticks"]])
	assert_eq(base["fires"], 0, "the defect at base: the plant's reading never fires on a pinned IFV")
	assert_true(now["fires"] >= 1 and now["fired_at"] <= 3.0, "the honest reading fires within 3 s (at %.2f s)" % now["fired_at"])
	var arms: Dictionary = now["arms"]
	assert_true(int(arms["fires_hull"]) >= 1 and int(arms["asks"]) >= 1, "it was pinned on a hull and asked it first (%s)" % arms)
	assert_true(int(arms["backs"]) >= 1, "the friend did not clear (its tick is off): a straight reverse followed (%s)" % arms)
	assert_true(now["max_back"] >= Movement.ESC_BACK_MIN_M - 0.2 and now["max_back"] <= Movement.ESC_BACK_MAX_M + 1.0,
			"it backed off between the minimum and the cap (%.2f m)" % now["max_back"])
	assert_true(now["max_yaw_deg"] < 5.0, "STRAIGHT: no lock, the nose stays on the street (%.1f deg)" % now["max_yaw_deg"])
	assert_true(now["pressing_ticks"] < base["pressing_ticks"] / 2,
			"it does not sit at full throttle against the friend (%d ticks v base %d)" % [now["pressing_ticks"], base["pressing_ticks"]])


## Round 30's design note: a War Rig against a FRIEND reads the honest reading (touch false, a Tank collider), asks,
## then backs STRAIGHT a few metres — never run 1's reverse on lock that swung its tail across the street.
func test_a_war_rig_pinned_on_a_friend_asks_then_backs_straight() -> void:
	var now := await _pin(true, "gang_tank", 16.0, 8.0)
	print("MEASURE h1_escape gang_tank on a friend: fires %d at %.2f s, backed %.2f m, yaw %.1f deg, arms %s" % [
			now["fires"], now["fired_at"], now["max_back"], now["max_yaw_deg"], now["arms"]])
	var arms: Dictionary = now["arms"]
	assert_true(now["fires"] >= 1 and int(arms["fires_hull"]) >= 1, "the rig's stall reads the friend that pins it (%s)" % arms)
	assert_true(int(arms["asks"]) >= 1, "it asked first (%s)" % arms)
	assert_true(now["max_back"] >= Movement.ESC_BACK_MIN_M - 0.2, "then backed off (%.2f m)" % now["max_back"])
	assert_true(now["max_back"] <= Movement.ESC_BACK_MAX_M + 1.5, "a few metres, not a street's length (%.2f m)" % now["max_back"])
	assert_true(now["max_yaw_deg"] < 5.0, "straight, no lock (%.1f deg)" % now["max_yaw_deg"])


## Round 30's pair check (Sumps causeway, `test_tactics_mixed_legs`): an 8x8 in single file took one reverse on full
## lock and sat 21.5 m from its slot for good. With a squadmate close behind there is no room: it asks that one, never
## reverses into it, never swings on lock, and does not sit at full throttle meanwhile.
func test_an_8x8_in_single_file_never_reverses_on_lock_into_its_column() -> void:
	var now := await _pin(true, "law_tank", 9.3, 8.0, 9.6)
	print("MEASURE h1_escape law_tank single file: fires %d, backed %.2f m, yaw %.1f deg, reverse ticks %d, tail gap %.2f, pressing %d, arms %s, phase %s by '%s'" % [
			now["fires"], now["max_back"], now["max_yaw_deg"], now["reverse_ticks"], now["tail_gap"], now["pressing_ticks"],
			now["arms"], now["phase"], now["blocked_by"]])
	var arms: Dictionary = now["arms"]
	assert_true(now["fires"] >= 1, "the pin is read (%d fires)" % now["fires"])
	assert_true(now["max_yaw_deg"] < 5.0, "never on lock (%.1f deg)" % now["max_yaw_deg"])
	assert_true(now["max_back"] < 0.5, "no room behind: it does not reverse into its column (%.2f m)" % now["max_back"])
	assert_true(int(arms["refused"]) >= 1 and int(arms["backs"]) == 0, "the straight reverse was refused by the sweep (%s)" % arms)
	assert_true(now["pressing_ticks"] < SimClock.TICK_RATE * 3, "and it stands rather than pressing (%d ticks)" % now["pressing_ticks"])


## The switch OFF is round 29's rule bit for bit: the escape's counters stay at zero.
func test_switched_off_the_escape_never_runs() -> void:
	var base := await _pin(false, "ifv", 11.0, 4.0)
	assert_eq(base["arms"], {"fires_hull": 0, "fires_wall": 0, "asks": 0, "backs": 0, "backed": 0, "capped": 0, "refused": 0, "fallback": 0},
			"no escape arm moves with the switch off")


## Round 30's other pair-check red (`test_nav_wall_contact`): a hull under a raw `drive` order at a wall must NOT back
## off with the switch ON — the honest escape is for a routed goal only.
func test_a_hull_driven_at_a_wall_under_a_drive_order_never_backs_off() -> void:
	var was_off := _arms(["unstickback"] if not Movement.UNSTICK_BACK_DEFAULT else [])
	var was_native := BrainSwitches.native
	BrainSwitches.native = false
	Movement.reset_escape_arms()
	await ArenaFixture.build(self, "foundry")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var wall_at := Vector3(-36.0, 0.0, -20.0)
	var tank := game_match.spawn_tank("Driver", 0, Match.Team.GREEN, "tank")
	tank.global_position = wall_at + Vector3(0, 0, 11.0)
	tank.rotation.y = 0.0
	var ctl := OrderController.new()
	ctl.tank = tank
	ctl.tanks_root = game_match.tanks
	add_to_tree(ctl)
	assert_eq(ctl.set_orders({"type": "drive", "throttle": 1.0, "turn": 0.0, "seconds": 5.0}, {"type": "hold_fire"}), "", "told to drive")
	var nearest := INF
	var furthest_after := -INF
	for frame in int(SimClock.TICK_RATE * 5.0):
		await tree.physics_frame
		var gap := tank.global_position.z - wall_at.z
		nearest = minf(nearest, gap)
		if frame > SimClock.TICK_RATE * 2:
			furthest_after = maxf(furthest_after, gap)
	print("MEASURE h1_escape drive at a wall (tank): nearest %.2f m, furthest after 2 s %.2f, arms %s" % [nearest, furthest_after, Movement.escape_arms()])
	assert_eq(int(Movement.escape_arms()["backs"]) + int(Movement.escape_arms()["fires_wall"]) + int(Movement.escape_arms()["fires_hull"]), 0,
			"no honest escape under a drive order")
	assert_true(furthest_after - nearest < 0.5, "it stays pressed where it was driven (%.2f v %.2f)" % [furthest_after, nearest])
	BrainSwitches.native = was_native
	Movement._off = was_off


## R31.2 (the planner's seam): a plan that takes a hull ends manoeuvre's executor state, so nothing resumes stale when
## the plan releases it (a k-turn leg half driven, an escape in its ask or reverse stage, the stall clock).
func test_a_plan_taking_the_hull_ends_every_executor_state() -> void:
	var lab := TacticsLab.create(self, 31)
	var ifv := lab.gun(Match.Team.GREEN, "Green_A_1", Vector3(TacticsScenarios.LANE_X, 0, 30), 0.0, "ifv")
	await lab.start()
	var ctl := _controller_of(lab, ifv)
	ctl.set_physics_process(false)
	var mover := ctl.movement
	mover._kturn_turn = 1.0
	mover._kturn_start_leg(Vector2(-1, 4.0))
	mover._kturn_legs = [Vector2(1, 3.0)]
	mover._esc_stage = Movement.ESC_BACK
	mover._unstick_left = 1.2
	mover._stuck_time = 0.7
	mover.yield_to_plan()
	assert_true(not mover.in_kturn() and mover._kturn_legs.is_empty(), "the k-turn leg and its queued legs are ended")
	assert_eq(mover._esc_stage, Movement.ESC_NONE, "the escape is ended")
	assert_true(mover._unstick_left == 0.0 and mover._stuck_time == 0.0, "and the stall timers are cleared")
	lab.dispose()
