extends TestCase
## Round 32, manoeuvre H1b (C32.2, `--nav-off=h1b` = ON, opt-in until judged): **the ask that never frees.** H1 asks
## the friend that pins it, backs off straight and drives the route again. A squadmate parked at its own slot never
## moves for that ask, so the pinned hull looped (Terminus rigs seed 31: Green_S0_4 on Green_S0_2, ask, back 2-3 m,
## drive back in about every 21 s, asks 29, backs 29). H1b: after H1B_ASKS failed asks on the SAME unmoved friend, a
## hull whose goal is within H1B_SETTLE_MAX_M settles where it stands (the goal re-grounded through the repair channel
## the brain completes on) and never re-drives into it.
##
## The pinned hull's whole execute step runs (`compute_command`: the route, avoidance, the stall rule) on the GDScript
## path; the friend's controller is off, so it is a squadmate that never moves.

## Base fires about every 5.3 s and H1b settles by ~14 s (builder0, 373de208): 40 s holds both, and the last 20 s
## are the "sits still" window.
const SECONDS := 40.0
## One run per (arm, hull, geometry): the base arms are shared between tests (deterministic, so identical).
static var _runs := {}


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


## A parked at its slot facing north; B `behind` metres south of it, facing north, sent to a goal `past` metres north
## of A's centre (inside or just beyond A's hull: the slot A sits on). Returns what B did over SECONDS.
func _parked(on: bool, unit_id: String, behind: float, past: float) -> Dictionary:
	var key := "%s/%s/%.1f/%.1f" % [on, unit_id, behind, past]
	if not _runs.has(key):
		_runs[key] = await _run_parked(on, unit_id, behind, past)
	return _runs[key]


func _run_parked(on: bool, unit_id: String, behind: float, past: float) -> Dictionary:
	var was_native := BrainSwitches.native
	var was_off := _arms(["unstickback"] if not Movement.UNSTICK_BACK_DEFAULT else [])
	if on != Movement.H1B_DEFAULT:
		Movement._off.append("h1b")
	BrainSwitches.native = false
	Movement.reset_escape_arms()
	var lab := TacticsLab.create(self, 32)
	var a := lab.gun(Match.Team.GREEN, "Green_A_1", Vector3(TacticsScenarios.LANE_X, 0, 20), 0.0, unit_id)
	var b := lab.gun(Match.Team.GREEN, "Green_A_2", Vector3(TacticsScenarios.LANE_X, 0, 20 + behind), 0.0, unit_id)
	await lab.start()
	_controller_of(lab, a).set_physics_process(false)
	var cb := _controller_of(lab, b)
	cb.set_physics_process(false)
	var goal := a.global_position + Vector3(0, 0, -past)
	assert_eq(cb.set_orders({"type": "move_to", "x": goal.x, "z": goal.z}, {"type": "hold_fire"}), "", "B told to move")
	var mover := cb.movement
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var fires_before := Movement.esc_fires_hull
	var fire_times: Array = []
	var arrived_at := -1.0
	var mark := Vector3.INF
	var last_fire := -1.0
	var pressing_late := 0
	var reverse_after_settle := 0
	for tick in int(SimClock.TICK_RATE * SECONDS):
		mover.observe_contact()
		var cmd := cb.compute_command(delta)
		b.command = cmd
		a.command = TankCommand.new(0.0, 0.0, a.global_position + Vector3(0, 0, -20))
		var t := tick * delta
		if Movement.esc_fires_hull > fires_before + fire_times.size():
			fire_times.append(snappedf(t, 0.1))
			last_fire = t
		if mover.phase == "arrived" and arrived_at < 0.0:
			arrived_at = t
		if arrived_at >= 0.0 and cmd.throttle < -0.1:
			reverse_after_settle += 1
		if t >= SECONDS - 20.0:
			if mark == Vector3.INF:
				mark = b.global_position
			if cmd.throttle > 0.5:
				pressing_late += 1
		await lab.step()
	var out := {"fires": fire_times.size(), "fire_times": fire_times, "last_fire": last_fire, "arrived_at": arrived_at,
			"phase": mover.phase, "repaired": Movement.repaired_arrival(b),
			"repaired_m": float(mover.reading().get("repaired_m", 0.0)), "late_moved_m": Vector2(b.global_position.x - mark.x, b.global_position.z - mark.z).length(),
			"pressing_late": pressing_late, "reverse_after_settle": reverse_after_settle,
			"gap_to_goal": Vector2(b.global_position.x - goal.x, b.global_position.z - goal.z).length(),
			"arms": Movement.escape_arms(), "h1b": ManoeuvreCensus.h1b_report()}
	lab.dispose()
	BrainSwitches.native = was_native
	Movement._off = was_off
	return out


