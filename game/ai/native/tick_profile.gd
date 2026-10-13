class_name TickProfile
extends Node
## Round 24 (native, measurement only): where a WINDOWED tick goes in a window of game time. `--native-tick-profile=A,B`
## (seconds of match time) installs SimProfile into the running match the first time a mover refreshes the avoidance
## table (Avoidance.refresh calls `TickProfile.ensure`), resets it at A s, and at B s prints one NATIVE_TICK_PROFILE
## line: SimProfile's split of the tick's scripts (elements, commanders, controllers, then priority 0: tanks, brains,
## match, shells, with their own sections) plus this node's per-frame reading of the engine's monitors over the same
## window (the frame's wall time, physics ticks a frame, TIME_PROCESS) and the ENGINE's physics step between two ticks'
## scripts (the gap from one tick's last script to the next tick's first, timed by two marker nodes, kept only when no
## frame was drawn in between), and how many hulls were alive at A and at B. It reads the wall clock, so nothing it measures
## may feed a decision; with it on, OrderController's profile parts run too (SimProfile's `brain/` sections), so the
## absolute ms carry their instrumentation.

static var _window := Vector2(-1.0, -1.0)
static var _parsed := false
static var _installed: TickProfile = null

var _match: Match = null
var _started := false
var _done := false
var _alive_at_start := 0
var _frames := 0
var _process_ms := 0.0
var _wall_usec := 0
var _last_usec := 0
var _ticks_at_start := 0
var _closed_usec := 0
var _closed_frame := -1
var _gap_usec := 0
var _gaps := 0
var _opener: Node = null


class Opener:
	extends Node
	var owner_profile: TickProfile

	func _physics_process(_delta: float) -> void:
		owner_profile._on_open()


## Measurement for tests: the last report printed.
## The guard counts native paths from here (match seconds) until the window opens.
const COUNT_FROM_S := 5.0
static var last_report := {}
var _taken := {}


static func window() -> Vector2:
	if not _parsed:
		_parsed = true
		_window = parse_window(OS.get_cmdline_user_args())
	return _window


## `--native-tick-profile=A,B` -> Vector2(A, B), or (-1, -1) when absent or malformed.
static func parse_window(args: PackedStringArray) -> Vector2:
	for arg in args:
		if arg.begins_with("--native-tick-profile="):
			var parts := arg.trim_prefix("--native-tick-profile=").split(",")
			if parts.size() == 2 and parts[0].is_valid_float() and parts[1].is_valid_float():
				return Vector2(float(parts[0]), float(parts[1]))
	return Vector2(-1.0, -1.0)


## Tests: profile `tanks_root`'s match over [a, b] seconds of match time (as if the flag said so).
static func start_for_test(tanks_root: Node, a: float, b: float) -> void:
	_parsed = true
	_window = Vector2(a, b)
	_installed = null
	last_report = {}
	ensure(tanks_root)


## Tests: forget the profile (and stop SimProfile) so the rest of the suite runs unprofiled.
static func stop_for_test() -> void:
	SimProfile.uninstall()
	_window = Vector2(-1.0, -1.0)
	_installed = null


## Called by Avoidance.refresh with the hulls' root (its parent is the match): one profile per process.
static func ensure(tanks_root: Node) -> void:
	if _installed != null or window().x < 0.0 or tanks_root == null:
		return
	var game_match := tanks_root.get_parent() as Match
	if game_match == null:
		return
	_installed = TickProfile.new()
	_installed.name = "NativeTickProfile"
	_installed._match = game_match
	_installed.process_physics_priority = 100001  # after SimProfile's close marker: the tick's scripts are done
	var opener := Opener.new()
	opener.name = "NativeTickProfileOpen"
	opener.owner_profile = _installed
	opener.process_physics_priority = -100001  # before SimProfile's open marker
	_installed._opener = opener
	game_match.add_child(_installed)
	game_match.add_child(opener)
	SimProfile.install(game_match)
	# Round 28 (N7 guard): which native paths are TAKEN under this instrument, counted from COUNT_FROM_S of match time
	# (every measurement mode is on by then: profile_detail flips at each controller's first tick after the install,
	# and a count from the install let a seam that stepped aside score its one call before that) until the window
	# opens -- not inside it, so the count costs the window nothing.
	NativeBridge.taken = {}
	NativeBridge.counting = false


func _on_open() -> void:
	if _started and not _done and _closed_usec > 0 and _closed_frame == _frames:
		_gap_usec += Time.get_ticks_usec() - _closed_usec
		_gaps += 1
	_closed_usec = 0


func _physics_process(_delta: float) -> void:
	_closed_usec = Time.get_ticks_usec()
	_closed_frame = _frames


## The native switches in force (BrainSwitches.native and the switch both on): what the guard expects to be taken.
static func _native_on() -> Array:
	var on: Array = []
	if not BrainSwitches.native:
		return on
	var switches: Script = BrainSwitches  # the class as a value: its static vars by name
	for name: String in BrainSwitches.NAMES:
		if name.begins_with("native_") and bool(switches.get(name)):
			on.append(name)
	return on


func _alive() -> int:
	var count := 0
	for child in _match.tanks.get_children():
		var tank := child as Tank
		if tank != null and tank.is_alive():
			count += 1
	return count


func _process(_delta: float) -> void:
	if _done or _match == null or not is_instance_valid(_match):
		return
	var seconds := float(_match.tick) / float(SimClock.TICK_RATE)
	var now := Time.get_ticks_usec()
	if not _started:
		if not NativeBridge.counting and seconds >= COUNT_FROM_S and seconds < window().x:
			NativeBridge.counting = true
		if seconds >= window().x:
			_started = true
			SimProfile.reset()
			_taken = NativeBridge.taken.duplicate()
			NativeBridge.counting = false
			_alive_at_start = _alive()
			_ticks_at_start = Engine.get_physics_frames()
			_last_usec = now
		return
	_frames += 1
	_process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_wall_usec += now - _last_usec
	_last_usec = now
	if seconds >= window().y:
		_done = true
		var frames := float(maxi(_frames, 1))
		var report := {"window_s": [window().x, window().y], "match_tick": _match.tick,
				"alive": [_alive_at_start, _alive()], "frames": _frames,
				"ticks_per_frame": snappedf(float(Engine.get_physics_frames() - _ticks_at_start) / frames, 0.01),
				"frame_wall_ms": snappedf(_wall_usec / frames / 1000.0, 0.01),
				"process_ms": snappedf(_process_ms / frames, 0.01),
				"engine_physics_step_ms": snappedf(_gap_usec / float(maxi(_gaps, 1)) / 1000.0, 0.01), "step_samples": _gaps,
				"sim": SimProfile.report(), "native": NativeBridge.describe(),
				"switches": {"native": BrainSwitches.native, "native_drive": BrainSwitches.native_drive},
				"native_on": _native_on(), "native_taken": _taken}
		last_report = report
		print("NATIVE_TICK_PROFILE " + JSON.stringify(report))
