extends TestCase
## Round 32 (manoeuvre H1b, C32.2): the parked-squadmate stage shared by test_manoeuvre_h1b.gd and
## test_manoeuvre_h1b_guard.gd (split for C32.8: the stage runs about real time). No tests here.
##
## The pinned hull's whole execute step runs (`compute_command`: the route, avoidance, the stall rule) on the GDScript
## path; the friend's controller is off, so it is a squadmate that never moves.

## Base fires about every 5.3 s (2.1, 7.4, 12.6, 17.9 s ...) and H1b settles at 13.7 s (builder0, 373de208): 30 s
## holds five base fires and the settle, and the last STILL_SECONDS are the "sits still" window. The file runs about
## real time (162 s at 40 s a run), so the IFV guard is its own file (test_manoeuvre_h1b_guard.gd, C32.8).
const SECONDS := 30.0
const STILL_SECONDS := 12.0
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
## `stall`: manoeuvre W1c's `stallintent` (round 35), pinned whatever the tree's default; false = the behaviour H1b's tests were
## written for (avoidance's crawl against the parked squadmate hides the stall from unstick).
func _parked(on: bool, unit_id: String, behind: float, past: float, seconds := SECONDS, stall := false) -> Dictionary:
	var key := "%s/%s/%.1f/%.1f/%.0f/%s" % [on, unit_id, behind, past, seconds, stall]
	if not _runs.has(key):
		_runs[key] = await _run_parked(on, unit_id, behind, past, seconds, stall)
	return _runs[key]


func _run_parked(on: bool, unit_id: String, behind: float, past: float, seconds: float, stall := false) -> Dictionary:
	var was_native := BrainSwitches.native
	var was_off := _arms(["unstickback"] if not Movement.UNSTICK_BACK_DEFAULT else [])
	if on != Movement.H1B_DEFAULT:
		Movement._off.append("h1b")
	if stall != Manoeuvre.STALL_INTENT_DEFAULT:
		Movement._off.append("stallintent")
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
	for tick in int(SimClock.TICK_RATE * seconds):
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
		if t >= seconds - STILL_SECONDS:
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


