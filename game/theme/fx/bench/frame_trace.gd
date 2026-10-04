class_name FrameTrace
extends Node
## Round 18 (finale E1): every frame through the END of a match, cut into its parts, with a marker at each end-of-match
## event, so the freeze at the final kill has a number and a place. `--frame-trace=PATH` turns it on (FxWorld adds it).
##
## A frame is cut at the engine's own signals, in the order the main loop runs them: the first `physics_frame` (the
## simulation's ticks), `process_frame` (every `_process`, deferred calls), `RenderingServer.frame_pre_draw` /
## `frame_post_draw` (the draw: in the Compatibility renderer a first-use shader compiles HERE, synchronously, on the main
## thread), then the gap to the next frame's first tick (the buffer swap / vsync wait and the frame cap's sleep, input,
## the audio mix lock). So a stall is named by its PART before anything is switched off (E2 does the removal).
## Each frame also carries the match tick, `Engine.time_scale`, the draw calls, the object / resource / node counts and
## the video and texture memory (a jump there is a first `load()` or a first upload), and the names of the nodes that
## entered the tree that frame.
##
## Per frame also: the pooled lights lit, beams, wrecks and burning sites, and a `first:<what>` marker the first frame
## each is non-zero (a first use: E5). Markers: `kill` (Match.unit_destroyed), `finished`, `kill_cam` / `kill_cam_end` (FxWorld.kill_cam.active), `banner`
## (the HUD banner becoming visible, read only), `results` (a node named ResultsScreen entering the tree), and
## `--frame-trace-mark=` is free for a probe. `--frame-trace-after=S` quits S real seconds after `finished` (default 6),
## writing PATH (one JSON line per frame, then one `{"summary": …}` line) and printing FRAME_TRACE lines.
## E2's removal arms: `--frame-trace-off=no_live_feed,no_pool_lights,…` applies those RenderLayers (render's round-16
## switch table) the first frame the match is attached, and marks `off:<layer>` with how many things it switched (the
## arm assertion: a layer that found nothing says `0`, and the run is not that arm).
## Recording costs a few array appends a frame; nothing is written until the end.

const AFTER_DEFAULT := 6.0
## The window the stall is judged in: the largest frame within this many seconds of the final kill (E1's definition).
const WINDOW_S := 1.0
const NODE_NAMES_KEPT := 6

var path := ""
var after_s := AFTER_DEFAULT
var game_match: Node

var _rows: Array[Dictionary] = []
var _marks: Array[Dictionary] = []
var _start_usec := 0
var _frame_start := 0  # the first physics_frame of this frame, or process_frame when no tick ran
var _process_start := 0
var _pre_draw := 0
var _post_draw := 0
var _tick_seen := false
var _added: PackedStringArray = []
var _added_count := 0
var _finished_usec := 0
var _kill_cam_was := false
var _banner_was := false
var _written := false
## First uses already marked (`first:lit`, `first:beams`, …): E5 reads the stall frames against these.
var _firsts := {}
var _uses := {}
var _fx: FxWorld


static func wanted(flags: LaunchFlags) -> bool:
	return flags.has("frame-trace") and DisplayServer.get_name() != "headless"


func _init(fx: FxWorld = null) -> void:
	name = "FrameTrace"
	_fx = fx
	process_mode = Node.PROCESS_MODE_ALWAYS
	var flags := LaunchFlags.from_environment()
	path = flags.text("frame-trace")
	after_s = float(flags.text("frame-trace-after", str(AFTER_DEFAULT)))


func _ready() -> void:
	_start_usec = Time.get_ticks_usec()
	var tree := get_tree()
	tree.physics_frame.connect(_on_physics_frame)
	tree.process_frame.connect(_on_process_frame)
	tree.node_added.connect(_on_node_added)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)


func _now() -> int:
	return Time.get_ticks_usec() - _start_usec


## Add a marker at the current frame (anything may call it: `FrameTrace.mark_now("x")`).
func mark(what: String, detail := "") -> void:
	_marks.append({"frame": _rows.size(), "t_us": _now(), "what": what, "detail": detail})


static func mark_now(what: String, detail := "") -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var trace := tree.root.find_child("FrameTrace", true, false) as FrameTrace if tree != null else null
	if trace != null:
		trace.mark(what, detail)


