extends TestCase
## Round 36 (manoeuvre S1, C36.3): the pinch stage shared by test_manoeuvre_stall_net*.gd. No tests here.
##
## X1(d)'s choke wedge (references/round35/manoeuvre/x1d-trace): law-716 Green_Guns_7 (law_tank) pressed at full throttle
## into the gap between two parked friends of ANOTHER element (Hunters_2, Hunters_6: law_ifv). Wedged there its real speed
## read 0.1–0.6 m/s, except ONE tick about once a second that read 8.5–9.9 m/s as the contact popped (net <= 0.1 m in
## 10 s); today's stall rule zeroed its clock on that tick (0.73–0.99 s each time) and H1's escape never started in ~50 s.
##
## The stage builds the wedge physically: the two friends park nose-in as a funnel (FUNNEL_YAW each) with GAP_M between
## their inner sides at their centres, narrower at the front than the law_tank is wide; the law_tank starts BEHIND_M short
## of the mouth and is sent PAST_M beyond it. Its whole execute step runs (`compute_command`: route, the stall rule, H1's
## escape); the friends' controllers are off, so they never move or answer an ask. ORCA is off for the run
## (Movement.avoidance_on, restored after), so the hull presses at pace 1 as the traced crew did (ORCA alone stops a hull
## short of the mouth; that hull is W1c's case, not this one).
##
## **The pop is injected.** Jolt brings a lab hull wedged this way to a clean stop (real 0.00 every tick; laptop runs on
## 60a2dbc5c + stallnet: gaps 2.2–4.0 m, funnels 0–0.3 rad, a plug ahead, goals off-axis), so the live contact's pop does
## not arise here. From the first wedged tick, every POP_EVERY ticks the hull's `real_velocity` (what both paths' stall rule
## reads on the honest path) is set to POP_MPS along its nose for that one tick: the traced signal, at a cadence that keeps
## today's clock below STUCK_SECONDS. Position is untouched (net motion 0, as traced).

## The base never fires in this long (the X1(d) trace: ~50 s with no escape); the ON arm must within FIRE_BY_S of wedging.
const SECONDS := 20.0
const FIRE_BY_S := 3.0
const UNIT := "law_tank"
const FRIEND := "law_ifv"
const GAP_M := 3.4
const FUNNEL_YAW := 0.2
const BEHIND_M := 2.0
const PAST_M := 30.0
## 26 ticks = 0.87 s: today's clock reaches 25 / 30 = 0.83 s and is zeroed, as traced (0.73–0.99 s).
const POP_EVERY := 26
const POP_MPS := 9.0
## One run per (arm, path): deterministic, so tests share them.
static var _runs := {}


static func _controller_of(lab: TacticsLab, tank: Tank) -> OrderController:
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == tank:
			return child
	return null


## The arm list: stallnet ON or OFF whatever the tree's default, every other switch as the tree has it.
static func arm(on: bool) -> PackedStringArray:
	return PackedStringArray([]) if on == Movement.STALL_NET_DEFAULT else PackedStringArray(["stallnet"])


## The native drive runs only with `Movement._off` empty: on the native path only the tree's default arm exists.
static func native_arm() -> bool:
	return Movement.STALL_NET_DEFAULT


func pinch(on: bool, native: bool, pop_every := POP_EVERY, trace := false) -> Dictionary:
	var key := "%s/%s/%d" % [on, native, pop_every]
	if not _runs.has(key) or trace:
		_runs[key] = await _run(on, native, pop_every, trace)
	return _runs[key]


