extends TestCase
## Round 36 (manoeuvre S2a, `h1bside`): the far-loop stage shared by test_manoeuvre_h1b_side*.gd. No tests here.
##
## X4b (references/round36/manoeuvre/x4b): 10 of the 17 crews left behind and still at the judge loop H1's escape nose-on to a
## friend that will not give way again (it gave way once, or to T9's cap, and could not clear them): ask, stand, back ~2 m,
## re-drive into it, every ~7 s for a minute, H1b's FAR branch (goal beyond H1B_SETTLE_MAX_M) only counting. The stage: the
## asker (UNIT) starts BEHIND_M behind a parked friend (FRIEND, controller off: it never moves or answers) and is sent PAST_M
## beyond it. `walls` more parked friends stand abreast of it: "left" closes the left side (room on the right), "both" makes a
## one-hull street. The asker's whole execute step runs on the chosen path.
## Round 36 (R36.27, the orchestrator's ship condition): `walls` "bank" and "mouth" stand the pair on the Locks' north bank,
## driving east: "bank" with the friend's water side a metre off the canal's rim, the goal past it a little towards the water;
## "mouth" with the friend parked at the central bridge's north mouth and a second friend abreast on its land side, the goal
## past them on the bank. The open side point is then over the water or on the deck, and must not be taken: in "bank" the
## hull goes round on its own bank; in "mouth" it stands.

const SECONDS := 30.0
const STILL_SECONDS := 10.0
const UNIT := "law_tank"
const FRIEND := "law_ifv"
const BEHIND_M := 4.0
const PAST_M := 30.0
## Abreast parked friends stand this far apart side to side (hull to hull): nothing the asker can pass through.
const WALL_GAP_M := 0.4
## The Locks (arenas/locks.json): the canal fills |z| <= CANAL_HALF_M; RIM_THICKNESS (1.2 m) of rim stands outside it; the
## central bridge's deck spans |x| <= DECK_HALF_X, |z| <= DECK_HALF_Z.
const CANAL_HALF_M := 7.0
const DECK_HALF_X := 8.0
const DECK_HALF_Z := 12.0
const BANK_X := 40.0
const EAST := -PI / 2.0  # a yaw facing +x (a hull's forward is -z at yaw 0)
static var _runs := {}


static func _controller_of(lab: TacticsLab, tank: Tank) -> OrderController:
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == tank:
			return child
	return null


static func arm(on: bool) -> PackedStringArray:
	return PackedStringArray([]) if on == Movement.H1B_SIDE_DEFAULT else PackedStringArray(["h1bside"])


static func native_arm() -> bool:
	return Movement.H1B_SIDE_DEFAULT


func far_loop(on: bool, native: bool, walls: String, trace := false) -> Dictionary:
	var key := "%s/%s/%s" % [on, native, walls]
	if not _runs.has(key) or trace:
		_runs[key] = await _run(on, native, walls, trace)
	return _runs[key]