func _on_physics_frame() -> void:
	if not _tick_seen:
		_tick_seen = true
		_close_frame(_now())
		_frame_start = _now()


func _on_process_frame() -> void:
	var now := _now()
	if not _tick_seen:
		_close_frame(now)
		_frame_start = now
	_process_start = now
	_watch()


func _on_pre_draw() -> void:
	_pre_draw = _now()


func _on_post_draw() -> void:
	_post_draw = _now()
	_tick_seen = false


func _on_node_added(node: Node) -> void:
	_added_count += 1
	if _added.size() < NODE_NAMES_KEPT:
		_added.append("%s:%s" % [node.get_class(), node.name])
	if String(node.name) == "ResultsScreen":
		mark("results")
	# A second viewport or camera draws the scene's materials under its own lights and settings: new shader variants.
	if node is Viewport or node is Camera3D:
		mark("enter:" + node.get_class(), str(node.get_path()))


## The frame that started at `_frame_start` is over: record it, cut into its parts.
func _close_frame(now: int) -> void:
	if _frame_start == 0 and _rows.is_empty() and _process_start == 0:
		return
	var physics := maxi(_process_start - _frame_start, 0)
	var process := maxi(_pre_draw - _process_start, 0) if _pre_draw >= _process_start else 0
	var draw := maxi(_post_draw - _pre_draw, 0) if _post_draw >= _pre_draw and _pre_draw >= _process_start else 0
	var rest := maxi(now - _frame_start - physics - process - draw, 0)
	var tick := int(game_match.get("tick")) if game_match != null and is_instance_valid(game_match) else -1
	_rows.append({
		"t_us": _frame_start, "ms": (now - _frame_start) / 1000.0,
		"physics_ms": physics / 1000.0, "process_ms": process / 1000.0, "draw_ms": draw / 1000.0, "rest_ms": rest / 1000.0,
		"tick": tick, "time_scale": Engine.time_scale,
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"texture_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"added": _added_count, "added_names": _added,
		"lit": _fx.lights.lit_count if _fx != null else 0,
		"beams": _fx.beams.active_count() if _fx != null else 0,
		"wrecks": _fx.wrecks.count() if _fx != null else 0,
		"burning": _fx.fires.burning_count() if _fx != null else 0,
		"camera": _camera_pose(),
	})
	_added = []
	_added_count = 0


func _camera_pose() -> Array:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return []
	var p := camera.global_position
	var f := -camera.global_basis.z
	return [snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1), snappedf(f.x, 0.01), snappedf(f.y, 0.01), snappedf(f.z, 0.01)]


## Markers read from state each frame (read only: the trace never calls into what it watches).
func _watch() -> void:
	if game_match == null or not is_instance_valid(game_match):
		var found := FxWorld.existing().link.attached_match() if FxWorld.existing() != null else null
		if found != null:
			game_match = found
			if game_match.has_signal("unit_destroyed"):
				game_match.connect("unit_destroyed", func(event: Dictionary) -> void: mark("kill", str(event.get("unit", ""))))
			game_match.connect("finished", func(result: Dictionary) -> void:
				_finished_usec = _now()
				mark("finished", String(result.get("reason", ""))))
			# E5: the first and the tenth of each gun and of each kind of impact, so a first use reads against a later one.
			if game_match.has_signal("weapon_fired"):
				game_match.connect("weapon_fired", func(event: Dictionary) -> void: _count_use("fire:" + str(event.get("weapon", ""))))
			if game_match.has_signal("projectile_impact"):
				game_match.connect("projectile_impact", func(event: Dictionary) -> void:
					_count_use("impact:" + ("kill" if bool(event.get("killed", false)) else "unit" if event.has("target") else "ground")))
			for layer in LaunchFlags.from_environment().text("frame-trace-off").split(",", false):
				mark("off:" + layer, str(RenderLayers.apply(get_tree(), layer).size()))
	if _fx != null:
		for pair in [["lit", _fx.lights.lit_count], ["beams", _fx.beams.active_count()], ["wrecks", _fx.wrecks.count()],
				["burning", _fx.fires.burning_count()]]:
			if int(pair[1]) > 0 and not _firsts.has(pair[0]):
				_firsts[pair[0]] = true
				mark("first:" + String(pair[0]))
	if _fx != null and _fx.kill_cam != null and _fx.kill_cam.active != _kill_cam_was:
		_kill_cam_was = _fx.kill_cam.active
		mark("kill_cam" if _kill_cam_was else "kill_cam_end")
	var scene := get_tree().current_scene
	var banner := scene.get_node_or_null("Hud/Banner") as CanvasItem if scene != null else null
	if banner == null and scene != null and scene.get("hud") is Node:
		banner = (scene.get("hud") as Node).get("banner") as CanvasItem
	if banner != null and banner.visible != _banner_was:
		_banner_was = banner.visible
		if _banner_was:
			mark("banner", String(banner.get("text")))
	if _finished_usec > 0 and not _written and _now() - _finished_usec > int(after_s * 1_000_000.0):
		finish()
		get_tree().quit()


