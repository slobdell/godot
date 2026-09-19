extends SceneTree
## `make facing-audit` (feel, round 7; the lead: "the gang's IFV drives backwards"): every faction unit's art, one image
## each, side-on, with a red arrow along the engine's forward (-Z: trip-up 2). A model authored facing +Z drives
## tail-first while every other vehicle behaves, and only a look catches it: a 180 degree error hides in plain sight and
## a 90 degree one more so. Saves <dir>/<unit>.png and a contact sheet order in FACING_AUDIT lines, then quits.
## Visual only. Flags: --facing-dir=<abs dir> [--facing-units=a,b] [--facing-turret=DEG] (turn every turret: a gun
## cut out of its hull, FactionArt.GUN_CUTS, must turn with it and leave the hull whole)

const SIZE := Vector2i(960, 540)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var flags := LaunchFlags.from_environment()
	var out := flags.text("facing-dir", "/tmp/facing")
	DirAccess.make_dir_recursive_absolute(out)
	GameTheme.use("cyberpunk")
	root.size = SIZE
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.17, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(sun)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	var units: Array = []
	var only := Array(flags.text("facing-units").split(",", false))
	for faction in ["condemned", "gangs", "law", "syndicate"]:
		for unit_id in Units.roster(faction):
			if only.is_empty() or only.has(unit_id):
				units.append(unit_id)
	var tank_scene := load("res://game/tank/tank.tscn") as PackedScene
	for unit_id: String in units:
		var tank: Node3D = tank_scene.instantiate()
		tank.set("unit_id", unit_id)
		tank.set("simulate", false)
		world.add_child(tank)
		var hold_turret := flags.has("facing-turret")
		var turret_deg := float(flags.text("facing-turret", "0"))
		if hold_turret:
			(tank.get_node("Turret") as Node3D).rotation.y = deg_to_rad(turret_deg)
		for label in tank.find_children("*", "Label3D", true, false):
			(label as Node3D).visible = false  # the nameplate covers the vehicle side-on
		var length := float(Units.stat(unit_id, "hull_size")[2])
		# Forward (-Z) points to the right of the picture: the camera looks along -X from the unit's right side.
		var arrow := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.25, 0.25, 3.0)
		arrow.mesh = box
		var red := StandardMaterial3D.new()
		red.albedo_color = Color(1, 0.1, 0.1)
		red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		arrow.material_override = red
		arrow.position = Vector3(0, 0.15, -length / 2.0 - 2.0)
		world.add_child(arrow)
		var height := float(Units.stat(unit_id, "hull_size")[1])
		var distance := maxf(length + 4.0, 6.0) * 1.15
		camera.fov = 40.0
		camera.global_transform = Transform3D(Basis(), Vector3(distance, height * 0.6 + 0.8, -1.0)).looking_at(
				Vector3(0, height * 0.5, -1.0), Vector3.UP)
		for i in 8:
			if hold_turret:  # the tank drives its turret itself: hold it where the audit wants it (0 = straight ahead)
				(tank.get_node("Turret") as Node3D).rotation.y = deg_to_rad(turret_deg)
			await process_frame
		if hold_turret:
			(tank.get_node("Turret") as Node3D).rotation.y = deg_to_rad(turret_deg)
			await process_frame
		await RenderingServer.frame_post_draw
		var path := out.path_join("%s.png" % unit_id)
		root.get_texture().get_image().save_png(path)
		print("FACING_AUDIT %s -> %s (forward: the red arrow, to the right)" % [unit_id, path])
		tank.queue_free()
		arrow.queue_free()
		await process_frame
	print("FACING_AUDIT_DONE")
	quit()
