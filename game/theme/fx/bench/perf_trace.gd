class_name PerfTrace
extends Node
## Round 16 (play P2): every game he plays carries its own frame times. Beside each match recording
## (build/recordings/<stamp>-<arena>.jsonl) it writes <stamp>-<arena>.perf: one JSON line a second of wall clock with the
## frames' avg/p95/max (WALL CLOCK, not `delta`: see perf_scene.gd), ticks per frame, the tick scripts' ms a tick, the
## game+UI `_process` ms, the GPU ms, `game_speed` (battle time over wall time: below 1 the game is in slow motion),
## `over34` (the share of frames that missed the locked-30 line), vehicles alive, the phase, and `self_ms` (what this
## node cost a frame: the budget is 0.05). Lesson 225: the recording is the witness -- now for the frame too.
## Read one with `tools/perf_trace_report.py <file.perf>`.
##
## P6: with `--perf` it also shows its line on screen, with "SLOW x0.60" when the simulation cannot keep up, so
## "choppy" (frames late) and "slow" (the battle itself behind the clock) are told apart.
##
## On in a windowed skirmish that records; never headless, scripted, under perf-scene/perf-play, with --no-record, or
## with --perf-trace=off.

const EXTENSION := ".perf"
const KEEP := 40
const SLOW_BELOW := 0.95
const PROBE := preload("res://game/theme/fx/bench/perf_probe.gd")

var path := ""
var game_match: Node
var show_line := false

var _file: FileAccess
var _wall := PackedFloat32Array()
var _gpu := PackedFloat32Array()
var _game_ms := 0.0
var _ticks := 0
var _tick_usec := 0
var _tick_start := 0
var _ui_usec := 0
var _marks := PackedInt64Array([0, 0])
var _last := 0
var _second_start := 0
var _started := 0
var _self_usec := 0
var _label: Label
var _latest := {}
var _over := false


## Whether this launch traces. Pure.
static func wanted(flags: LaunchFlags, headless: bool) -> bool:
	if headless or flags.text("perf-trace") == "off":
		return false
	for flag in ["scripted", "perf-scene", "no-record"]:
		if flags.has(flag):
			return false
	return true


## The trace beside a recording: the same name, its own extension (the recorder's prune counts only *.jsonl). Pure.
static func trace_path(recording_path: String) -> String:
	return recording_path.get_basename() + EXTENSION


## Starts a trace under `parent` beside `recording_path`. Returns it.
static func start(parent: Node, recording_path: String, p_match: Node, p_show_line: bool) -> PerfTrace:
	var trace := PerfTrace.new()
	trace.name = "PerfTrace"
	trace.path = PerfTrace.trace_path(recording_path)
	trace.game_match = p_match
	trace.show_line = p_show_line
	parent.add_child(trace)
	return trace


## One row from a second of frames: wall frame ms, the battle time they advanced, physics ticks and their script µs,
## game+UI µs, GPU ms per frame. Pure.
static func summarize(wall: PackedFloat32Array, game_ms: float, ticks: int, tick_usec: int, ui_usec: int,
		gpu: PackedFloat32Array) -> Dictionary:
	var frames := maxi(wall.size(), 1)
	var wall_total := 0.0
	for ms in wall:
		wall_total += ms
	return {
		"frames": wall.size(),
		"avg_ms": snappedf(wall_total / frames, 0.01),
		"p95_ms": snappedf(PerfScene.percentile(wall, 0.95), 0.01),
		"max_ms": snappedf(PerfScene.percentile(wall, 1.0), 0.01),
		"ticks_per_frame": snappedf(float(ticks) / frames, 0.01),
		"tick_ms": snappedf(float(tick_usec) / maxf(float(ticks), 1.0) / 1000.0, 0.01),
		"ui_ms": snappedf(float(ui_usec) / frames / 1000.0, 0.01),
		"gpu_ms": snappedf(PerfScene.percentile(gpu, 0.5), 0.01),
		"game_speed": snappedf(game_ms / wall_total if wall_total > 0.0 else 1.0, 0.01),
		"over34": snappedf(PerfScene.over_share(wall, PerfScene.cap_line_ms(30.0)), 0.001),
	}


## P6: what the overlay says about the battle's own speed ("" at real time). Pure.
static func slow_label(game_speed: float) -> String:
	return "" if game_speed >= SLOW_BELOW else "SLOW x%.2f" % game_speed


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# After FxWorld (1000) and everything at default priority: one frame's wall clock, measured at the same point.
	process_priority = 2000


