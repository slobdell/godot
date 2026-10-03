class_name RenderSplit
extends Node
## `make render-split` (render, round 16, R2): what each piece of the picture costs the GPU, the draw calls and the
## primitives, measured by REMOVAL within one run (contract C16.3). It alternates `all` with each `RenderLayers` layer,
## a few seconds apart, so a layer's cost is read against the `all` phases either side of it and the battle's own
## drift (vehicles dying, effects coming and going) and the machine's load cancel.
##
## It is perf-scene's layer method on render's own switch table, for the layers perf-scene does not have (the base
## of ~8 ms no layer accounted for at launch). Play's perf harness stays the record for the frame as a whole.
##
## Flags: --render-split=<abs json>  --render-split-layers=a,b  --render-split-warmup=S (8)
##        --render-split-seconds=S (2.5)  --render-split-cycles=N (2)  --render-split-freeze=<tick> (one frozen frame)
## Prints RENDER_SPLIT <layer> gpu_saved=… draws_saved=… prims_saved=… per layer and RENDER_SPLIT_DONE.

## The first frames after a switch show the previous phase's GPU work (the measurement lags a frame or two).
const SETTLE_S := 0.4

var out_path := ""
var layers: Array[String] = []
var warmup := 8.0
var seconds := 2.5
var cycles := 2
var _phases: Array[String] = []
var _index := -1
var _phase_started := 0
var _undo: Array = []
var _rows: Array = []
var _samples := {}
var _last_wall := 0
## `--render-split-freeze=<tick>`: measure on one frozen frame instead of a live fight (-1 = live).
var freeze_tick := -1
## `--render-split-no-stage`: measure the frozen frame as the fight left it.
var stage_effects := true
var _frozen := false


static func wanted() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--render-split="):
			return true
	return false


func _init() -> void:
	name = "RenderSplit"
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 2000
	process_physics_priority = 1000


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--render-split="):
			out_path = arg.trim_prefix("--render-split=")
		elif arg.begins_with("--render-split-layers="):
			for piece in arg.trim_prefix("--render-split-layers=").split(",", false):
				layers.append(piece)
		elif arg.begins_with("--render-split-warmup="):
			warmup = float(arg.trim_prefix("--render-split-warmup="))
		elif arg.begins_with("--render-split-seconds="):
			seconds = float(arg.trim_prefix("--render-split-seconds="))
		elif arg.begins_with("--render-split-cycles="):
			cycles = int(arg.trim_prefix("--render-split-cycles="))
		elif arg == "--render-split-no-stage":
			stage_effects = false
		elif arg.begins_with("--render-split-freeze="):
			freeze_tick = int(arg.trim_prefix("--render-split-freeze="))
	if layers.is_empty():
		layers.assign(RenderLayers.NAMES)
	for c in cycles:
		for layer in layers:
			_phases.append("all")
			_phases.append(layer)
	_phases.append("all")
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	set_process(false)
	_start.call_deferred()


func _start() -> void:
	if freeze_tick < 0:
		await get_tree().create_timer(warmup, true, false, true).timeout
		set_process(true)
		_next_phase()


## Frozen mode: stop the world at match tick `freeze_tick` (tree paused from inside the step, FX and shader clocks
## stopped by time_scale 0, as look-parity does) and alternate the layers on that ONE frame. A live run's layer costs
## move with what the camera happens to be looking at (the same layers read 2.5 vs 4.0 ms for glow and 0.4 vs 1.9 ms
## for the fog sheet in two runs, 2026-10-02); a frozen frame's GPU time is the same frame after frame, so a layer's
## cost and a before/after are read to a fraction of a millisecond.
func _physics_process(_delta: float) -> void:
	if freeze_tick < 0 or _frozen:
		return
	var scene := get_tree().current_scene
	var game_match := scene.get_node_or_null("Match") if scene != null else null
	if game_match == null or int(game_match.get("tick")) < freeze_tick:
		return
	_frozen = true
	get_tree().paused = true
	Engine.time_scale = 0.0
	print("RENDER_SPLIT_FROZEN tick=%d vehicles=%d" % [int(game_match.get("tick")), _vehicles()])
	_begin_frozen.call_deferred()


func _begin_frozen() -> void:
	# The same staged combat look-parity shoots (LookParityShot.stage): without it the frozen frame is whatever the
	# fight happened to be doing at that tick, and the pooled lights read 1.91 ms in one run and 0.0 in the next.
	var fx := FxWorld.existing()
	if fx != null and stage_effects:
		fx.shake.enabled = false
		LookParityShot.stage(fx, LookParityShot.live_focus(get_viewport()), self)
		Engine.time_scale = 1.0
		for i in LookParityShot.STAGE_FRAMES:
			await get_tree().process_frame
		Engine.time_scale = 0.0
	await get_tree().create_timer(1.0, true, false, true).timeout
	_census()
	set_process(true)
	_next_phase()


## Every lit static instance whose box is big enough for one pooled light anywhere to re-draw all of it (the
## Compatibility renderer draws an object again, whole, for each OmniLight whose sphere meets its box).
func _census() -> void:
	var scene := get_tree().current_scene
	var game_match := scene.get_node_or_null("Match") if scene != null else null
	var tanks: Node = game_match.get("tanks") if game_match != null else null
	var fx := FxWorld.existing()
	var rows: Array = []
	for node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if not g.is_visible_in_tree() or (tanks != null and tanks.is_ancestor_of(g)) or (fx != null and fx.is_ancestor_of(g)):
			continue
		var box := g.global_transform * g.get_aabb()
		var lit := true
		var material: Variant = g.material_override
		if material is BaseMaterial3D:
			lit = (material as BaseMaterial3D).shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
		var span := maxf(box.size.x, box.size.z)
		if span >= 40.0:
			rows.append([span, "%s (%s) span=%.0f m box=%s instances=%s lit_guess=%s" % [g.get_path(), g.get_class(), span,
					box.size.snapped(Vector3.ONE), (g as MultiMeshInstance3D).multimesh.instance_count if g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null else 1, lit]])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for row: Array in rows:
		print("RENDER_SPLIT_BIG %s" % row[1])