func _run(on: bool, native: bool, pop_every: int, trace: bool) -> Dictionary:
	var was_native := BrainSwitches.native
	var was_off := Movement._off
	var was_avoid := Movement.avoidance_on
	Movement._off = arm(on)
	Movement._off_parsed = true
	BrainSwitches.native = native
	Movement.reset_escape_arms()
	var lab := TacticsLab.create(self, 36)
	var x := TacticsScenarios.LANE_X
	var half := float(Movement.hull_box(FRIEND)[0]) * 0.5 + GAP_M * 0.5
	var flen := float(Movement.hull_box(FRIEND)[2])
	var mlen := float(Movement.hull_box(UNIT)[2])
	var left := lab.gun(Match.Team.GREEN, "Green_Hunters_2", Vector3(x - half, 0, 0), -FUNNEL_YAW, FRIEND)
	var right := lab.gun(Match.Team.GREEN, "Green_Hunters_6", Vector3(x + half, 0, 0), FUNNEL_YAW, FRIEND)
	var tank := lab.gun(Match.Team.GREEN, "Green_Guns_7", Vector3(x, 0, flen * 0.5 + mlen * 0.5 + BEHIND_M), 0.0, UNIT)
	var parked: Array[Tank] = [left, right]
	await lab.start()
	for each in parked:
		_controller_of(lab, each).set_physics_process(false)
	var ctl := _controller_of(lab, tank)
	ctl.set_physics_process(false)
	var goal := Vector3(x, 0, -flen * 0.5 - PAST_M)
	assert_eq(ctl.set_orders({"type": "move_to", "x": goal.x, "z": goal.z}, {"type": "hold_fire"}), "", "the pinched hull told to move")
	var mover := ctl.movement
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var fires_before := Movement.esc_fires_hull
	var unstick_before := mover.unstick_fires
	var holds_before := Movement.stall_net_holds
	var wedged_at := -1.0
	var wedged_tick := -1
	var first_fire := -1.0
	var pops := 0
	var max_clock := 0.0
	var blockers := {}
	Movement.avoidance_on = false
	for tick in int(SimClock.TICK_RATE * SECONDS):
		var t := tick * delta
		var fast := tank.real_velocity.length() >= Movement.STUCK_SPEED
		if wedged_tick < 0 and t > 0.3 and not fast:
			wedged_tick = tick
			wedged_at = t
		if wedged_tick >= 0 and pop_every > 0 and (tick - wedged_tick) % pop_every == pop_every - 1 and not fast:
			tank.real_velocity = -tank.global_basis.z * POP_MPS
			pops += 1
		mover.observe_contact()
		var cmd := ctl.compute_command(delta)
		tank.command = cmd
		for each in parked:
			each.command = TankCommand.new(0.0, 0.0, each.global_position + Vector3(0, 0, -20))
		if first_fire < 0.0 and (Movement.esc_fires_hull > fires_before or mover.unstick_fires > unstick_before):
			first_fire = t
		max_clock = maxf(max_clock, mover._stuck_time)
		if wedged_tick >= 0 and first_fire < 0.0:
			var pin: Object = mover._honest_blocker(ctl.move_order) if Movement.unstick_back_on() else null
			var label := "none" if pin == null else ("terrain" if pin == tank else String((pin as Node).name))
			blockers[label] = int(blockers.get(label, 0)) + 1
		if trace and tick % 3 == 0:
			print("STALL_NET_STAGE t %.2f thr %.2f turn %.2f pace %.2f phase %s real %.2f est %.2f stuck %.2f esc %d at %.2f %.2f" % [
					t, cmd.throttle, cmd.turn, mover.pace_now, mover.phase, tank.real_velocity.length(),
					tank.estimated_velocity.length(), mover._stuck_time, mover._esc_stage, tank.global_position.x,
					tank.global_position.z])
		await lab.step()
	Movement.avoidance_on = was_avoid
	var out := {"wedged_at": wedged_at, "first_fire": first_fire,
			"fire_after": first_fire - wedged_at if first_fire >= 0.0 else -1.0,
			"fires": mover.unstick_fires - unstick_before,  # every fire (H1's escape counts here too)
			"fires_hull": Movement.esc_fires_hull - fires_before, "holds": Movement.stall_net_holds - holds_before,
			"pops": pops, "max_clock": max_clock, "blockers": blockers, "path": "native" if native else "gdscript"}
	lab.dispose()
	BrainSwitches.native = was_native
	Movement._off = was_off
	return out


func report(label: String, now: Dictionary, base: Dictionary) -> void:
	print("MEASURE stall_net %s: ON wedged %.2f s, first fire %.2f s after (fires %d, hull %d), holds %d, pops %d, max clock %.2f, pinned on %s | base: first fire %.2f s after, fires %d, pops %d, max clock %.2f, pinned on %s" % [
			label, now["wedged_at"], now["fire_after"], now["fires"], now["fires_hull"], now["holds"], now["pops"],
			now["max_clock"], now["blockers"], base["fire_after"], base["fires"], base["pops"], base["max_clock"],
			base["blockers"]])
