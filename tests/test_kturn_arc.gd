extends TestCase
## Round 31, manoeuvre H2 (`--nav-off=kturnarc` turns it ON: OPT-IN until CP-H), from round 30's M2b (the planner's P4
## findings on the executor): **a planned leg is measured by the arc the hull drove IN ITS GEAR, and the stopping
## distance is the plant's discrete one.** `_planned_reverse` read the leg's progress as the
## flat distance from where it took hold (the chord), 3 % short of the arc on a War Rig's 10 m full-lock leg, so the
## hull drove past its planned end by that; and v²/2b is the continuous stopping distance where the plant brakes in
## ticks (v²/2b − v·dt/2). Round 30's unsigned arc counted a short hull's forward roll-out as a reverse leg's progress
## (`scenario_cp2`'s scout orbit); round 31's arc is signed by the gear. Switch off = round 14's chord and v²/2b.

const LANE_X := TacticsScenarios.LANE_X


static func _controller_of(lab: TacticsLab, tank: Tank) -> OrderController:
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == tank:
			return child
	return null


## A War Rig at rest on open ground drives ONE planned reverse leg of `metres` on full lock (set up as the planner
## would), under a routed move far ahead so the executor runs; the path it really drove until the leg ended and it
## came to rest, and how the leg ended.
func _leg(metres: float, arc_on: bool, unit_id := "gang_tank", legs := 1) -> Dictionary:
	var was_native := BrainSwitches.native
	var was_off := Movement._off
	BrainSwitches.native = false
	Movement._off = PackedStringArray(["kturnarc"]) if arc_on else PackedStringArray([])
	Movement._off_parsed = true
	var lab := TacticsLab.create(self, 31)
	var rig := lab.gun(Match.Team.GREEN, "Green_A_1", Vector3(LANE_X, 0, 30), 0.0, unit_id)
	await lab.start()
	var ctl := _controller_of(lab, rig)
	var mover := ctl.movement
	var goal := rig.global_position + Vector3(0, 0, -80)
	ctl.set_orders({"type": "move_to", "x": goal.x, "z": goal.z}, {"type": "hold_fire"})
	await lab.step()
	mover._kturn_turn = 1.0
	mover._kturn_start_leg(Vector2(-1, metres))
	var path := 0.0
	var last := rig.global_position
	var ended_at := -1.0
	var path_at_end := 0.0
	var legs_left := legs - 1
	var delta := 1.0 / float(SimClock.TICK_RATE)
	for tick in int(SimClock.TICK_RATE * 12.0 * legs):
		await lab.step()
		path += Vector2(rig.global_position.x - last.x, rig.global_position.z - last.z).length()
		last = rig.global_position
		if mover._kturn_left_m <= 0.0 and legs_left > 0:
			# The next leg starts WHILE the hull still rolls in its gear (native's review: a leg that starts rolling must
			# not inherit the last leg's arc). Measured from here.
			legs_left -= 1
			path = 0.0
			mover._kturn_start_leg(Vector2(-1, metres))
			continue
		if ended_at < 0.0 and mover._kturn_left_m <= 0.0 and legs_left == 0:
			ended_at = tick * delta
			path_at_end = path
		if ended_at >= 0.0 and rig.speed() >= -0.05:
			break  # at rest or driving on: the roll past the leg's end is over
	var out := {"path": path, "path_at_end": path_at_end, "ended_at": ended_at, "aborted": int(Movement.route_arms()["kturn_aborted"])}
	lab.dispose()
	BrainSwitches.native = was_native
	Movement._off = was_off
	return out


func test_a_ten_metre_leg_drives_ten_metres_by_the_arc() -> void:
	var on := await _leg(10.0, true)
	var off := await _leg(10.0, false)
	print("MEASURE m2b_kturn_arc gang_tank 10 m reverse leg on full lock: arc rule drove %.2f m (%.2f at the leg's end, ended %.2f s, aborted %d) | chord rule %.2f m (%.2f at end, aborted %d)" % [
			on["path"], on["path_at_end"], on["ended_at"], on["aborted"], off["path"], off["path_at_end"], off["aborted"]])
	assert_true(on["ended_at"] >= 0.0 and off["ended_at"] >= 0.0, "setup: both legs ended (%.2f, %.2f s)" % [on["ended_at"], off["ended_at"]])
	assert_true(on["aborted"] == 0, "the leg ended by its plan, not a timeout or a hit")
	assert_true(absf(on["path"] - 10.0) <= 0.4, "the arc rule drives the planned 10 m within 0.4 m (%.2f m)" % on["path"])
	assert_true(absf(on["path"] - 10.0) < absf(off["path"] - 10.0), "and nearer the plan than the chord rule (%.2f v %.2f)" % [on["path"], off["path"]])
	assert_true(off["path"] > on["path"], "the chord rule over-runs the arc (%.2f v %.2f)" % [off["path"], on["path"]])


