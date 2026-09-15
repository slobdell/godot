extends SceneTree
## Close-up turnaround of an assembled tank unit from a generated theme: hull + turret + cannon placed the way
## game/tank/tank.tscn places the slots (turret pivot at 1.22 m, 0.2 m back), four angles in one sheet.
##   godot --path . --script res://assets/pipeline/unit_view.gd -- <theme> <out.png> <day|night> [turret yaw°] [unit id]
## `make assets-unit THEME=prison_dozer` renders day + night; `UNIT=ifv THEME=roster` assembles unit.ifv.* at the IFV's
## own turret pivot and scale (AssetContracts.unit_pivot). The gallery's camera is too far to judge detail.

const TURRET_PIVOT := Vector3(0.0, 1.22, 0.2)
const TEAM_COLOR := Color(0.33, 0.4, 0.22)  # the default theme's green team
const VIEWS := [Vector3(-1.0, 0.55, -1.0), Vector3(1.0, 0.5, 1.0), Vector3(1.0, 0.25, 0.0), Vector3(0.001, 1.8, 0.4)]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var night: bool = args.size() > 2 and args[2] == "night"
	var slots := AssetIO.theme_slots(args[0])
	var unit_id: String = args[4] if args.size() > 4 else ""
	var names := ["tank.hull", "tank.turret", "weapon.cannon"]
	var pivot_position := TURRET_PIVOT
	var turret_scale := 1.0
	if unit_id != "":
		names = ["unit.%s.hull" % unit_id, "unit.%s.turret" % unit_id, "unit.%s.weapon" % unit_id]
		var placement := AssetContracts.unit_pivot(unit_id)
		pivot_position = placement["pivot"]
		turret_scale = placement["turret_scale"]
	var unit := Node3D.new()
	root.add_child(unit)
	var parts: Array[Node] = [(load(slots[names[0]]) as PackedScene).instantiate()]
	unit.add_child(parts[0])
	var pivot := Node3D.new()
	pivot.position = pivot_position
	pivot.scale = Vector3.ONE * turret_scale
	pivot.rotation_degrees.y = float(args[3]) if args.size() > 3 else 0.0
	unit.add_child(pivot)
	for slot in names.slice(1):
		if not slots.has(slot):
			continue  # e.g. the scout has no turret, the artillery no barrel
		parts.append((load(slots[slot]) as PackedScene).instantiate())
		pivot.add_child(parts[-1])
	var marker := MeshInstance3D.new()  # where gameplay's rounds leave (Tank.muzzle_position)
	var dot := SphereMesh.new()
	dot.radius = 0.08
	dot.height = 0.16
	var red := StandardMaterial3D.new()
	red.albedo_color = Color.RED
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot.material = red
	marker.mesh = dot
	marker.position = Vector3(0, 0.05, -3.2)
	pivot.add_child(marker)
	for part in parts:
		if part.has_method("set_team_color"):
			part.call("set_team_color", TEAM_COLOR)
	_add_stage(night)

	var camera := Camera3D.new()
	camera.fov = 32.0
	root.add_child(camera)
	camera.current = true
	var center := Vector3(0.0, 1.0, -0.5)
	var shots := []
	for view in VIEWS:
		camera.position = center + (view as Vector3).normalized() * 9.5
		camera.look_at(center)
		for frame in 5:
			await RenderingServer.frame_post_draw
		shots.append(root.get_viewport().get_texture().get_image())
	var width: int = shots[0].get_width()
	var height: int = shots[0].get_height()
	var sheet := Image.create(width * 2, height * 2, false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, width, height), Vector2i((i % 2) * width, (i / 2) * height))
	sheet.save_png(args[1])
	print("UNIT_VIEW saved ", args[1])
	quit()


func _add_stage(night: bool) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.05, 0.05, 0.07) if night else Color(0.22, 0.22, 0.24)
	plane.material = ground_material
	ground.mesh = plane
	root.add_child(ground)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.02, 0.05) if night else Color(0.35, 0.38, 0.45)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.33, 0.5) if night else Color(0.7, 0.72, 0.8)
	environment.ambient_light_energy = 0.5 if night else 0.8
	environment.glow_enabled = true
	environment.glow_intensity = 1.2 if night else 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 0.25 if night else 1.2
	root.add_child(sun)
