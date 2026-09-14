extends Node3D
## LOD probe: how many primitives the renderer draws for a slot scene at increasing camera
## distances, i.e. whether imported mesh LODs kick in on this renderer. Prints LOD_PROBE lines.
##   godot --path . res://assets/pipeline/lod_probe.tscn -- --scene=res://game/theme/kitbash/generated/tank_hull.tscn [--lod-threshold=1.0] [--count=1]

const DISTANCES := [4.0, 15.0, 30.0, 60.0, 120.0, 240.0]


func _ready() -> void:
	var flags := LaunchFlags.from_environment()
	var path := flags.text("scene", "res://game/theme/kitbash/generated/tank_hull.tscn")
	var count := int(flags.text("count", "1"))
	get_viewport().mesh_lod_threshold = float(flags.text("lod-threshold", "1.0"))
	for i in count:
		var node := (load(path) as PackedScene).instantiate() as Node3D
		node.position = Vector3((i % 10) * 3.0, 0, (i / 10) * 4.0)
		add_child(node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	for distance in DISTANCES:
		camera.position = Vector3(0, distance * 0.6, distance)
		camera.look_at(Vector3.ZERO)
		for frame in 5:
			await RenderingServer.frame_post_draw
		print("LOD_PROBE %s threshold=%.1f count=%d distance=%.0f primitives=%d draw_calls=%d" % [path.get_file(),
				get_viewport().mesh_lod_threshold, count, distance,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	get_tree().quit()
