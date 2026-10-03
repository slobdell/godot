extends SceneTree
## Yard (round 17, Y5): container frames at the lead's pose (21 deg, FOV 35, 49 m), for the before/after page. Boots the
## REAL skirmish (main.tscn with the flags after `--`: the theme, the lamps and the show are what he sees), lets it
## settle, freezes it, hides the HUD, then parks the camera with the rig's own pose function over each spot and saves
## a JPEG. `opening` keeps the camera where the match put it (what he sees first). A spot's distance may be shorter
## than his for a close look at a stack (the page says which frames are close).
##
##   godot --path . --resolution 1920x1080 --script res://tests/arena/container_frames.gd -- --skirmish --mute --seed=3 \
##       --arena=yard --frames-out=/abs/dir --frames-tag=after --frames-spots="opening;west:-86:28;close:-84:20:0:22"
##
## A spot is key[:x:z[:heading_deg[:distance_m]]]. Run once on the launch tree (the true BEFORE: square ground, the old
## stack jitter) and once on the tree under test; `make container-frames` runs the after pass.

const SETTLE_S := 4.0
const DISTANCE_M := 49.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var flags := LaunchFlags.from_environment()
	var out_dir := flags.text("frames-out")
	var tag := flags.text("frames-tag", "after")
	var spots := _spots(flags.text("frames-spots", "opening"))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	var clock := 0.0
	while clock < SETTLE_S:
		await physics_frame
		clock += 1.0 / Engine.physics_ticks_per_second
	paused = true
	for rig in _all(root, func(n: Node) -> bool: return n is RtsCamera):
		rig.set_process(false)
		rig.set_physics_process(false)
	for layer in _all(root, func(n: Node) -> bool: return n is CanvasLayer):
		(layer as CanvasLayer).visible = false  # the containers, not the HUD
	var camera: Camera3D = main.get("camera")
	camera.current = true
	camera.fov = RtsCamera.FOV_DEG
	var arena := String(Arena.active.get("name", ""))
	var frames: Array = []
	for spot: Dictionary in spots:
		if spot.has("at"):
			var at := Vector3(spot["at"][0], 0.0, spot["at"][1])
			camera.global_transform = RtsCamera.pose_at(at, deg_to_rad(float(spot["heading_deg"])), float(spot["distance_m"]),
					RtsCamera.DEFAULT_PITCH_DEG)
			camera.near = 0.3
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_viewport().get_texture().get_image()
		var file := "%s_%s_%s.jpg" % [arena, spot["key"], tag]
		if image != null and not image.is_empty():
			image.save_jpg(out_dir.path_join(file), 0.88)
		frames.append(spot.merged({"file": file}))
		print("CONTAINER_FRAME %s %s" % [tag, file])
	var meta := FileAccess.open(out_dir.path_join("%s_%s.json" % [arena, tag]), FileAccess.WRITE)
	meta.store_string(JSON.stringify({"tag": tag, "arena": arena, "pitch": RtsCamera.DEFAULT_PITCH_DEG, "fov": RtsCamera.FOV_DEG,
			"frames": frames}, "  "))
	meta.close()
	print("CONTAINER_FRAMES_DONE arena=%s tag=%s frames=%d" % [arena, tag, frames.size()])
	quit(0)


func _spots(text: String) -> Array:
	var out: Array = []
	for item in text.split(";", false):
		var parts := item.split(":")
		var spot := {"key": parts[0]}
		if parts.size() >= 3:
			spot["at"] = [float(parts[1]), float(parts[2])]
			spot["heading_deg"] = float(parts[3]) if parts.size() >= 4 else 0.0
			spot["distance_m"] = float(parts[4]) if parts.size() >= 5 else DISTANCE_M
		out.append(spot)
	return out


func _all(node: Node, keep: Callable) -> Array:
	var out: Array = []
	if keep.call(node):
		out.append(node)
	for child in node.get_children():
		out.append_array(_all(child, keep))
	return out