func _report(label: String, now: Dictionary, base: Dictionary) -> void:
	print("MEASURE h1b %s: fires %d at %s, arrived at %.1f s (repaired %s, %.1f m short), late moved %.2f m, pressing late %d, reverse after settle %d, h1b %s | base: fires %d at %s, phase %s, late moved %.2f m, pressing late %d" % [
			label, now["fires"], now["fire_times"], now["arrived_at"], now["repaired"], now["repaired_m"], now["late_moved_m"],
			now["pressing_late"], now["reverse_after_settle"], now["h1b"], base["fires"], base["fire_times"], base["phase"],
			base["late_moved_m"], base["pressing_late"]])


## Seed 31's shape: a War Rig sent to a slot a parked squadmate sits on. Base loops (the defect); H1b settles after two
## failed asks and never fires again.
func test_a_war_rig_behind_a_parked_squadmate_settles_instead_of_looping() -> void:
	var now := await _parked(true, "gang_tank", 18.0, -3.0)
	var base := await _parked(false, "gang_tank", 18.0, -3.0)
	_report("gang_tank on a parked squadmate", now, base)
	assert_true(base["fires"] > Movement.H1B_ASKS + 1, "setup: base loops on the parked friend (%d fires at %s)" % [base["fires"], base["fire_times"]])
	assert_true(now["fires"] <= Movement.H1B_ASKS + 1, "H1b: at most %d fires, then it stops (%d at %s)" % [Movement.H1B_ASKS + 1, now["fires"], now["fire_times"]])
	assert_true(now["repaired"] and now["phase"] == "arrived", "it settled where it stands, the order completable (phase %s, repaired %s)" % [now["phase"], now["repaired"]])
	assert_true(now["late_moved_m"] < 0.5 and now["pressing_late"] == 0, "and sits still (moved %.2f m, pressing %d ticks in the last 20 s)" % [now["late_moved_m"], now["pressing_late"]])
	assert_eq(int((now["h1b"] as Dictionary)["settles"]), 1, "one settle")
	assert_eq(int((now["h1b"] as Dictionary)["loops"]), 0, "and no loop left (base: %d)" % int((base["h1b"] as Dictionary)["loops"]))


## No loop, nothing to do: an IFV short of a parked squadmate is held still by avoidance (phase blocked, never pressing,
## the stall rule never fires; builder0, first run of this test), so H1b never acts and the hull does what base does.
func test_an_ifv_held_off_a_parked_squadmate_is_left_alone() -> void:
	var now := await _parked(true, "ifv", 11.0, -1.0)
	var base := await _parked(false, "ifv", 11.0, -1.0)
	_report("ifv held off a parked squadmate", now, base)
	assert_eq(base["fires"], 0, "setup: avoidance holds the IFV off, no escape fires at base")
	assert_eq(now["fires"], 0, "none with H1b either")
	assert_eq(int((now["h1b"] as Dictionary)["settles"]), 0, "H1b never settles a hull that is not looping")
	assert_eq(now["phase"], base["phase"], "the same phase as base (%s)" % now["phase"])
	assert_true(absf(float(now["gap_to_goal"]) - float(base["gap_to_goal"])) < 0.05, "the same place (%.2f v %.2f m)" % [now["gap_to_goal"], base["gap_to_goal"]])


## Switched off, H1b never acts (round 31's escape bit for bit); its bookkeeping still counts the loops, which is the
## base arm's number for the bar.
func test_switched_off_h1b_never_acts_and_counts_the_loops() -> void:
	var base := await _parked(false, "gang_tank", 18.0, -3.0)
	var counts: Dictionary = base["h1b"]
	assert_eq(int(counts["settles"]) + int(counts["far"]), 0, "H1b never acts with the switch off (%s)" % counts)
	# Fire 1 starts the count, fires 2 and 3 are the two failed asks; from fire 3 on (where H1b would settle) each is a loop.
	assert_eq(int(counts["loops"]), int(base["fires"]) - Movement.H1B_ASKS,
			"every fire from the second failed ask on is a loop (%s, fires %d)" % [counts, base["fires"]])
	assert_true(not base["repaired"], "nothing re-grounded the goal")
