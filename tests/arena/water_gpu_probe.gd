extends SceneTree
## `make water-gpu` (arena, round 12, A1): what the water costs on the GPU, measured where it can be seen. A live
## skirmish (`perf-scene`) moves its camera and its fight, and on a shared builder0 its frame time swings 5x between
## cycles, so a sub-millisecond shader change drowns in it. This holds ONE frame still: a terrain map at the lead's
## pose (21 deg, FOV 35, 49 m) over a water spot, nothing moving but the swell, and reads the viewport's measured GPU
## time over `--frames` frames, then again with the water hidden. The difference is the water's cost at that pose.
##
##   godot --path . --resolution 1920x1080 --script res://tests/arena/water_gpu_probe.gd -- --arena=crossing --spot=-92:14
## Prints WATER_GPU {json}: median and p90 GPU ms with the water drawn and hidden, the difference, frames, pixels.
## Self-contained on purpose: the same file runs unchanged in a "before" worktree, so both arms are measured alike.

const ARENA := preload("res://game/arena/arena.tscn")
const PITCH_DEG := 21.0
const DISTANCE_M := 49.0
const FOV_DEG := 35.0


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	var arena_name := _flag("arena", "crossing")
	var spot := _flag("spot", "-92:14").split(":")
	var frames := int(_flag("frames", "400"))
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = arena_name
	root.add_child(arena)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = FOV_DEG
	camera.far = 900.0
	var target := Vector3(float(spot[0]), 0.0, float(spot[1]))
	camera.global_position = target + Vector3(0.0, sin(deg_to_rad(PITCH_DEG)), cos(deg_to_rad(PITCH_DEG))) * DISTANCE_M
	camera.look_at(target, Vector3.UP)
	for frame in 120:
		await process_frame
	var water: MeshInstance3D = null
	for node in arena.find_children("*", "MeshInstance3D", true, false):
		if node.name == "Water":
			water = node
	if water == null:
		print("WATER_GPU {\"error\": \"no water on %s\"}" % arena_name)
		quit(1)
		return
	var viewport_rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	var drawn := await _sample(viewport_rid, frames)
	water.visible = false
	var hidden := await _sample(viewport_rid, frames)
	water.visible = true
	var drawn_again := await _sample(viewport_rid, frames)
	var result := {"arena": arena_name, "spot": spot, "frames": frames,
		"shader": String((water.material_override as ShaderMaterial).shader.resource_path),
		"drawn_median_ms": _pct(drawn, 0.5), "drawn_p90_ms": _pct(drawn, 0.9),
		"hidden_median_ms": _pct(hidden, 0.5), "hidden_p90_ms": _pct(hidden, 0.9),
		"drawn_again_median_ms": _pct(drawn_again, 0.5),
		"water_ms": snappedf((_pct(drawn, 0.5) + _pct(drawn_again, 0.5)) / 2.0 - _pct(hidden, 0.5), 0.001)}
	print("WATER_GPU " + JSON.stringify(result))
	quit(0)


func _sample(viewport_rid: RID, count: int) -> PackedFloat64Array:
	for frame in 30:
		await process_frame
	var out := PackedFloat64Array()
	for frame in count:
		await RenderingServer.frame_post_draw
		out.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
	out.sort()
	return out


func _pct(values: PackedFloat64Array, q: float) -> float:
	return snappedf(values[clampi(int(q * (values.size() - 1)), 0, values.size() - 1)], 0.001) if values.size() > 0 else -1.0
