extends ExecuteTwinCase
## Round 33 (manoeuvre C33.9, native's hand-back): under the turn-in a `stop` on a fixed gun on wheels runs
## OrderController._stop_turn_in after the gun (gunnery's swing turned in, or held), which the native execute does not
## mirror: it hands that stop back (execute_native.cpp, reason 4, `turn_in_stop`). The stage is manoeuvre's own
## (tests/test_manoeuvre_orbit.gd's stop case): a gang_scout brain circled at 15 m by a syn_scout firing at will. Every
## tick the scout's execute runs from one snapshot: the live GDScript, then the native call on the live members and on
## the C++-owned state. A hand-back must write nothing; an answer must be the live command and state.

const ORBIT_R := 15.0
const LEAD_DEG := 40.0
const SECONDS := 30.0
## builder2's fresh counts halved (n 1): see the run's "turn-in stop" line.
const MIN_TURN_IN_STOPS := 1
const MIN_LIVE_TURN_INS := 1


## The controller's turn-in history (C33.9's members): the twin's extra live call must not move it.
static func _turn_in_state(ctl: OrderController) -> Dictionary:
	var out := {}
	for prop: Dictionary in ctl.get_property_list():
		var name := String(prop["name"])
		if name.begins_with("_turn_in_"):
			out[name] = ctl.get(name)
	return out


func test_a_wheeled_fixed_gun_at_stop_is_handed_back_under_the_turn_in() -> void:
	if FreshStage.parent(self, "test_a_wheeled_fixed_gun_at_stop_is_handed_back_under_the_turn_in"):  # its own process (tests/native/fresh_stage.gd)
		return
	if not NativeBridge.available:
		print("native: absent, the turn-in hand-back is not exercised in this run")
		return
	if not ("TURN_IN_DEFAULT" in (Manoeuvre as Script).get_script_constant_map()) or not Manoeuvre.turn_in_on():
		print("turn-in: off on this tree, the hand-back is not exercised")
		return
	MoverState.world_reset()
	assert_true(NativeGun.configure() and NativeDrive.configure(), "the native drive and gun take the live constants")
	var s := AiScenario.create(self, 14)
	s.game_match.set_meta("player_team", Match.Team.GREEN)
	var dice := RandomNumberGenerator.new()
	dice.seed = 14
	var way := 1.0 if dice.randi() % 2 == 0 else -1.0
	var phase := dice.randf() * TAU
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3.ZERO, dice.randf() * TAU, {}, "gang_scout")
	AiScenario.make_durable(me)
	var enemy := s.shooter(Match.Team.RUST, "Rust_A_1", Vector3(ORBIT_R * cos(phase), 0, ORBIT_R * sin(phase)), PI,
			{"type": "stop"}, {"type": "fire_at_will", "long_shot": true}, "syn_scout")
	AiScenario.make_durable(enemy)
	var orbiter := s.controller_of(enemy)
	await s.start()
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var native := 0
	var handed_back := 0
	var mismatches := 0
	var first := ""
	var stops := 0
	var live_turn_ins := 0
	var was_exec := BrainSwitches.native_exec
	BrainSwitches.native_exec = false
	NativeBridge.impl.execute_counts(true)
	for tick in int(SimClock.TICK_RATE * SECONDS):
		if tick % 5 == 0:
			var at := Vector3(enemy.global_position.x - me.global_position.x, 0.0, enemy.global_position.z - me.global_position.z)
			var ahead := at.normalized().rotated(Vector3.UP, deg_to_rad(LEAD_DEG) * way) * ORBIT_R
			orbiter.set_orders({"type": "move_to", "x": me.global_position.x + ahead.x, "z": me.global_position.z + ahead.z},
					orbiter.weapon_order)
		await s.step()
		var movers: Array[Movement] = []
		for node in s.game_match.tanks.get_children():
			var mover := Movement.of(node)
			if mover != null and mover.ctl != null and mover.ctl.gunnery != null:
				movers.append(mover)
		var ctl := s.controller_of(me)
		if ctl == null or not me.alive or ctl.gunnery == null:
			continue
		if String(ctl.move_order.get("type", "")) == "stop":
			stops += 1
		var history := _turn_in_state(ctl)
		var stop_turn_ins := Manoeuvre.turn_in_stops
		var start := _capture(movers, ctl)
		var live_cmd: TankCommand = ctl.compute_command(delta)
		var live := _capture(movers, ctl)
		live_turn_ins += Manoeuvre.turn_in_stops - stop_turn_ins
		Manoeuvre.turn_in_stops = stop_turn_ins
		for owned in [false, true]:
			_restore(movers, ctl, start)
			for name: String in history:
				ctl.set(name, history[name])
			for each in movers:
				each.native_stale = Movement.STALE_ALL  # the test wrote the members back: a door from outside
			var answer: Variant = NativeBridge.impl.execute(ctl, delta, NativeExec.EXEC_OWNED_VERIFY if owned \
					else NativeExec.EXEC_LIVE)
			var after := _capture(movers, ctl)
			if answer == null:
				handed_back += 1
				var untouched := _diff(start, after)
				if untouched != "":
					mismatches += 1
					if first == "":
						first = "tick %d handed back but wrote: %s" % [tick, untouched]
				continue
			native += 1
			var differ := _diff(live, after)
			if _command(live_cmd) != _command(answer as TankCommand) or differ != "":
				mismatches += 1
				if first == "":
					first = "tick %d (owned %s, move %s): command live %s native %s; %s" % [tick, owned, ctl.move_order,
							_command(live_cmd), _command(answer as TankCommand), differ]
		_restore(movers, ctl, start)
		for name: String in history:
			ctl.set(name, history[name])
		for each in movers:
			each.native_stale = Movement.STALE_ALL
	BrainSwitches.native_exec = was_exec
	var counts: Dictionary = NativeBridge.impl.execute_counts(true)
	print("native execute (turn-in stop): %s" % counts)
	print("native execute (turn-in stop): %d native, %d handed back, %d mismatches; %d stop ticks, %d live stop turn-ins" % [
			native, handed_back, mismatches, stops, live_turn_ins])
	s.dispose()
	assert_eq(mismatches, 0, "the native execute is the live compute_command under the turn-in: %s" % first)
	assert_true(int(counts.get("turn_in_stop", 0)) >= MIN_TURN_IN_STOPS,
			"the stage hands a turn-in stop back (%d)" % int(counts.get("turn_in_stop", 0)))
	assert_true(live_turn_ins >= MIN_LIVE_TURN_INS, "the live arm turned a stop's swing in (%d)" % live_turn_ins)