func _process(_delta: float) -> void:
	# Wall clock, not `delta`: above max_physics_steps_per_frame Godot hands _process the SIMULATED time, so a saturated
	# frame read ~100 ms whatever it cost (play, round 16).
	var wall := Time.get_ticks_usec()
	var frame_ms := (wall - _last_wall) / 1000.0 if _last_wall > 0 else 0.0
	_last_wall = wall
	var age := (Time.get_ticks_msec() - _phase_started) / 1000.0
	if age >= SETTLE_S:
		var rid := get_viewport().get_viewport_rid()
		var s: Dictionary = _samples
		s["n"] = int(s.get("n", 0)) + 1
		s["frame_ms"] = float(s.get("frame_ms", 0.0)) + frame_ms
		# GPU ms is taken as the phase's MEDIAN (below): one garbage timer read (-6e10 ms, seen 2026-10-02) must not
		# decide a phase.
		(s.get_or_add("gpu_list", []) as Array).append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		s["cpu_ms"] = float(s.get("cpu_ms", 0.0)) + RenderingServer.viewport_get_measured_render_time_cpu(rid)
		s["draws"] = float(s.get("draws", 0.0)) + Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		s["prims"] = float(s.get("prims", 0.0)) + Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		s["objects"] = float(s.get("objects", 0.0)) + Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	if age >= SETTLE_S + seconds:
		_finish_phase()
		_next_phase()


func _next_phase() -> void:
	_index += 1
	if _index >= _phases.size():
		_report()
		return
	_samples = {}
	var phase := _phases[_index]
	if phase != "all":
		_undo = RenderLayers.apply(get_tree(), phase)
	_samples["switched"] = _undo.size()
	_phase_started = Time.get_ticks_msec()


func _finish_phase() -> void:
	RenderLayers.restore(_undo)
	_undo = []
	var n := maxi(1, int(_samples.get("n", 0)))
	var row := {"phase": _phases[_index], "frames": int(_samples.get("n", 0)), "switched": int(_samples.get("switched", 0)),
			"vehicles": _vehicles()}
	for key in ["frame_ms", "cpu_ms", "draws", "prims", "objects"]:
		row[key] = float(_samples.get(key, 0.0)) / n
	var gpu: Array = _samples.get("gpu_list", [0.0])
	gpu.sort()
	row["gpu_ms"] = float(gpu[gpu.size() / 2])
	_rows.append(row)


func _vehicles() -> int:
	var scene := get_tree().current_scene
	var game_match := scene.get_node_or_null("Match") if scene != null else null
	var tanks: Node = game_match.get("tanks") if game_match != null else null
	return tanks.get_child_count() if tanks != null else 0


func _report() -> void:
	set_process(false)
	var costs := {}
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		if row["phase"] == "all" or i == 0 or i + 1 >= _rows.size():
			continue
		var before: Dictionary = _rows[i - 1]
		var after: Dictionary = _rows[i + 1]
		var entry: Dictionary = costs.get(row["phase"], {"samples": 0, "switched": row["switched"]})
		entry["samples"] = int(entry["samples"]) + 1
		for key in ["gpu_ms", "cpu_ms", "frame_ms", "draws", "prims", "objects"]:
			var base := (float(before[key]) + float(after[key])) / 2.0
			entry[key + "_saved"] = float(entry.get(key + "_saved", 0.0)) + base - float(row[key])
			entry[key + "_all"] = float(entry.get(key + "_all", 0.0)) + base
		costs[row["phase"]] = entry
	var all_gpu := 0.0
	var all_count := 0
	for row: Dictionary in _rows:
		if row["phase"] == "all":
			all_gpu += float(row["gpu_ms"])
			all_count += 1
	for layer: String in costs:
		var entry: Dictionary = costs[layer]
		var k := float(entry["samples"])
		for key in entry.keys():
			if String(key).ends_with("_saved") or String(key).ends_with("_all"):
				entry[key] = float(entry[key]) / k
		print("RENDER_SPLIT %-15s gpu_saved=%6.2f ms (of %5.2f)  draws_saved=%6.1f  prims_saved=%8.0f  objects_saved=%6.1f  cpu_render_saved=%5.2f  switched=%d" % [
				layer, entry["gpu_ms_saved"], entry["gpu_ms_all"], entry["draws_saved"], entry["prims_saved"],
				entry["objects_saved"], entry["cpu_ms_saved"], entry["switched"]])
	var size := get_viewport().get_visible_rect().size
	var summary := {"gpu_ms_all": all_gpu / maxf(1.0, all_count), "window": "%dx%d" % [int(size.x), int(size.y)],
			"commit": OS.get_environment("TANK_SQUAD_COMMIT"), "tier": FxQuality.tier(),
			"renderer": RenderingServer.get_current_rendering_method(),
			"adapter": RenderingServer.get_video_adapter_name(), "seconds": seconds, "cycles": cycles,
			"frozen_at_tick": freeze_tick}
	print("RENDER_SPLIT_SUMMARY %s" % JSON.stringify(summary))
	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"summary": summary, "costs": costs, "phases": _rows}, " "))
	print("RENDER_SPLIT_DONE layers=%d phases=%d" % [costs.size(), _rows.size()])
	Engine.time_scale = 1.0
	get_tree().quit()
