extends Node
class_name BandProbe
## Measurement only (round-5 X1): brackets the unit-controller band (OrderController and TankBrain run at physics
## priority -10) with two probes at -11 and -9 and adds up what the band costs per tick, in wall time and in this
## thread's CPU time. The CPU time comes from /proc/thread-self/schedstat (nanoseconds this thread actually ran), so it
## does not inflate when other worktrees load the machine the way the wall clock does. Linux only; 0 elsewhere.

static var wall_usec := 0
static var cpu_usec := 0
static var ticks := 0
## Living units summed over the measured ticks: different variants fight different battles, so cost is compared per
## living unit per tick, not per tick.
static var unit_ticks := 0
static var _wall_start := 0
static var _cpu_start := 0

var opening := true


static func install(parent: Node) -> void:
	wall_usec = 0
	cpu_usec = 0
	ticks = 0
	unit_ticks = 0
	for opening_probe in [true, false]:
		var probe := BandProbe.new()
		probe.opening = opening_probe
		probe.name = "BandProbeOpen" if opening_probe else "BandProbeClose"
		probe.process_physics_priority = -11 if opening_probe else -9
		parent.add_child(probe)


static func thread_cpu_usec() -> int:
	var file := FileAccess.open("/proc/thread-self/schedstat", FileAccess.READ)
	if file == null:
		return 0
	# /proc files report a size of 0, so read a line rather than "the whole file".
	return int(file.get_line().get_slice(" ", 0)) / 1000


func _physics_process(_delta: float) -> void:
	if opening:
		_wall_start = Time.get_ticks_usec()
		_cpu_start = thread_cpu_usec()
	else:
		cpu_usec += thread_cpu_usec() - _cpu_start
		wall_usec += Time.get_ticks_usec() - _wall_start
		ticks += 1
		var game_match := get_parent() as Match
		if game_match != null:
			unit_ticks += game_match.alive_count(Match.Team.GREEN) + game_match.alive_count(Match.Team.RUST)