func _count_use(what: String) -> void:
	var count := int(_uses.get(what, 0)) + 1
	_uses[what] = count
	if count == 1:
		mark("first:" + what)
	elif count == 10:
		mark("tenth:" + what)


## The summary: the final kill (the last `kill` at or before `finished`) and the largest frame within WINDOW_S of it.
static func summarize(rows: Array, marks: Array) -> Dictionary:
	var finished_frame := -1
	var kill_us := -1
	for m: Dictionary in marks:
		if m["what"] == "finished" and finished_frame < 0:
			finished_frame = int(m["frame"])
	for m: Dictionary in marks:
		if m["what"] == "kill" and (finished_frame < 0 or int(m["frame"]) <= finished_frame):
			kill_us = int(m["t_us"])
	var out := {"frames": rows.size(), "final_kill_us": kill_us, "max_ms": 0.0, "max_frame": -1, "typical_ms": 0.0}
	if kill_us < 0:
		return out
	var before: Array[float] = []
	var window := int(WINDOW_S * 1_000_000.0)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var t := int(row["t_us"])
		# The typical frame: the median of the four seconds before the window opens.
		if t >= kill_us - 5_000_000 and t < kill_us - window:
			before.append(float(row["ms"]))
		if absi(t - kill_us) <= window and float(row["ms"]) > float(out["max_ms"]):
			out["max_ms"] = float(row["ms"])
			out["max_frame"] = i
	before.sort()
	out["typical_ms"] = before[before.size() / 2] if not before.is_empty() else 0.0
	if int(out["max_frame"]) >= 0:
		var worst: Dictionary = rows[int(out["max_frame"])]
		for key in ["physics_ms", "process_ms", "draw_ms", "rest_ms", "tick", "time_scale", "added", "added_names"]:
			out[key] = worst[key]
		out["after_kill_ms"] = (int(worst["t_us"]) - kill_us) / 1000.0
		var prev: Dictionary = rows[maxi(int(out["max_frame"]) - 1, 0)]
		for key in ["objects", "resources", "nodes", "video_mb", "texture_mb"]:
			out["d_" + key] = float(worst[key]) - float(prev[key])
	return out


func finish() -> void:
	if _written:
		return
	_written = true
	_close_frame(_now())
	var summary := FrameTrace.summarize(_rows, _marks)
	if path != "":
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			for row in _rows:
				file.store_line(JSON.stringify(row))
			file.store_line(JSON.stringify({"marks": _marks}))
			file.store_line(JSON.stringify({"summary": summary}))
	for m: Dictionary in _marks:
		print("FRAME_TRACE mark frame=%d t=%.3f %s %s" % [m["frame"], int(m["t_us"]) / 1e6, m["what"], m["detail"]])
	print("FRAME_TRACE summary max_ms=%.1f at=%+.0fms typical_ms=%.1f physics=%.1f process=%.1f draw=%.1f rest=%.1f added=%s d_resources=%s %s" % [
		float(summary["max_ms"]), float(summary.get("after_kill_ms", 0.0)), float(summary["typical_ms"]),
		float(summary.get("physics_ms", 0.0)), float(summary.get("process_ms", 0.0)), float(summary.get("draw_ms", 0.0)),
		float(summary.get("rest_ms", 0.0)), summary.get("added", 0), summary.get("d_resources", 0), summary.get("added_names", [])])
	print("FRAME_TRACE_DONE %s" % path)


func _exit_tree() -> void:
	finish()