func _ready() -> void:
	_prune(path.get_base_dir())
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		print("PERF_TRACE could not open %s: off" % path)
		queue_free()
		return
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	# [process priority, slot]: game+UI _process is slot 0 -> 1 (everything at default priority, before FxWorld);
	# the physics probes bracket every _physics_process of a tick (3 -> 4).
	for probe in [[-100000000, 0], [999, 1], [-100000000, 3], [100000000, 4]]:
		var node := Node.new()
		node.name = "TraceProbe%d" % probe[1]
		node.process_mode = Node.PROCESS_MODE_ALWAYS
		node.process_priority = probe[0]
		node.process_physics_priority = probe[0]
		node.set_script(PROBE)
		node.set_meta("slot", probe[1])
		node.set_meta("owner", self)
		add_child(node)
	if show_line:
		var layer := CanvasLayer.new()
		layer.layer = 120
		_label = Label.new()
		_label.position = Vector2(12.0, 150.0)
		_label.add_theme_font_size_override("font_size", 15)
		_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_label.add_theme_constant_override("outline_size", 4)
		layer.add_child(_label)
		add_child(layer)
	if game_match != null and game_match.has_signal("finished"):
		game_match.connect("finished", func(_result: Dictionary) -> void: _over = true)
	_started = Time.get_ticks_usec()
	_second_start = _started
	print("PERF_TRACE %s" % path)


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last > 0:
		_wall.append((now - _last) / 1000.0)
		_game_ms += delta * 1000.0 if not get_tree().paused else (now - _last) / 1000.0
		_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
		if _marks[0] > 0 and _marks[1] > _marks[0]:
			_ui_usec += _marks[1] - _marks[0]
	_last = now
	if now - _second_start >= 1000000:
		_write(now)
	_self_usec += Time.get_ticks_usec() - now


func _write(now: int) -> void:
	var row := PerfTrace.summarize(_wall, _game_ms, _ticks, _tick_usec, _ui_usec, _gpu)
	row["t"] = snappedf((now - _started) / 1000000.0, 0.1)
	row["vehicles"] = _vehicles()
	row["phase"] = _phase()
	row["self_ms"] = snappedf(_self_usec / 1000.0 / maxf(float(_wall.size()), 1.0), 0.001)
	_file.store_line(JSON.stringify(row))
	_file.flush()
	_latest = row
	if _label != null:
		_label.text = "frame %.0f ms (p95 %.0f)  tick %.1f ms x%.2f/frame  ui %.1f  gpu %.1f  %s" % [row["avg_ms"],
				row["p95_ms"], row["tick_ms"], row["ticks_per_frame"], row["ui_ms"], row["gpu_ms"],
				PerfTrace.slow_label(float(row["game_speed"]))]
		_label.modulate = Color(1.0, 0.55, 0.3) if PerfTrace.slow_label(float(row["game_speed"])) != "" else Color.WHITE
	_wall.clear()
	_gpu.clear()
	_game_ms = 0.0
	_ticks = 0
	_tick_usec = 0
	_ui_usec = 0
	_self_usec = 0
	_second_start = now


## The last row written (tests, the overlay).
func latest() -> Dictionary:
	return _latest


func _vehicles() -> int:
	var tanks: Node = game_match.get("tanks") if game_match != null else null
	var count := 0
	if tanks != null:
		for child in tanks.get_children():
			if child is Tank and (child as Tank).is_alive():
				count += 1
	return count


func _phase() -> String:
	if _over:
		return "over"
	return "paused" if get_tree().paused else "battle"


## Called by the probes (perf_probe.gd).
func mark(slot: int) -> void:
	var now := Time.get_ticks_usec()
	if slot < 3:
		_marks[slot] = now
	elif slot == 3:
		_tick_start = now
	else:
		_tick_usec += now - _tick_start
		_ticks += 1
	_self_usec += Time.get_ticks_usec() - now


func _exit_tree() -> void:
	if _file != null:
		_file.flush()
		_file = null


## Keep the newest KEEP traces in `dir`.
static func _prune(dir: String) -> void:
	var traces: Array = Array(DirAccess.get_files_at(dir)).filter(func(n: String) -> bool: return n.ends_with(EXTENSION))
	traces.sort()
	for i in maxi(0, traces.size() - KEEP + 1):
		DirAccess.remove_absolute(dir.path_join(String(traces[i])))
