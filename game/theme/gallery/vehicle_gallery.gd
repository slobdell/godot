extends Node3D
## Vehicle + weapon FX gallery (`make vehicle-gallery`): both teams' tanks up close under the active
## theme's environment, each slot's optional methods driven with fake values so the looks exist
## before gameplay calls them: set_team_color, set_firing (flamethrower), set_heat (cannon cycles
## cold → hot), and later set_shield / weapon.laser / fx.laser_beam (L5). Visual only.
## Flags: --theme=NAME (default cyberpunk) --screenshot=<abs png> [--screenshot-delay=S] [--gallery-time=S]

const ORBIT_SPEED := 0.25

var camera := Camera3D.new()
var time := 0.0
var tanks: Array[Node3D] = []
var _flags: LaunchFlags


func _ready() -> void:
	_flags = LaunchFlags.from_environment()
	if not _flags.has("theme"):
		GameTheme.use("cyberpunk")
	time = float(_flags.text("gallery-time", "0"))
	for slot_name in ["arena.environment", "arena.dressing"]:
		var slot := VisualSlot.new()
		slot.slot = slot_name
		add_child(slot)
	camera.fov = 50.0
	add_child(camera)
	camera.current = true
	var weapons := ["weapon.cannon", "weapon.flamethrower", "weapon.cannon", "weapon.flamethrower"]
	for i in 4:
		var team := i % 2
		var tank := _tank(team, weapons[i])
		tank.position = Vector3(-7.5 + i * 5.0, 0, 0)
		tank.rotation.y = 0.5 - i * 0.3
		tanks.append(tank)
	var overlay := PerfOverlay.new()
	add_child(overlay)
	overlay.extra = "VEHICLE GALLERY (%s)" % GameTheme.theme_name
	if _flags.has("screenshot"):
		_capture(_flags.text("screenshot"), float(_flags.text("screenshot-delay", "3")))


func _process(delta: float) -> void:
	time += delta
	var angle := 0.6 + sin(time * ORBIT_SPEED) * 0.5
	camera.position = Vector3(sin(angle) * 16.0, 7.5, cos(angle) * 16.0)
	camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	for i in tanks.size():
		var tank := tanks[i]
		var turret := tank.get_node("Turret") as Node3D
		turret.rotation.y = sin(time * 0.6 + i) * 0.6
		var weapon := turret.get_node("Weapon") as VisualSlot
		# Heat cycles 0 → 1 → 0 over 6 s; flamethrowers fire in bursts.
		var heat := 0.5 - 0.5 * cos(time * TAU / 6.0 + i)
		weapon.invoke("set_heat", [heat])
		(tank.get_node("Hull") as VisualSlot).invoke("set_heat", [heat])
		if weapon.slot == "weapon.flamethrower":
			weapon.invoke("set_firing", [fmod(time + i, 3.0) < 2.0])


func _tank(team: int, weapon_slot: String) -> Node3D:
	var tank := Node3D.new()
	tank.name = "Tank%d" % tanks.size()
	add_child(tank)
	var hull := VisualSlot.new()
	hull.name = "Hull"
	hull.slot = "tank.hull"
	tank.add_child(hull)
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 1.22, 0.2)
	tank.add_child(turret)
	var body := VisualSlot.new()
	body.name = "Body"
	body.slot = "tank.turret"
	turret.add_child(body)
	var weapon := VisualSlot.new()
	weapon.name = "Weapon"
	weapon.slot = weapon_slot
	turret.add_child(weapon)
	weapon.invoke("setup", [Weapons.profile("flamethrower") if weapon_slot == "weapon.flamethrower" else {}])
	for slot in [hull, body, weapon]:
		slot.invoke("set_team_color", [GameTheme.team_color(team)])
	return tank


func _capture(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved: " if err == OK else "screenshot failed: ", path)
	get_tree().quit(err)