## A hull under KTURN_BRAKE_HULL_M (an IFV) starts every leg "rolling" (its brake rule is off), and a second leg started
## while it still rolls must drive its own metres, not end at once on the first leg's arc (native's review of 1f1c9835).
func test_a_second_leg_started_rolling_drives_its_own_metres() -> void:
	var on := await _leg(8.0, true, "ifv", 2)
	print("MEASURE m2b_kturn_arc ifv second 8 m leg started rolling: drove %.2f m (%.2f at the leg's end, ended %.2f s, aborted %d)" % [
			on["path"], on["path_at_end"], on["ended_at"], on["aborted"]])
	assert_true(on["ended_at"] >= 0.0, "the second leg ended (%.2f s)" % on["ended_at"])
	assert_true(absf(on["path"] - 8.0) <= 1.0, "it drove its own 8 m within 1 m (%.2f m), not the first leg's arc" % on["path"])



## Round 30's scout orbit (`scenario_cp2`, the trace in `references/round30/manoeuvre/kturnarc_scout_deck_*.log`): a
## scout (under KTURN_BRAKE_HULL_M, so its leg is "rolling" from the first tick) is planned a 3.5 m reverse leg while
## still doing ~10 m/s FORWARD. The signed arc subtracts the roll-out: the leg ends with the hull backed its 3.5 m
## behind where the leg began (within the stopping slack), not 2.2 m short as the unsigned arc left it.
func _rolling_leg(arc_on: bool, metres := 3.5) -> Dictionary:
	var was_native := BrainSwitches.native
	var was_off := Movement._off
	BrainSwitches.native = false
	Movement._off = PackedStringArray(["kturnarc"]) if arc_on else PackedStringArray([])
	Movement._off_parsed = true
	var lab := TacticsLab.create(self, 31)
	var scout := lab.gun(Match.Team.GREEN, "Green_A_1", Vector3(LANE_X, 0, 60), 0.0, "scout")
	await lab.start()
	var ctl := _controller_of(lab, scout)
	var mover := ctl.movement
	var goal := scout.global_position + Vector3(0, 0, -150)
	ctl.set_orders({"type": "move_to", "x": goal.x, "z": goal.z}, {"type": "hold_fire"})
	for tick in int(SimClock.TICK_RATE * 4.0):
		await lab.step()
		if scout.speed() >= 9.5:
			break
	var speed_at_start := scout.speed()
	var start := scout.global_position
	var nose := Vector2(-scout.global_basis.z.x, -scout.global_basis.z.z).normalized()
	mover._kturn_turn = 0.0
	mover._kturn_start_leg(Vector2(-1, metres))
	var ended := false
	var behind_at_end := 0.0
	var max_forward := 0.0
	for tick in int(SimClock.TICK_RATE * 8.0):
		await lab.step()
		var along := Vector2(scout.global_position.x - start.x, scout.global_position.z - start.z).dot(nose)
		max_forward = maxf(max_forward, along)
		if mover._kturn_left_m <= 0.0:
			ended = true
			behind_at_end = -along
			break
	var out := {"speed": speed_at_start, "ended": ended, "behind": behind_at_end, "rolled": max_forward}
	lab.dispose()
	BrainSwitches.native = was_native
	Movement._off = was_off
	return out


func test_a_scout_rolling_forward_backs_its_planned_leg() -> void:
	var on := await _rolling_leg(true)
	var off := await _rolling_leg(false)
	print("MEASURE h2_kturn_arc scout 3.5 m reverse leg started at %.1f m/s forward: signed arc ended %.2f m behind the leg's start (rolled out %.2f m) | chord ended %.2f m behind (rolled %.2f)" % [
			on["speed"], on["behind"], on["rolled"], off["behind"], off["rolled"]])
	assert_true(on["speed"] >= 8.0, "setup: the leg starts with the scout rolling forward at speed (%.1f m/s)" % on["speed"])
	assert_true(on["rolled"] >= 0.5, "setup: it rolls out forward before reversing (%.2f m)" % on["rolled"])
	assert_true(on["ended"], "the leg ended")
	assert_true(on["behind"] >= 3.5 - 1.0, "the signed arc ends the leg with the hull backed its 3.5 m (%.2f m behind the start)" % on["behind"])
