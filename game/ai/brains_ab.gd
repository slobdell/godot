class_name BrainsAB
extends Node
## Round 16 (brains): the in-fight A/B of make ai-perf AB=1 for ANY run: a headless match, the skirmish he plays.
## `--brains-ab-run` (all switches) or `--brains-ab-run=<BrainSwitches name>` flips the round's switches every AB_BLOCK
## physics ticks and charges each tick's controller band (process_physics_priority -10: every OrderController and
## TankBrain) to its arm, in this thread's CPU time (/proc/thread-self/schedstat) and in wall time. The switches are
## equalities, so the run is the same run with or without the A/B: its MATCH_RESULT state hash must equal a run
## without the flag (that is the proof), and both arms share whatever load the machine has.
## Prints BRAINS_AB at exit. (scenario_perf's own `--brains-ab` is the same idea inside that test's loop.) Measurement only: reads the clock, decides nothing.

const AB_BLOCK := 30

static var _installed_for := 0
static var _cpu := [0, 0]
static var _wall := [0, 0]
static var _ticks := [0, 0]
static var _which := ""

var opening := true
var _cpu_start := 0
var _wall_start := 0
var _arm := 0


## Called by every OrderController on _ready; installs the two probes once per parent (the brains' container).
static func ensure(parent: Node) -> void:
	if parent == null or _installed_for == parent.get_instance_id():
		return
	var which := requested()
	if which == "":
		return
	_installed_for = parent.get_instance_id()
	_which = which
	_cpu = [0, 0]
	_wall = [0, 0]
	_ticks = [0, 0]
	for opening_probe in [true, false]:
		var probe := BrainsAB.new()
		probe.opening = opening_probe
		probe.name = "BrainsABOpen" if opening_probe else "BrainsABClose"
		probe.process_physics_priority = -11 if opening_probe else -9
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
	if opening:
		_arm = int(Engine.get_physics_frames() / AB_BLOCK) % 2  # 0 = the round's changes ON, 1 = OFF
		if _which == "all":
			BrainSwitches.set_all(_arm == 0)
		else:
			BrainSwitches.set_named(_which, _arm == 0)
		_cpu_start = _thread_cpu_usec()
		_wall_start = Time.get_ticks_usec()
		var closing := get_parent().get_node_or_null("BrainsABClose") as BrainsAB
		if closing != null:
			closing._arm = _arm
			closing._cpu_start = _cpu_start
			closing._wall_start = _wall_start
	else:
		_cpu[_arm] += _thread_cpu_usec() - _cpu_start
		_wall[_arm] += Time.get_ticks_usec() - _wall_start
		_ticks[_arm] += 1


func _exit_tree() -> void:
	if opening or _ticks[0] + _ticks[1] == 0:
		return
	BrainSwitches.set_all(true)
	var on_cpu := float(_cpu[0]) / maxi(_ticks[0], 1)
	var off_cpu := float(_cpu[1]) / maxi(_ticks[1], 1)
	print("BRAINS_AB %s: controller band cpu ON %.0f usec/tick (%d ticks), OFF %.0f usec/tick (%d ticks): %.1f%% saved; wall ON %.0f OFF %.0f; %d-tick blocks in one run" % [
			_which, on_cpu, _ticks[0], off_cpu, _ticks[1], 100.0 * (off_cpu - on_cpu) / maxf(off_cpu, 1.0),
			float(_wall[0]) / maxi(_ticks[0], 1), float(_wall[1]) / maxi(_ticks[1], 1), AB_BLOCK])
