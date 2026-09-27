extends SceneTree
## `make water-gpu` (arena, round 12, A1): what the water costs on the GPU, measured where it can be seen. A live
## skirmish (`perf-scene`) moves its camera and its fight, and on a shared builder0 its frame time swings 5x between
## cycles, so a sub-millisecond shader change drowns in it. This holds ONE frame still: a terrain map at the lead's
## pose (21 deg, FOV 35, 49 m) over a water spot, nothing moving but the swell, and reads the viewport's measured GPU
## time with the water drawn and hidden in alternating blocks (`--blocks`, `--frames` in all); the median of the paired
## block differences is the water's cost at that pose, and its quartiles say how far to trust it.
##
##   godot --path . --resolution 1920x1080 --script res://tests/arena/water_gpu_probe.gd -- --arena=crossing --spot=-92:14
## Prints WATER_GPU {json}: the water's ms (median of paired differences) with its quartiles, and the medians drawn/hidden.
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
	# builder0's GPU is shared with other streams' runs, so the load drifts by milliseconds within a minute. Toggle
	# the water in short blocks and pair each drawn block with the hidden block right after it: the drift cancels in
	# the difference, and the median of the differences is the water's cost.
	# `--looks=r10,b_venue,...` (this branch only: WaterLook's steps) measures each look in turn, to find what costs.
	var looks := _flag("looks", "").split(",", false)
	if looks.is_empty():
		looks = PackedStringArray([""])
	for look in looks:
		if look != "":
			var visual: Node = water.get_parent()
			visual.call("set_water_look", _look(look), -1.0)
		await _measure(arena_name, spot, frames, water, viewport_rid, look)
	quit(0)


func _look(name: String) -> Dictionary:
	var script: GDScript = load("res://game/theme/arena_kit/terrain/water_look.gd")
	return script.call("at", name)


func _measure(arena_name: String, spot: PackedStringArray, frames: int, water: MeshInstance3D, viewport_rid: RID, look: String) -> void:
	var blocks := int(_flag("blocks", "40"))
	var per := maxi(4, frames / blocks)
	var diffs := PackedFloat64Array()
	var drawn := PackedFloat64Array()
	var hidden := PackedFloat64Array()
	for pair in blocks / 2:
		water.visible = true
		var on := _pct(await _sample(viewport_rid, per), 0.5)
		water.visible = false
		var off := _pct(await _sample(viewport_rid, per), 0.5)
		drawn.append(on)
		hidden.append(off)
		diffs.append(on - off)
	water.visible = true
	diffs.sort()
	drawn.sort()
	hidden.sort()
	var result := {"arena": arena_name, "spot": spot, "look": look, "blocks": blocks, "frames_per_block": per,
		"shader": String((water.material_override as ShaderMaterial).shader.resource_path),
		"drawn_median_ms": _pct(drawn, 0.5), "hidden_median_ms": _pct(hidden, 0.5),
		"water_ms": _pct(diffs, 0.5), "water_q25_ms": _pct(diffs, 0.25), "water_q75_ms": _pct(diffs, 0.75)}
	print("WATER_GPU " + JSON.stringify(result))


func _sample(viewport_rid: RID, count: int) -> PackedFloat64Array:
	for frame in 3:
		await process_frame
	var out := PackedFloat64Array()
	for frame in count:
		await RenderingServer.frame_post_draw
		out.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
	out.sort()
	return out


func _pct(values: PackedFloat64Array, q: float) -> float:
	return snappedf(values[clampi(int(q * (values.size() - 1)), 0, values.size() - 1)], 0.001) if values.size() > 0 else -1.0