func _run(on: bool, native: bool, walls: String, trace: bool) -> Dictionary:
	var was_native := BrainSwitches.native
	var was_off := Movement._off
	Movement._off = arm(on)
	Movement._off_parsed = true
	BrainSwitches.native = native
	Movement.reset_escape_arms()
	var bank := walls in ["bank", "mouth"]
	var lab := TacticsLab.create(self, 37, "locks" if bank else "")
	var x := TacticsScenarios.LANE_X
	var fw := float(Movement.hull_box(FRIEND)[0])
	var flen := float(Movement.hull_box(FRIEND)[2])
	var mlen := float(Movement.hull_box(UNIT)[2])
	var parked: Array[Tank] = []
	var tank: Tank
	var goal := Vector3(x, 0, -flen * 0.5 - PAST_M)
	var front_z := -flen * 0.5  # the parked friend's nose: the asker is past it when its own tail is beyond
	var front_x := INF
	if bank:
		# East along the north bank. "bank": the friend's water side 1 m off the rim; "mouth": the friend across the bridge's
		# north mouth (its centre on the deck's end line), so its south side point lies on the deck.
		var fx := BANK_X if walls == "bank" else 0.0
		var fz := CANAL_HALF_M + ArenaTerrain.RIM_THICKNESS + 1.0 + fw * 0.5 if walls == "bank" else DECK_HALF_Z + fw * 0.5 + 0.3
		parked.append(lab.gun(Match.Team.GREEN, "Green_Hunters_2", Vector3(fx, 0, fz), EAST, FRIEND))
		if walls == "mouth":  # a second friend abreast on the land side: the deck is the only open side
			parked.append(lab.gun(Match.Team.GREEN, "Green_Hunters_3", Vector3(fx, 0, fz + fw + WALL_GAP_M), EAST, FRIEND))
		tank = lab.gun(Match.Team.GREEN, "Green_Guns_7", Vector3(fx - flen * 0.5 - mlen * 0.5 - BEHIND_M, 0, fz), EAST, UNIT)
		goal = Vector3(fx + flen * 0.5 + PAST_M, 0, fz - 1.0)
		front_z = -INF
		front_x = fx + flen * 0.5
	else:
		parked.append(lab.gun(Match.Team.GREEN, "Green_Hunters_2", Vector3(x, 0, 0), 0.0, FRIEND))
		if walls in ["left", "both"]:
			parked.append(lab.gun(Match.Team.GREEN, "Green_Hunters_3", Vector3(x - fw - WALL_GAP_M, 0, 0), 0.0, FRIEND))
		if walls == "both":
			parked.append(lab.gun(Match.Team.GREEN, "Green_Hunters_4", Vector3(x + fw + WALL_GAP_M, 0, 0), 0.0, FRIEND))
		tank = lab.gun(Match.Team.GREEN, "Green_Guns_7", Vector3(x, 0, flen * 0.5 + mlen * 0.5 + BEHIND_M), 0.0, UNIT)
	await lab.start()
	for each in parked:
		_controller_of(lab, each).set_physics_process(false)
	var ctl := _controller_of(lab, tank)
	ctl.set_physics_process(false)
	assert_eq(ctl.set_orders({"type": "move_to", "x": goal.x, "z": goal.z}, {"type": "hold_fire"}), "", "the asker told to move")
	var mover := ctl.movement
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var fires_before := mover.unstick_fires
	var far_before := ManoeuvreCensus.h1b_far
	var steps_before := ManoeuvreCensus.h1b_side_steps
	var stands_before := ManoeuvreCensus.h1b_side_stands
	var fire_times: Array = []
	var first_far := -1.0
	var past_at := -1.0
	var mark := Vector3.INF
	var pressing_late := 0
	var side_points: Array = []  # every side point taken: [x, z]
	var min_z := INF  # the asker's least z (bank cases: how near the canal it came)
	var on_deck_ticks := 0
	for tick in int(SimClock.TICK_RATE * SECONDS):
		var t := tick * delta
		mover.observe_contact()
		var cmd := ctl.compute_command(delta)
		tank.command = cmd
		for each in parked:
			each.command = TankCommand.new(0.0, 0.0, each.global_position + Vector3(0, 0, -20))
		if mover.unstick_fires > fires_before + fire_times.size():
			fire_times.append(snappedf(t, 0.1))
		if first_far < 0.0 and ManoeuvreCensus.h1b_far > far_before:
			first_far = t
		var at := tank.global_position
		if past_at < 0.0 and (at.z + mlen * 0.5 < front_z or at.x - mlen * 0.5 > front_x):
			past_at = t
		if mover._side_to != Vector3.INF and (side_points.is_empty() or Vector2(side_points[-1][0], side_points[-1][1]).distance_to(Vector2(mover._side_to.x, mover._side_to.z)) > 0.01):
			side_points.append([snappedf(mover._side_to.x, 0.01), snappedf(mover._side_to.z, 0.01)])
		min_z = minf(min_z, at.z)
		if absf(at.x) <= DECK_HALF_X and absf(at.z) <= DECK_HALF_Z:
			on_deck_ticks += 1
		if t >= SECONDS - STILL_SECONDS:
			if mark == Vector3.INF:
				mark = tank.global_position
			if cmd.throttle > 0.5:
				pressing_late += 1
		if trace and tick % 6 == 0:
			print("H1B_SIDE_STAGE t %.1f thr %.2f turn %.2f phase %s esc %d at %.2f %.2f stuck %.2f" % [t, cmd.throttle, cmd.turn,
					mover.phase, mover._esc_stage, tank.global_position.x, tank.global_position.z, mover._stuck_time])
		await lab.step()
	var fires_after_far := 0
	for f: float in fire_times:
		if first_far >= 0.0 and f > first_far + 0.05:
			fires_after_far += 1
	var out := {"fires": fire_times.size(), "fire_times": fire_times, "first_far": first_far, "fires_after_far": fires_after_far,
			"past_at": past_at, "late_moved_m": Vector2(tank.global_position.x - mark.x, tank.global_position.z - mark.z).length(),
			"pressing_late": pressing_late, "far": ManoeuvreCensus.h1b_far - far_before,
			"steps": ManoeuvreCensus.h1b_side_steps - steps_before, "stands": ManoeuvreCensus.h1b_side_stands - stands_before,
			"at": [snappedf(tank.global_position.x, 0.01), snappedf(tank.global_position.z, 0.01)],
			"side_points": side_points, "min_z": snappedf(min_z, 0.01), "on_deck_ticks": on_deck_ticks}
	lab.dispose()
	BrainSwitches.native = was_native
	Movement._off = was_off
	return out


func report(label: String, now: Dictionary, base: Dictionary) -> void:
	print("MEASURE h1b_side %s: ON fires %d at %s, first far %.1f s, fires after %d, past at %.1f s, steps %d, stands %d, late moved %.2f m, pressing late %d, at %s, side points %s, min z %.2f, deck ticks %d | base: fires %d at %s, past at %.1f s, at %s" % [
			label, now["fires"], now["fire_times"], now["first_far"], now["fires_after_far"], now["past_at"], now["steps"],
			now["stands"], now["late_moved_m"], now["pressing_late"], now["at"], now["side_points"], now["min_z"],
			now["on_deck_ticks"], base["fires"], base["fire_times"], base["past_at"], base["at"]])
