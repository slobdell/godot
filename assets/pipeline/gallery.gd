extends Node3D
## Asset gallery: every model in a generated theme, next to the default theme's placeholder and
## a translucent box showing the slot contract, so size, orientation, anchor, and team tint can
## be judged from one screenshot. Tanks are assembled the way tank.tscn places the slots, with a
## red marker where gameplay spawns shells.
##   godot --path . res://assets/pipeline/gallery.tscn -- --theme=kitbash [--screenshot=/abs.png] [--only=kit.] [--night]
## --night: a dark arena (low moonlight, strong glow), the way the cyberpunk theme will show emissive neon.
## `make assets-gallery THEME=kitbash` wraps it.

## From game/tank/tank.tscn: where the turret pivot sits on the hull.
const TURRET_PIVOT := Vector3(0.0, 1.22, 0.2)
const MUZZLE := Vector3(0.0, 0.05, -3.2)
const TEAM_TINT := Color(0.0, 0.85, 0.95)

var _bounds := AABB()
var _night := false


func _ready() -> void:
	var flags := LaunchFlags.from_environment()
	var theme := flags.text("theme", "kitbash")
	var only := flags.text("only", "")
	_night = flags.has("night")
	var manifest := AssetIO.read_manifest(theme)
	var entries: Dictionary = manifest["slots"]
	_add_environment(flags.has("night"))

	var row_z := 0.0
	if entries.has("tank.hull") and (only == "" or "tank.hull".begins_with(only)):
		_add_tank(Vector3(-2.2, 0, 0), func(slot: String) -> String: return AssetIO.theme_slots(theme).get(slot, ""), "%s tank" % theme)
		_add_tank(Vector3(2.2, 0, 0), func(slot: String) -> String: return GameTheme.DEFAULT_SLOTS.get(slot, ""), "default tank")
		row_z = -9.0

	var x := 0.0
	for slot in entries:
		if slot.begins_with("tank.") or slot.begins_with("weapon.") or (only != "" and not slot.begins_with(only)):
			continue
		var contract := AssetContracts.get_contract(slot)
		var guide: Vector3 = contract["guide"]
		var at := Vector3(x + guide.x / 2.0, 0, row_z - guide.z / 2.0)
		_place_scene("%s/%s" % [AssetIO.generated_dir(theme), entries[slot]["scene"]], at, true)
		_add_ghost(guide, at, contract["anchor"])
		_add_label("%s\n%d tris" % [slot, int(entries[slot].get("tris", 0))], at + Vector3(0, guide.y + 1.0, 0))
		if GameTheme.DEFAULT_SLOTS.has(slot) and slot.begins_with("prop."):
			var beside := at + Vector3(0, 0, -guide.z - 2.0)
			_place_scene(GameTheme.DEFAULT_SLOTS[slot], beside, false)
			_add_label("default", beside + Vector3(0, guide.y + 0.6, 0))
			_grow(AABB(beside - guide / 2.0, guide))
		x += guide.x + 2.5

	_frame_camera()
	print("ASSET_GALLERY_READY theme=%s" % theme)
	if flags.has("screenshot"):
		await get_tree().create_timer(float(flags.text("screenshot-delay", "1.5"))).timeout
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(flags.text("screenshot"))
		print("gallery screenshot %s: %s" % ["saved" if error == OK else "FAILED", flags.text("screenshot")])
		get_tree().quit(error)


func _add_tank(origin: Vector3, scene_for: Callable, title: String) -> void:
	var hull := _place_scene(scene_for.call("tank.hull"), origin, true)
	var turret_origin := origin + TURRET_PIVOT
	var turret := _place_scene(scene_for.call("tank.turret"), turret_origin, true)
	var cannon := _place_scene(scene_for.call("weapon.cannon"), turret_origin, true)
	if hull == null and turret == null and cannon == null:
		return
	_add_ghost(Vector3(2.4, 1.6, 3.6), origin, "ground_center")
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color.RED
	sphere.material = red
	marker.mesh = sphere
	marker.position = turret_origin + MUZZLE
	add_child(marker)
	_add_label(title, origin + Vector3(0, 3.0, 0))
	_grow(AABB(origin + Vector3(-1.2, 0, -3.4), Vector3(2.4, 2.6, 5.4)))


func _place_scene(path: String, at: Vector3, tint: bool) -> Node3D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var node := (load(path) as PackedScene).instantiate() as Node3D
	node.position = at
	add_child(node)
	if tint and node.has_method("set_team_color"):
		node.call("set_team_color", TEAM_TINT)
	var report := AssetInspector.inspect(node)
	var aabb: AABB = report["aabb"]
	_grow(AABB(aabb.position + at, aabb.size))
	return node


func _add_ghost(size: Vector3, at: Vector3, anchor: String) -> void:
	if _night:
		return  # the ghosts wash out the neon; judge sizes in the day gallery
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.9, 0.2, 0.06)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	box.material = material
	var ghost := MeshInstance3D.new()
	ghost.mesh = box
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.position = at + (Vector3(0, size.y / 2.0, 0) if anchor == "ground_center" else Vector3.ZERO)
	add_child(ghost)


func _add_label(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.02
	label.outline_size = 8
	label.position = at
	add_child(label)


func _add_environment(night: bool) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.02, 0.06) if night else Color(0.09, 0.1, 0.13)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.25, 0.28, 0.45) if night else Color(0.55, 0.58, 0.65)
	environment.ambient_light_energy = 0.8 if night else 0.6
	environment.glow_enabled = true
	environment.glow_intensity = 1.2 if night else 0.8
	environment.glow_bloom = 0.15 if night else 0.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 0.3 if night else 1.0
	sun.light_color = Color(0.6, 0.7, 1.0) if night else Color.WHITE
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.07, 0.07, 0.09) if night else Color(0.18, 0.19, 0.21)
	plane.material = dark
	ground.mesh = plane
	add_child(ground)


func _grow(box: AABB) -> void:
	_bounds = box if _bounds.size == Vector3.ZERO else _bounds.merge(box)


func _frame_camera() -> void:
	var camera := Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	var center := _bounds.get_center()
	var radius := maxf(_bounds.size.length() * 0.5, 3.0)
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var tightness := 0.62 if radius > 15.0 else 1.0  # big layouts can crop the empty corners; small ones can't
	var distance := radius / tan(deg_to_rad(camera.fov * 0.5)) * (1.0 if aspect >= 1.0 else 1.0 / aspect) * tightness
	camera.position = center + Vector3(0.55, 0.6, 1.0).normalized() * distance
	camera.look_at(center)
	camera.current = true
