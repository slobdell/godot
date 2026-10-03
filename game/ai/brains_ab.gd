class_name BrainsAB
extends Node
## Round 16 (brains): the in-fight A/B of make ai-perf AB=1 for ANY run: a headless match, the skirmish he plays.
## `--brains-ab-run` (all switches) or `--brains-ab-run=<BrainSwitches name>` flips the round's switches every AB_BLOCK
## physics ticks and charges each tick's controller band (process_physics_priority -10: every OrderController and
## TankBrain) to its arm, in this thread's CPU time (/proc/thread-self/schedstat) and in wall time. The switches are
## equalities, so the run is the same run with or without the A/B: its MATCH_RESULT state hash must equal a run
## without the flag (that is the proof), and both arms share whatever load the machine has.
## Prints BRAINS_AB at exit (scenario_perf's own `--brains-ab` is the same idea inside that test's loop).
## Measurement only: reads the clock, decides nothing.

const AB_BLOCK := 30

static var _installed_for := 0
static var _cpu := [0, 0]
static var _wall := [0, 0]
static var _ticks := [0, 0]
## The whole physics tick's scripts (every _physics_process: elements and commanders at -30..-15, the band, tanks,
## Match, shells), per arm: changes outside the band (the element leaders' slot grounding) show here.
static var _tick_cpu := [0, 0]
static var _which := ""
## `--brains-parts`: the brains' detailed laps and call counts (OrderController.add_part: think / execute / move /
## weapon, nav.*, nav.closest@<site>, los.*, avoid.*) printed at exit as BRAINS_PARTS, per controller-band tick. The
## same parts `make sim-profile` reports as brain/* sections, for runs SimProfile does not reach (his skirmish).
static var _parts := false
static var _arm := 0
static var _band_start := 0
static var _band_wall := 0
static var _tick_start := 0

## 0 opens the tick (and flips the switches, before anything in the tick runs), 1 opens the band, 2 closes it,
## 3 closes the tick.
const ROLES := [[-100001, "BrainsABTickOpen"], [-11, "BrainsABOpen"], [-9, "BrainsABClose"], [100001, "BrainsABTickClose"]]
var role := 0


## Called by every OrderController on _ready; installs the probes once per parent (the brains' container).
static func ensure(parent: Node) -> void:
	if parent == null or _installed_for == parent.get_instance_id():
		return
	var which := requested()
	var parts := OS.get_cmdline_user_args().has("--brains-parts")
	if which == "" and not parts:
		return
	_installed_for = parent.get_instance_id()
	_which = which
	_parts = parts
	if parts:
		OrderController.profiling = true
		OrderController.profile_detail = true
		TankBrain.profile_parts = {}
		TankBrain.profile_calls = {}
	_cpu = [0, 0]
	_wall = [0, 0]
	_ticks = [0, 0]
	_tick_cpu = [0, 0]
	for index in ROLES.size():
		var probe := BrainsAB.new()
		probe.role = index
		probe.name = ROLES[index][1]
		probe.process_physics_priority = ROLES[index][0]
		parent.add_child.call_deferred(probe)


## "" (off), "all", or one BrainSwitches name.
static func requested() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg == "--brains-ab-run":
			return "all"
		if arg.begins_with("--brains-ab-run="):
			return arg.trim_prefix("--brains-ab-run=")
	return ""


static func _thread_cpu_usec() -> int:
	var file := FileAccess.open("/proc/thread-self/schedstat", FileAccess.READ)
	if file == null:
		return 0
	return int(file.get_line().get_slice(" ", 0)) / 1000


func _physics_process(_delta: float) -> void:
	match role:
		0:
			_arm = int(Engine.get_physics_frames() / AB_BLOCK) % 2  # 0 = the round's changes ON, 1 = OFF
			if _which == "all":
				BrainSwitches.set_all(_arm == 0)
			elif _which != "":
				BrainSwitches.set_named(_which, _arm == 0)
			_tick_start = _thread_cpu_usec()
		1:
			_band_start = _thread_cpu_usec()
			_band_wall = Time.get_ticks_usec()
		2:
			_cpu[_arm] += _thread_cpu_usec() - _band_start
			_wall[_arm] += Time.get_ticks_usec() - _band_wall
			_ticks[_arm] += 1
		3:
			_tick_cpu[_arm] += _thread_cpu_usec() - _tick_start


func _exit_tree() -> void:
	if role != 2 or _ticks[0] + _ticks[1] == 0:
		return
	if _parts:
		var ticks := float(_ticks[0] + _ticks[1])
		var table := {}
		for part: String in TankBrain.profile_parts:
			table[part] = [snappedf(float(TankBrain.profile_parts[part]) / ticks / 1000.0, 0.001),
					snappedf(float(TankBrain.profile_calls.get(part, 0)) / ticks, 0.01)]
		print("BRAINS_PARTS %d ticks, [ms, calls] per tick: %s" % [int(ticks), JSON.stringify(table)])
	if _which == "":
		return
	BrainSwitches.set_all(true)
	var on_cpu := float(_cpu[0]) / maxi(_ticks[0], 1)
	var off_cpu := float(_cpu[1]) / maxi(_ticks[1], 1)
	var on_tick := float(_tick_cpu[0]) / maxi(_ticks[0], 1)
	var off_tick := float(_tick_cpu[1]) / maxi(_ticks[1], 1)
	print(("BRAINS_AB %s: controller band cpu ON %.0f usec/tick (%d ticks), OFF %.0f usec/tick (%d ticks): %.1f%% saved; "
			+ "whole tick's scripts cpu ON %.0f OFF %.0f: %.1f%% saved; band wall ON %.0f OFF %.0f; %d-tick blocks in one run") % [
			_which, on_cpu, _ticks[0], off_cpu, _ticks[1], 100.0 * (off_cpu - on_cpu) / maxf(off_cpu, 1.0),
			on_tick, off_tick, 100.0 * (off_tick - on_tick) / maxf(off_tick, 1.0),
			float(_wall[0]) / maxi(_ticks[0], 1), float(_wall[1]) / maxi(_ticks[1], 1), AB_BLOCK])
