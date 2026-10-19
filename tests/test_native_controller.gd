extends TestCase
## Round 28 (native N7.3a): OrderController._physics_process natively (NativeController -> controller_native.cpp)
## against the LIVE GDScript, branch by branch. A probe brain (TankBrain with think, compute_command and wants_to_run
## recording their calls, and a Movement recording observe_contact) on a real hull, from one seeded start state both
## ways: the stride (1 or 3), a last command or none, the last run tick, the think offset, wants_to_run's answer, and
## the measurement statics (SimProfile on or off, so profiling / profile_detail follow it; the stride census; BrainsAB's
## split charging). Compared: the calls and their deltas, which command the hull got and what was kept, _step and
## _last_run_tick, the executed_full / executed_held counts, the parts counted, the census and the split charge.
## The whole-match proof is native-proof's `controller` arm (and with --quiet-stride=3 for the hold on a live match).

const MATCH := preload("res://game/match/match.tscn")
const SCENARIOS := 600


class ContactProbe:
	extends Movement
	var calls := 0

	func observe_contact() -> void:
		calls += 1


class ProbeBrain:
	extends TankBrain
	var calls: Array = []
	var run_wanted := false

	func think(delta: float) -> void:
		calls.append(["think", delta])
		_tick_over()

	func compute_command(delta: float) -> TankCommand:
		calls.append(["execute", delta])
		_tick_over()
		return TankCommand.new(delta, -delta, Vector3(delta, 0, 0), false)

	func wants_to_run() -> bool:
		calls.append(["wants"])
		_tick_over()
		return run_wanted

	## Wait for the microsecond clock to advance. Every span the controller charges (profile_usec, the parts, BrainsAB's
	## split) then covers at least 1 µs on either side. Without it, a fast core (builder2's Zen 5) sometimes finishes
	## the GDScript held tick inside one microsecond and charges 0 while the native one charges 1: the twin was reading
	## timer granularity, not the controller (round 33, d99394f1 on builder2: 7 of 600, `profile_usec > 0` only).
	static func _tick_over() -> void:
		var at := Time.get_ticks_usec()
		while Time.get_ticks_usec() == at:
			pass


static func _statics() -> Array:
	return [OrderController.profiling, OrderController.profile_detail, OrderController._sim_profiled,
			OrderController.executed_full, OrderController.executed_held, TankBrain.stride_skips.duplicate(),
			int(TankBrain.profile_calls.get("think", 0)), int(TankBrain.profile_calls.get("execute", 0)),
			int(TankBrain.profile_calls.get("c.wall_contact", 0))]


func _run(brain: ProbeBrain, contact: ContactProbe, held: TankCommand, start: Dictionary, native: bool) -> Array:
	brain.calls = []
	contact.calls = 0
	brain._stride = start["stride"]
	brain._last_command = held if start["has_last"] else null
	brain._last_run_tick = start["last_run_tick"]
	brain._step = 7
	brain.think_offset = start["offset"]
	brain.run_wanted = start["wants"]
	brain.game_match.tick = start["tick"]
	brain.tank.command = TankCommand.new()
	SimProfile.enabled = start["sim"]
	OrderController._sim_profiled = start["was_sim"]
	OrderController.profiling = start["was_sim"]
	OrderController.profile_detail = start["was_sim"]
	OrderController.executed_full = 0
	OrderController.executed_held = 0
	OrderController.profile_usec = 0
	TankBrain.census = start["census"]
	TankBrain.stride_skips = [0, 0]
	TankBrain.profile_calls = {}
	TankBrain.profile_parts = {}
	BrainsAB.split_on = start["split"]
	BrainsAB._charging = start["split"]
	BrainsAB._phase = 1
	BrainsAB._per_unit = {}
	BrainSwitches.native_controller = native
	brain._physics_process(start["delta"])
	BrainSwitches.native_controller = false
	var command := brain.tank.command
	var kept := "other"
	if command == held:
		kept = "held"
	elif command != null and not brain.calls.is_empty() and brain.calls[-1][0] == "execute" \
			and command.throttle == float(brain.calls[-1][1]):
		kept = "new"  # the command compute_command made this tick
	var per_unit: Array = BrainsAB._per_unit.get(String(brain.tank.name), [0, 0, 0, 0])
	return [brain.calls.duplicate(), contact.calls, kept, brain._last_command == command, brain._step, brain._last_run_tick,
			_statics(), OrderController.profile_usec > 0, [per_unit[1], per_unit[3]]]


func test_the_controller_tick_is_the_live_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the controller tick equality is not exercised in this run")
		return
	assert_true(NativeController.configure(), "the native controller tick takes its scripts")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	await wait_physics_frames(1)
	var tank := game_match.spawn_tank("Probe", 0, Match.Team.GREEN, "tank")
	await wait_physics_frames(1)
	var brain := ProbeBrain.new()
	brain.tank = tank
	brain.game_match = game_match
	var contact := ContactProbe.new(brain)
	brain.movement = contact
	var held := TankCommand.new(0.5, 0.25, Vector3(1, 2, 3), true)
	var saved := [SimProfile.enabled, OrderController._sim_profiled, OrderController.profiling,
			OrderController.profile_detail, TankBrain.census, TankBrain.stride_skips, BrainsAB.split_on,
			BrainsAB._charging, BrainsAB._phase, BrainsAB._per_unit, TankBrain.profile_calls, TankBrain.profile_parts,
			BrainSwitches.native_controller]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2873
	var mismatches := 0
	var first := ""
	var seen := {}
	for n in SCENARIOS:
		var tick := rng.randi_range(0, 5000)
		var start := {"stride": [1, 3, 3, 4][rng.randi_range(0, 3)], "has_last": rng.randf() < 0.85,
				"last_run_tick": [-1, tick - 1, tick - 2, tick - 9][rng.randi_range(0, 3)], "offset": rng.randi_range(0, 3),
				"wants": rng.randf() < 0.3, "tick": tick, "sim": rng.randf() < 0.4, "was_sim": rng.randf() < 0.4,
				"census": rng.randf() < 0.5, "split": rng.randf() < 0.3, "delta": [1.0 / 30.0, 0.05][rng.randi_range(0, 1)]}
		var live := _run(brain, contact, held, start, false)
		var native := _run(brain, contact, held, start, true)
		seen[live[2]] = int(seen.get(live[2], 0)) + 1
		if live != native:
			mismatches += 1
			if first == "":
				first = "start %s: live %s native %s" % [start, live, native]
	BrainSwitches.native_controller = saved[12]
	SimProfile.enabled = saved[0]
	OrderController._sim_profiled = saved[1]
	OrderController.profiling = saved[2]
	OrderController.profile_detail = saved[3]
	TankBrain.census = saved[4]
	TankBrain.stride_skips = saved[5]
	BrainsAB.split_on = saved[6]
	BrainsAB._charging = saved[7]
	BrainsAB._phase = saved[8]
	BrainsAB._per_unit = saved[9]
	TankBrain.profile_calls = saved[10]
	TankBrain.profile_parts = saved[11]
	brain.free()
	print("native controller tick: %d scenarios, outcomes %s, %d mismatches" % [SCENARIOS, seen, mismatches])
	assert_eq(mismatches, 0, "the native controller tick is the live GDScript: %s" % first)
	assert_true(int(seen.get("held", 0)) > 50 and int(seen.get("new", 0)) > 200, "a real sample (%s)" % [seen])
