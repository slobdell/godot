extends Node3D
## Vehicle + weapon FX gallery (`make vehicle-gallery`): both teams' tanks up close under the active
## theme's environment, each slot's optional methods driven with fake values so the looks exist
## before gameplay calls them: set_team_color, set_firing (flamethrowers burst, lasers pulse),
## set_heat (weapons cycle cold → hot), set_shield (hit, hit, break, recharge), and fx.laser_beam
## pulses spawned exactly like Match.show_beam (a slot per pulse, freed after 0.2 s). Visual only.
## Flags: --theme=NAME (default cyberpunk) --screenshot=<abs png> [--screenshot-delay=S] [--gallery-time=S]
##        --gallery-focus=N (close-up on tank N)
##        --gallery-units: the round-2 roster instead (tank, scout, IFV, artillery, Lancer; both teams), each unit's
##        own slots at its own turret pivot and scale, the way Tank places them (catalog v2, C6)
##        --gallery-deploy: three crane carriers side by side, stowed, half deployed, and braced (assets X5,
##        the hull slot's set_deployed); `make artillery-deploy-shot`

const ORBIT_SPEED := 0.25
## Catalog v2 numbers the gallery needs to place per-unit art like Tank does (rules' Units.PROFILES; mirrored in
## assets/pipeline/asset_contracts.gd, which isn't exported).
const ROSTER := {
	"tank": {"hull_size": Vector3(2.4, 1.6, 3.6), "muzzle_height": 1.27},
	"scout": {"hull_size": Vector3(2.0, 1.4, 3.0), "muzzle_height": 1.12},
	"ifv": {"hull_size": Vector3(2.4, 1.6, 3.8), "muzzle_height": 1.27},
	"artillery": {"hull_size": Vector3(2.6, 1.6, 4.0), "muzzle_height": 1.27},
	"lancer": {"hull_size": Vector3(2.4, 1.6, 3.8), "muzzle_height": 1.27},
}

var camera := Camera3D.new()
var time := 0.0
var tanks: Array[Node3D] = []
var _flags: LaunchFlags
var _targets: Array[Node3D] = []
var _next_pulse := 0.0
## Shield script per tank index: ratio over time (hit, hit, break, recharge).
var _shield_clock := 0.0


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
	if _flags.has("gallery-units"):
		var i := 0
		for unit in ROSTER:
			for team in 2:
				var tank := _unit_tank(unit, team)
				tank.position = Vector3(-18.0 + i * 4.2, 0, -4.0 * team)
				tank.rotation.y = 0.5 - i * 0.1
				tanks.append(tank)
				i += 1
	if _flags.has("gallery-deploy"):
		for i in 3:
			var carrier := _unit_tank("artillery", 0)
			carrier.position = Vector3(-5.2 + i * 5.2, 0, 0)
			carrier.rotation.y = 0.0
			(carrier.get_node("Hull") as VisualSlot).invoke("set_deployed", [i * 0.5])
			tanks.append(carrier)
	var weapons := [] if _flags.has("gallery-units") or _flags.has("gallery-deploy") else ["weapon.cannon", "weapon.laser", "weapon.flamethrower", "weapon.laser", "weapon.cannon", "weapon.flamethrower"]
	for i in weapons.size():
		var team := i % 2
		var tank := _tank(team, weapons[i])
		tank.position = Vector3(-12.5 + i * 5.0, 0, 0)
		tank.rotation.y = 0.5 - i * 0.2
		tanks.append(tank)
	for i in 3:
		var target := Node3D.new()
		target.position = Vector3(-10.0 + i * 10.0, 1.0, -26.0)
		add_child(target)
		_targets.append(target)
	var overlay := PerfOverlay.new()
	add_child(overlay)
	overlay.extra = "VEHICLE GALLERY (%s)" % GameTheme.theme_name
	if _flags.has("screenshot"):
		_capture(_flags.text("screenshot"), float(_flags.text("screenshot-delay", "3")))


