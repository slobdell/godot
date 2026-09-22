extends SceneTree
## R4 (round 10): the Terminus streets at the lead's pose (21°, FOV 35, 49 m), one frame per named street, for the
## before/after pair on the arena page. Boots the REAL skirmish (main.tscn with the flags after `--`, so the theme,
## the lamps and the show are what he sees), lets it settle, freezes it, then parks the camera over each street with
## the rig's own pose function and saves a JPEG. Run twice by `make terminus-streets`: once on the round-9 layout
## frozen in tests/arena/before/, once on the shipping one.
##
##   godot --path . --resolution 1920x1080 --script res://tests/arena/street_shots.gd -- --skirmish --mute --seed=3 \
##       --arena=terminus --street-shots=/abs/out/dir --street-shots-tag=after

## The streets, each at his default heading (0: the camera behind green, looking north up the map) and, for the
## ring road, also looking ALONG it: at the default heading it runs across the screen, where a gap reads 2.8x
## narrower than the same gap in depth (research C11). Focus points are mid-street, where the furniture was.
const STREETS := [
	{"key": "avenue", "label": "the avenue (between the z = 62 blocks)", "at": [0.0, 60.0], "heading_deg": 0.0},
	{"key": "west_street", "label": "west street (between the z = 0 blocks)", "at": [-70.0, 6.0], "heading_deg": 0.0},
	{"key": "east_street", "label": "east street (between the z = 0 blocks)", "at": [70.0, -4.0], "heading_deg": 0.0},
	{"key": "ring_road", "label": "the ring road, across the screen (default heading)", "at": [-30.0, 31.0], "heading_deg": 0.0},
	{"key": "ring_road_along", "label": "the ring road, looking along it", "at": [-40.0, 31.0], "heading_deg": 90.0},
	{"key": "plaza", "label": "the plaza and its crossings", "at": [0.0, 10.0], "heading_deg": 0.0},
	{"key": "junction_west", "label": "west street x the ring road", "at": [-70.0, 30.0], "heading_deg": 0.0},
]
const SETTLE_S := 4.0
const DISTANCE_M := 49.0

var out_dir := ""
var tag := "after"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var flags := LaunchFlags.from_environment()
	out_dir = flags.text("street-shots")
	tag = flags.text("street-shots-tag", "after")
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
		(layer as CanvasLayer).visible = false  # the street, not the HUD: the pair compares ground
	var camera: Camera3D = main.get("camera")
	camera.current = true
	camera.fov = RtsCamera.FOV_DEG
	var frames: Array = []
	for street: Dictionary in STREETS:
		var at := Vector3(street["at"][0], 0.0, street["at"][1])
		var heading := deg_to_rad(float(street["heading_deg"]))
		camera.global_transform = RtsCamera.pose_at(at, heading, DISTANCE_M, RtsCamera.DEFAULT_PITCH_DEG)
		camera.near = 0.3
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_viewport().get_texture().get_image()
		var file := "%s_%s.jpg" % [street["key"], tag]
		if image != null and not image.is_empty():
			image.save_jpg(out_dir.path_join(file), 0.86)
		frames.append({"key": street["key"], "label": street["label"], "file": file, "at": street["at"],
				"heading_deg": street["heading_deg"]})
		print("STREET_SHOT %s %s" % [tag, file])
	var meta := FileAccess.open(out_dir.path_join("%s.json" % tag), FileAccess.WRITE)
	meta.store_string(JSON.stringify({"tag": tag, "arena": String(Arena.active.get("name", "")), "pitch": RtsCamera.DEFAULT_PITCH_DEG,
			"fov": RtsCamera.FOV_DEG, "distance": DISTANCE_M, "frames": frames}, "  "))
	meta.close()
	print("STREET_SHOTS_DONE tag=%s frames=%d" % [tag, frames.size()])
	quit(0)


func _all(node: Node, keep: Callable) -> Array:
	var out: Array = []
	if keep.call(node):
		out.append(node)
	for child in node.get_children():
		out.append_array(_all(child, keep))
	return out
