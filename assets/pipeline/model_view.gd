extends SceneTree
## Turnaround sheet of a raw model (a generator download, before normalizing): four views, auto-framed, with the
## island count and bounds printed, so you can decide --forward, --split and --include before running the pipeline.
##   godot --path . --resolution 900x600 --script res://assets/pipeline/model_view.gd -- <in.glb> <out.png> [--split [--forward=+x]]
## `make assets-view IN=assets/incoming/meshy/x.glb [SPLIT=1]`. With --split the islands are tinted by the
## AssetSplitter's tank labels (hull grey, turret cyan, cannon magenta) and seen from the source's own +X/+Z axes.

const VIEWS := [Vector3(1.0, 0.6, 1.0), Vector3(-1.0, 0.6, -1.0), Vector3(1.0, 0.15, 0.0), Vector3(0.0, 0.15, 1.0)]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var model := AssetIO.load_glb(args[0])
	if model == null:
		quit(1)
		return
	root.add_child(model)
	var report := AssetInspector.inspect(model)
	print(AssetInspector.summary(report))
	if "--split" in args:
		print("islands: %d" % AssetSplitter.split_islands(model))
		var forward := "+z"
		for arg in args:
			if arg.begins_with("--forward="):
				forward = arg.trim_prefix("--forward=")
		var regions := {}
		for arg in args:
			for label in ["cannon", "turret"]:
				if arg.begins_with("--%s-box=" % label):
					regions[label] = AssetSplitter.parse_box(arg.get_slice("=", 1))
		var counts := AssetSplitter.label_regions(model, forward, "+y", regions) if not regions.is_empty() \
				else AssetSplitter.label_tank(model, forward, "+y")
		print("tank labels (forward %s): %s" % [forward, counts])
		_tint_labels(model)
	var aabb: AABB = AssetInspector.inspect(model)["aabb"]
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.3, 0.32, 0.36)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	environment.ambient_light_energy = 0.9
	var world := WorldEnvironment.new()
	world.environment = environment
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.3
	root.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 35.0
	root.add_child(camera)
	camera.current = true
	var center := aabb.get_center()
	var distance := aabb.size.length() * 1.6
	var shots := []
	for view in VIEWS:
		camera.position = center + (view as Vector3).normalized() * distance
		camera.look_at(center, Vector3.UP if absf((view as Vector3).normalized().y) < 0.99 else Vector3.FORWARD)
		for frame in 5:
			await RenderingServer.frame_post_draw
		shots.append(root.get_viewport().get_texture().get_image())
	var width: int = shots[0].get_width()
	var height: int = shots[0].get_height()
	var sheet := Image.create(width * 2, height * 2, false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, width, height), Vector2i((i % 2) * width, (i / 2) * height))
	sheet.save_png(args[1])
	print("MODEL_VIEW saved %s (views: +X+Z corner, -X-Z corner, from +X, from +Z)" % args[1])
	quit()


func _tint_labels(model: Node) -> void:
	var colors := {"hull": Color(0.6, 0.6, 0.6), "turret": Color(0.1, 0.9, 1.0), "cannon": Color(1.0, 0.2, 0.7)}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		for label in colors:
			if instance.name.begins_with(label + "_"):
				var material := StandardMaterial3D.new()
				material.albedo_color = colors[label]
				instance.material_override = material