func _process(delta: float) -> void:
	time += delta
	if _flags.has("gallery-deploy"):
		camera.position = Vector3(0.0, 9.0, 7.5)
		camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	elif _flags.has("gallery-focus"):
		var focus := tanks[clampi(_flags.integer("gallery-focus", 0), 0, tanks.size() - 1)].global_position
		camera.position = focus + Vector3(4.5, 4.0, 7.5)
		camera.look_at(focus + Vector3(0, 1.0, 0), Vector3.UP)
	else:
		var angle := 0.6 + sin(time * ORBIT_SPEED) * 0.5
		camera.position = Vector3(sin(angle) * 21.0, 9.0, cos(angle) * 21.0)
		camera.look_at(Vector3(0, 1.0, -4.0), Vector3.UP)
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
		if not _flags.has("gallery-deploy"):
			(tank.get_node("Hull") as VisualSlot).invoke("set_shield", [_shield_ratio(fmod(time + i * 0.9, 6.0))])
	# Laser tanks pulse like gameplay does: a fresh fx.laser_beam slot per pulse, freed after 0.2 s.
	if time >= _next_pulse:
		_next_pulse = time + 0.3
		for i in tanks.size():
			var weapon := tanks[i].get_node("Turret/Weapon") as VisualSlot
			if weapon.slot != "weapon.laser":
				continue
			weapon.invoke("set_firing", [true])
			var muzzle := weapon.global_transform * Vector3(0, 0.05, -3.25)
			var target := _targets[(i + int(time * 2.0)) % _targets.size()].global_position
			var beam := VisualSlot.new()
			beam.slot = "fx.laser_beam"
			add_child(beam)
			beam.invoke("setup", [muzzle, target])
			get_tree().create_timer(0.2).timeout.connect(beam.queue_free)


## A 6 s shield story: two hits, a break, a pause, then recharge.
static func _shield_ratio(t: float) -> float:
	if t < 1.0:
		return 1.0
	if t < 2.0:
		return 0.6
	if t < 3.0:
		return 0.25
	if t < 3.8:
		return 0.0
	return clampf((t - 3.8) / 2.2, 0.0, 1.0)


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
	weapon.invoke("setup", [Weapons.profile(weapon_slot.trim_prefix("weapon."))])
	for slot in [hull, body, weapon]:
		slot.invoke("set_team_color", [GameTheme.team_color(team)])
	# Every third tank wears player paint (full body); friend or foe still reads from the accents.
	if tanks.size() % 3 == 2:
		for slot in [hull, body, weapon]:
			slot.invoke("set_paint", [[Color("#C8A030"), Color("#B03060"), Color("#3A7040")][tanks.size() % 3]])
	return tank


## A unit with its own slots (falling back to the tank's), placed like Tank._apply_hull_size.
func _unit_tank(unit: String, team: int) -> Node3D:
	var info: Dictionary = ROSTER[unit]
	var size: Vector3 = info["hull_size"]
	var tank := Node3D.new()
	tank.name = "Tank%d" % tanks.size()
	add_child(tank)
	var hull := VisualSlot.new()
	hull.name = "Hull"
	hull.slot = _slot_or("unit.%s.hull" % unit, "tank.hull")
	tank.add_child(hull)
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, float(info["muzzle_height"]) - 0.05, 0.2)
	if unit != "tank":
		turret.scale = Vector3.ONE * minf(size.x / 2.4, size.z / 3.6)
	tank.add_child(turret)
	var body := VisualSlot.new()
	body.name = "Body"
	body.slot = _slot_or("unit.%s.turret" % unit, "tank.turret")
	turret.add_child(body)
	var weapon := VisualSlot.new()
	weapon.name = "Weapon"
	weapon.slot = _slot_or("unit.%s.weapon" % unit, "weapon.cannon")
	turret.add_child(weapon)
	for slot in [hull, body, weapon]:
		slot.invoke("set_team_color", [GameTheme.team_color(team)])
	return tank


func _slot_or(slot: String, fallback: String) -> String:
	return slot if GameTheme.slots.has(slot) else fallback


func _capture(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved: " if err == OK else "screenshot failed: ", path)
	get_tree().quit(err)
