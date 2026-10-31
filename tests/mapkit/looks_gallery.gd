extends Node3D
## The map kit's looks page renders (mapkit P1, round 47; `make remote T="mapkit-looks DISPLAY=:1 ..."`, mk/mapkit.mk):
## two or three DIRECTIONS for each new cheap piece (blast doors, sight screens, the overpass, tank traps, and the
## stretch pipe racks and gantry crane), built from the kit's own primitives -- boxes and low-sided cylinders on
## CyberMaterials' shared surfaces, glow as emission, no real lights -- under the cyberpunk arena's night lighting,
## each shot from the lead's camera (21 degrees, FOV 35, 49 m) beside a dozer for scale. Concept geometry only: the
## direction he picks is rebuilt as a `prop.<type>` scene (one MultiMesh per kind, like KitYard) in the same commit as
## its ArenaKit type. Visual only; nothing here collides.
## Flags: --shots-dir=<abs dir> (saves looks-<direction>.png for every direction, then quits) [--only=a,b]
##        [--yaw=<deg>] (turn the camera about the piece; default 0, looking north like his default heading)

## His default pose (camera planner's base): pitch 21 degrees, 49 m from the ground point, FOV 35.
const PITCH_DEG := 21.0
const DISTANCE := 49.0
const FOV := 35.0
## The widest hull (Units: syn_artillery 4.07 m) needs 12.14 m physical in a lane (arenas.md *Streets are lanes*),
## so every gate or gap here is at least 14 m.
const GATE_WIDTH := 14.0
## Above the tallest hull (6.18 m) with room for its antennae.
const GATE_HEIGHT := 7.5

const STEEL := Color(0.16, 0.17, 0.19)
const GUNMETAL := Color(0.24, 0.25, 0.28)
const CONCRETE := Color(0.22, 0.22, 0.23)
const TARP := Color(0.11, 0.12, 0.13)
const STEAM_SHADER := preload("res://tests/mapkit/looks_steam.gdshader")

## direction id → [piece, method, focus (ground point the camera looks at)]
const DIRECTIONS := {
	"door_a_shut": ["door", "_door_vault", false],
	"door_a_open": ["door", "_door_vault", true],
	"door_b_shut": ["door", "_door_shutter", false],
	"door_b_open": ["door", "_door_shutter", true],
	"door_c_shut": ["door", "_door_drop", false],
	"door_c_open": ["door", "_door_drop", true],
	"screen_a": ["screen", "_screen_holo", false],
	"screen_b": ["screen", "_screen_strips", false],
	"screen_c": ["screen", "_screen_steam", false],
	"overpass_a": ["overpass", "_overpass_rail", false],
	"overpass_b": ["overpass", "_overpass_highway", false],
	"overpass_c": ["overpass", "_overpass_monorail", false],
	"traps_a": ["traps", "_traps_hedgehogs", false],
	"traps_b": ["traps", "_traps_teeth", false],
	"traps_c": ["traps", "_traps_bollards", false],
	"pipes_a": ["pipes", "_pipes_rack", false],
	"pipes_b": ["pipes", "_pipes_ground", false],
	"crane_a": ["crane", "_crane_gantry", false],
	# P4: the BUILT props (his picks), through their real prop.<type> slots, for the look check.
	"built_traps": ["traps", "_built_traps", false],
	"built_monorail": ["overpass", "_built_monorail", false],
	"built_screen": ["screen", "_built_screen", false],
	"built_door_shut": ["door", "_built_door", false],
	"built_door_open": ["door", "_built_door", true],
}

var camera := Camera3D.new()
var _flags: LaunchFlags
var _set: Node3D


func _ready() -> void:
	_flags = LaunchFlags.from_environment()
	GameTheme.use("cyberpunk")
	for slot_name in ["arena.environment", "arena.dressing"]:
		var slot := VisualSlot.new()
		slot.slot = slot_name
		add_child(slot)
	add_child(camera)
	camera.current = true
	camera.fov = FOV
	camera.far = 600.0
	_aim(float(_flags.text("yaw", "0")))
	if _flags.has("shots-dir"):
		_capture_all(_flags.text("shots-dir"))
	else:
		show_direction("door_a_shut")


func _aim(yaw_deg: float) -> void:
	var back := Vector3(0.0, sin(deg_to_rad(PITCH_DEG)), cos(deg_to_rad(PITCH_DEG))) * DISTANCE
	back = back.rotated(Vector3.UP, deg_to_rad(yaw_deg))
	camera.position = back
	camera.look_at(Vector3.ZERO, Vector3.UP)


func show_direction(id: String) -> void:
	if _set != null:
		_set.free()
	_set = Node3D.new()
	_set.name = "Set"
	add_child(_set)
	var spec: Array = DIRECTIONS[id]
	call(String(spec[1]), _set, bool(spec[2]))


func _capture_all(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var ids: Array = DIRECTIONS.keys()
	if _flags.has("only"):
		ids = Array(_flags.text("only").split(","))
	await get_tree().create_timer(2.0).timeout
	var failed := 0
	for id: String in ids:
		show_direction(id)
		for i in 8:
			await RenderingServer.frame_post_draw
		var path := folder.path_join("looks-%s.png" % id)
		var err := get_viewport().get_texture().get_image().save_png(path)
		print("MAPKIT_LOOKS draws=%d primitives=%d id=%s" % [
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), id])
		print("screenshot saved: " if err == OK else "screenshot failed: ", path)
		failed += int(err != OK)
	get_tree().quit(failed)


# --- shared helpers -------------------------------------------------------------------------------------------------

func _box(parent: Node3D, size: Vector3, center: Vector3, material: Material, yaw_deg := 0.0) -> MeshInstance3D:
	var box := CyberMaterials.box(parent, size, center, material)
	box.rotation.y = deg_to_rad(yaw_deg)
	return box


func _cylinder(parent: Node3D, radius_top: float, radius_bottom: float, height: float, center: Vector3,
		material: Material, sides := 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius_top
	mesh.bottom_radius = radius_bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	parent.add_child(instance)
	return instance


func _quad(parent: Node3D, size: Vector2, center: Vector3, material: Material) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## The dozer (tank.hull + tank.turret) for scale, the player's colour, nose toward `yaw_deg`.
func _dozer(parent: Node3D, at: Vector3, yaw_deg := 0.0, team := 0) -> void:
	var tank := Node3D.new()
	tank.position = at
	tank.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(tank)
	var hull := VisualSlot.new()
	hull.slot = "tank.hull"
	tank.add_child(hull)
	var turret := Node3D.new()
	turret.position = Vector3(0, 1.22, 0.2)
	tank.add_child(turret)
	var body := VisualSlot.new()
	body.slot = "tank.turret"
	turret.add_child(body)
	for slot in [hull, body]:
		slot.invoke("set_team_color", [GameTheme.team_color(team)])


## The arena wall a gate stands in: container-height concrete either side of the opening, out of frame.
func _gate_walls(parent: Node3D, height := GATE_HEIGHT + 1.5) -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * (GATE_WIDTH / 2.0 + 2.0 + 14.0)
		_box(parent, Vector3(28.0, height, 2.4), Vector3(x, height / 2.0, 0.0), CyberMaterials.surface(CONCRETE, 0.8, 0.05))
		# A cyan trim along the wall's top edge: the same neon the perimeter wears.
		_box(parent, Vector3(28.0, 0.12, 0.12), Vector3(x, height - 0.1, 1.25), CyberMaterials.neon(CyberMaterials.CYAN, 2.5, 0.0))


# --- 1. blast doors (the lead WANTS these; the announcer calls each one) ---------------------------------------------

## A: VAULT SLABS. Two armoured leaves slide sideways into the pylons; hazard chevrons on the faces; a header light
## that reads red when shut and green when open, and amber beacons on the pylons that the announcer's countdown times.
func _door_vault(root: Node3D, open: bool) -> void:
	_gate_walls(root)
	var pylon := CyberMaterials.surface(GUNMETAL, 0.45, 0.6)
	for side in [-1.0, 1.0]:
		var x: float = side * (GATE_WIDTH / 2.0 + 1.0)
		_box(root, Vector3(2.0, GATE_HEIGHT + 2.0, 3.4), Vector3(x, (GATE_HEIGHT + 2.0) / 2.0, 0.0), pylon)
		_cylinder(root, 0.35, 0.35, 0.5, Vector3(x, GATE_HEIGHT + 2.25, 0.8), CyberMaterials.neon(CyberMaterials.YELLOW, 4.0, 0.0), 8)
	_box(root, Vector3(GATE_WIDTH + 4.0, 1.4, 3.4), Vector3(0, GATE_HEIGHT + 0.7, 0.0), pylon)
	var lamp := CyberMaterials.GREEN if open else CyberMaterials.RED
	_box(root, Vector3(GATE_WIDTH - 1.0, 0.3, 0.1), Vector3(0, GATE_HEIGHT + 0.7, 1.75), CyberMaterials.neon(lamp, 4.0, 0.0))
	var leaf := CyberMaterials.surface(STEEL, 0.4, 0.7)
	var chevrons := CyberMaterials.panel(CyberMaterials.YELLOW, 7.0 / GATE_HEIGHT, 1.6, true)
	for side in [-1.0, 1.0]:
		var half := GATE_WIDTH / 2.0
		# Open: each leaf parked behind its wall (only its edge shows at the jamb).
		var x: float = side * (half / 2.0 + (half + 0.6 if open else 0.0))
		_box(root, Vector3(half, GATE_HEIGHT, 1.2), Vector3(x, GATE_HEIGHT / 2.0, -0.4 if open else 0.0), leaf)
		if not open:
			var face := _quad(root, Vector2(half - 0.6, GATE_HEIGHT - 1.2), Vector3(x, GATE_HEIGHT / 2.0, 0.62), chevrons)
			face.rotation.y = 0.0
	_dozer(root, Vector3(-3.0, 0, 9.0), 160.0)


## B: ROLL-UP SHUTTER. A segmented steel shutter that winds up into a lit header box; magenta neon on the bottom rail,
## so a half-open door reads as a gap you can judge. Garage-door familiar: it reads "this opens" at a glance.
func _door_shutter(root: Node3D, open: bool) -> void:
	_gate_walls(root)
	var frame := CyberMaterials.surface(GUNMETAL, 0.5, 0.5)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(1.2, GATE_HEIGHT + 2.6, 1.8), Vector3(side * (GATE_WIDTH / 2.0 + 0.6), (GATE_HEIGHT + 2.6) / 2.0, 0.0), frame)
	_box(root, Vector3(GATE_WIDTH + 2.4, 2.6, 2.6), Vector3(0, GATE_HEIGHT + 1.3, 0.0), frame)
	_box(root, Vector3(GATE_WIDTH + 2.4, 0.18, 0.1), Vector3(0, GATE_HEIGHT + 2.5, 1.32), CyberMaterials.neon(CyberMaterials.MAGENTA, 3.0, 0.0))
	var slat_h := 0.75
	var slats := 0 if open else int(GATE_HEIGHT / slat_h)
	for i in slats:
		var shade := STEEL if i % 2 == 0 else GUNMETAL
		_box(root, Vector3(GATE_WIDTH, slat_h - 0.06, 0.3), Vector3(0, slat_h * (i + 0.5), 0.0), CyberMaterials.surface(shade, 0.5, 0.6))
	var rail_y := GATE_HEIGHT - 0.1 if open else 0.12
	_box(root, Vector3(GATE_WIDTH, 0.24, 0.4), Vector3(0, rail_y, 0.0), CyberMaterials.neon(CyberMaterials.MAGENTA, 4.0, 0.0))
	# Hazard paint on the floor under the door: where not to stop.
	CyberMaterials.top_quad(root, Vector2(GATE_WIDTH, 3.0), Vector3(0, 0.03, 0.0), CyberMaterials.panel(CyberMaterials.YELLOW, GATE_WIDTH / 3.0, 1.2, true))
	_dozer(root, Vector3(-3.0, 0, 9.0), 160.0)


## C: DROP GATE. One slab rises out of a floor slot. Shut, its face is a giant holo countdown the crowd can read; open,
## the slot is a glowing strip across the street, so the player sees where the wall will come back up.
func _door_drop(root: Node3D, open: bool) -> void:
	_gate_walls(root)
	var frame := CyberMaterials.surface(GUNMETAL, 0.5, 0.5)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(1.6, GATE_HEIGHT + 1.0, 3.0), Vector3(side * (GATE_WIDTH / 2.0 + 0.8), (GATE_HEIGHT + 1.0) / 2.0, 0.0), frame)
		_box(root, Vector3(0.12, GATE_HEIGHT, 0.12), Vector3(side * (GATE_WIDTH / 2.0 + 0.05), GATE_HEIGHT / 2.0, 1.52), CyberMaterials.neon(CyberMaterials.ORANGE, 3.0, 0.0))
	var slot := CyberMaterials.neon(CyberMaterials.ORANGE if open else CyberMaterials.RED, 2.2, 0.0)
	CyberMaterials.top_quad(root, Vector2(GATE_WIDTH, 0.5), Vector3(0, 0.04, 1.0), slot)
	CyberMaterials.top_quad(root, Vector2(GATE_WIDTH, 0.5), Vector3(0, 0.04, -1.0), slot)
	if open:
		CyberMaterials.top_quad(root, Vector2(GATE_WIDTH, 1.6), Vector3(0, 0.03, 0.0), CyberMaterials.surface(STEEL, 0.3, 0.8))
	else:
		_box(root, Vector3(GATE_WIDTH, GATE_HEIGHT, 1.6), Vector3(0, GATE_HEIGHT / 2.0, 0.0), CyberMaterials.surface(STEEL, 0.35, 0.75))
		_quad(root, Vector2(GATE_WIDTH - 2.0, GATE_HEIGHT - 2.0), Vector3(0, GATE_HEIGHT / 2.0, 0.82),
				CyberMaterials.hologram(CyberMaterials.ORANGE, CyberMaterials.YELLOW, 4.0))
	_dozer(root, Vector3(-3.0, 0, 9.0), 160.0)


# --- 2. sight screens (NEW cover class `sight`: blocks eyes, not hulls or shells) ------------------------------------

## A: HOLO-AD CURTAIN. Emitter bars top and bottom on two posts; between them an additive holo ad. A crew drives
## straight through it (it is light); nobody sees through it. The one translucent surface: one quad, ~14 x 5 m.
func _screen_holo(root: Node3D, _open: bool) -> void:
	var post := CyberMaterials.surface(GUNMETAL, 0.5, 0.5)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.6, 6.4, 0.6), Vector3(side * 7.4, 3.2, 0.0), post)
	_box(root, Vector3(15.4, 0.4, 0.5), Vector3(0, 6.2, 0.0), post)
	_box(root, Vector3(14.4, 0.12, 0.3), Vector3(0, 0.08, 0.0), CyberMaterials.neon(CyberMaterials.MAGENTA, 3.5, 0.0))
	_box(root, Vector3(14.4, 0.12, 0.12), Vector3(0, 5.98, 0.0), CyberMaterials.neon(CyberMaterials.MAGENTA, 3.5, 0.0))
	# The emitter's dark scrim behind the light: opaque, so nobody sees through (the holo alone is additive).
	_box(root, Vector3(14.4, 5.8, 0.04), Vector3(0, 3.05, -0.06), CyberMaterials.surface(Color(0.03, 0.02, 0.05), 0.9, 0.0))
	_quad(root, Vector2(14.4, 5.8), Vector3(0, 3.05, 0.0), CyberMaterials.hologram(CyberMaterials.MAGENTA, CyberMaterials.CYAN, 7.0))
	_dozer(root, Vector3(4.0, 0, 7.5), 200.0)
	_dozer(root, Vector3(-4.0, 0, -6.0), 20.0, 1)


## B: TARP STRIPS. A steel gantry hung with heavy rubber strips (a loading-dock strip curtain): opaque, cheap, and it
## reads soft, so a player believes a tank pushes through. Strips hang with gaps, a few torn short.
func _screen_strips(root: Node3D, _open: bool) -> void:
	var post := CyberMaterials.surface(GUNMETAL, 0.5, 0.5)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.5, 6.4, 0.5), Vector3(side * 7.4, 3.2, 0.0), post)
	_box(root, Vector3(15.4, 0.5, 0.6), Vector3(0, 6.15, 0.0), post)
	_box(root, Vector3(15.4, 0.12, 0.08), Vector3(0, 6.15, 0.34), CyberMaterials.neon(CyberMaterials.CYAN, 3.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var strips := 22
	for i in strips:
		var x := -7.0 + 14.0 * (i + 0.5) / strips
		var length := 5.9 if rng.randf() > 0.15 else rng.randf_range(3.0, 4.5)
		var shade := TARP if i % 5 != 2 else Color(0.32, 0.12, 0.22)  # one faded magenta ad tarp in five
		var strip := _box(root, Vector3(0.58, length, 0.05), Vector3(x, 5.9 - length / 2.0, rng.randf_range(-0.08, 0.08)),
				CyberMaterials.surface(shade, 0.85, 0.0))
		strip.rotation.z = rng.randf_range(-0.03, 0.03)
	_dozer(root, Vector3(4.0, 0, 7.5), 200.0)
	_dozer(root, Vector3(-4.0, 0, -6.0), 20.0, 1)


## C: VENT STEAM. A run of floor grates glowing orange, each breathing a column of steam (soft, rising noise quads).
## The most atmospheric and the most translucent: 6 stacked quads per vent, the laptop's overdraw cost to measure.
func _screen_steam(root: Node3D, _open: bool) -> void:
	var grate := CyberMaterials.surface(STEEL, 0.5, 0.7)
	var steam := ShaderMaterial.new()
	steam.shader = STEAM_SHADER
	for i in 5:
		var x := -6.0 + 3.0 * i
		_box(root, Vector3(2.4, 0.25, 2.4), Vector3(x, 0.12, 0.0), grate)
		for slit in 4:
			_box(root, Vector3(2.0, 0.04, 0.16), Vector3(x, 0.26, -0.75 + 0.5 * slit), CyberMaterials.neon(CyberMaterials.ORANGE, 3.0, 0.2))
		for layer in 3:
			var plume := _quad(root, Vector2(4.2, 7.0), Vector3(x + (layer - 1) * 0.4, 3.6, (layer - 1) * 0.5), steam)
			plume.set_instance_shader_parameter("seed", float(i * 3 + layer))
	_dozer(root, Vector3(4.0, 0, 7.5), 200.0)
	_dozer(root, Vector3(-4.0, 0, -6.0), 20.0, 1)


## The overpass runs ACROSS his screen (a street crossing under it): along its own z, turned 90 degrees, set back.
func _crosswise(root: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.rotation.y = PI / 2.0
	pivot.position = Vector3(0.0, 0.0, -4.0)
	root.add_child(pivot)
	return pivot


# --- 3. the overpass (pillars collide; the deck is above the tallest hull) -------------------------------------------

## A: TWIN-COLONNADE RAIL. Two rows of square pillars 12 m apart along the lane, under a slab with a lit underside; a
## rail line on top. The pillars break sightlines every few metres: a flank lane with cover every 12 m.
func _overpass_rail(set_root: Node3D, _open: bool) -> void:
	var root := _crosswise(set_root)
	var concrete := CyberMaterials.surface(CONCRETE, 0.8, 0.05)
	var deck_y := 8.0
	for i in 7:
		var z := -36.0 + 12.0 * i
		for side in [-1.0, 1.0]:
			_box(root, Vector3(1.6, deck_y, 1.6), Vector3(side * 6.0, deck_y / 2.0, z), concrete)
	_box(root, Vector3(15.0, 1.2, 84.0), Vector3(0, deck_y + 0.6, 0.0), concrete)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.14, 0.14, 84.0), Vector3(side * 7.45, deck_y + 0.05, 0.0), CyberMaterials.neon(CyberMaterials.CYAN, 3.0, 0.0))
		_box(root, Vector3(0.3, 0.5, 84.0), Vector3(side * 2.0, deck_y + 1.45, 0.0), CyberMaterials.surface(STEEL, 0.4, 0.8))
	_box(root, Vector3(3.2, 3.6, 18.0), Vector3(-2.0, deck_y + 3.0, -8.0), CyberMaterials.surface(GUNMETAL, 0.4, 0.5))
	_box(root, Vector3(0.1, 0.4, 17.0), Vector3(-0.38, deck_y + 3.4, -8.0), CyberMaterials.neon(CyberMaterials.YELLOW, 3.0, 0.0))
	_dozer(root, Vector3(0.0, 0, 6.0), 180.0)
	_dozer(root, Vector3(11.0, 0, -4.0), 200.0)


## B: HAMMERHEAD HIGHWAY. One row of thick pillars with T caps down the middle, a wide deck with lit crash barriers
## and a sign gantry. The lane runs either side of the pillar row: two lanes, one colonnade.
func _overpass_highway(set_root: Node3D, _open: bool) -> void:
	var root := _crosswise(set_root)
	var concrete := CyberMaterials.surface(CONCRETE, 0.8, 0.05)
	var deck_y := 8.5
	for i in 5:
		var z := -32.0 + 16.0 * i
		_box(root, Vector3(2.4, deck_y - 1.0, 2.4), Vector3(0.0, (deck_y - 1.0) / 2.0, z), concrete)
		_box(root, Vector3(14.0, 1.0, 2.6), Vector3(0.0, deck_y - 0.5, z), concrete)
	_box(root, Vector3(20.0, 1.0, 84.0), Vector3(0, deck_y + 0.5, 0.0), concrete)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.4, 0.9, 84.0), Vector3(side * 9.8, deck_y + 1.45, 0.0), CyberMaterials.surface(STEEL, 0.4, 0.6))
		_box(root, Vector3(0.1, 0.12, 84.0), Vector3(side * 10.02, deck_y + 1.7, 0.0),
				CyberMaterials.neon(CyberMaterials.MAGENTA if side < 0 else CyberMaterials.YELLOW, 3.0, 0.0))
	_box(root, Vector3(0.5, 6.0, 0.5), Vector3(-9.8, deck_y + 4.0, -14.0), CyberMaterials.surface(STEEL, 0.4, 0.6))
	_box(root, Vector3(0.5, 6.0, 0.5), Vector3(9.8, deck_y + 4.0, -14.0), CyberMaterials.surface(STEEL, 0.4, 0.6))
	_box(root, Vector3(20.0, 2.4, 0.4), Vector3(0.0, deck_y + 6.0, -14.0), CyberMaterials.surface(GUNMETAL, 0.4, 0.5))
	_quad(root, Vector2(18.6, 2.0), Vector3(0.0, deck_y + 6.0, -13.78), CyberMaterials.panel(CyberMaterials.GREEN, 9.3, 1.8, false))
	_dozer(root, Vector3(-5.5, 0, 6.0), 180.0)
	_dozer(root, Vector3(5.5, 0, -4.0), 200.0)


## C: MONORAIL. Slender pillars every 10 m under a narrow beam at 9 m, a lit car parked on it. The lightest of the
## three: the fewest pixels over the street, the fewest sightline breaks (a thin colonnade, more look than cover).
func _overpass_monorail(set_root: Node3D, _open: bool) -> void:
	var root := _crosswise(set_root)
	var concrete := CyberMaterials.surface(CONCRETE, 0.8, 0.05)
	var beam_y := 9.0
	for i in 9:
		var z := -40.0 + 10.0 * i
		_cylinder(root, 0.55, 0.7, beam_y, Vector3(0.0, beam_y / 2.0, z), concrete, 10)
	_box(root, Vector3(2.4, 1.4, 90.0), Vector3(0, beam_y + 0.7, 0.0), concrete)
	_box(root, Vector3(0.1, 0.1, 90.0), Vector3(-1.25, beam_y + 0.1, 0.0), CyberMaterials.neon(CyberMaterials.CYAN, 3.0, 0.0))
	_box(root, Vector3(0.1, 0.1, 90.0), Vector3(1.25, beam_y + 0.1, 0.0), CyberMaterials.neon(CyberMaterials.CYAN, 3.0, 0.0))
	_box(root, Vector3(3.4, 3.2, 24.0), Vector3(0.0, beam_y + 3.0, -10.0), CyberMaterials.surface(Color(0.75, 0.76, 0.8), 0.3, 0.5))
	_box(root, Vector3(3.5, 0.7, 22.0), Vector3(0.0, beam_y + 3.4, -10.0), CyberMaterials.neon(CyberMaterials.CYAN, 1.8, 0.05))
	_dozer(root, Vector3(-5.0, 0, 6.0), 180.0)
	_dozer(root, Vector3(5.0, 0, -4.0), 200.0)


# --- 4. tank traps (cover class `low`: stop hulls, not fire) ---------------------------------------------------------

## The staggered field every trap direction is laid in: three rows, a 14 m gap left open as the funnel's mouth.
func _field_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for row in 3:
		for i in 9:
			var x := -22.0 + 4.4 * i + (2.2 if row % 2 == 1 else 0.0)
			if absf(x) < 7.0:
				continue  # the funnel's mouth
			points.append(Vector3(x, 0.0, -3.0 + 3.0 * row))
	return points


## A: CZECH HEDGEHOGS. Three steel I-beams crossed, standing on their legs, hazard-yellow tips. Iconic, spiky, 1.2 m.
func _traps_hedgehogs(root: Node3D, _open: bool) -> void:
	var steel := CyberMaterials.surface(STEEL, 0.4, 0.8)
	var tip := CyberMaterials.neon(CyberMaterials.YELLOW, 3.0, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for p: Vector3 in _field_points():
		var hog := Node3D.new()
		hog.position = p + Vector3(0, 0.62, 0)
		hog.rotation.y = rng.randf_range(0.0, TAU)
		root.add_child(hog)
		# Three beams along the body diagonals of a cube resting on a corner: tilted 54.7 degrees.
		for k in 3:
			var beam := _box(hog, Vector3(0.22, 1.9, 0.22), Vector3.ZERO, steel)
			beam.rotation_order = EULER_ORDER_YXZ
			beam.rotation = Vector3(deg_to_rad(54.7), deg_to_rad(120.0 * k), 0.0)
			var cap := _box(beam, Vector3(0.26, 0.25, 0.26), Vector3(0, 0.95, 0), tip)
			cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dozer(root, Vector3(0.0, 0, 9.0), 180.0)


## B: DRAGON'S TEETH. Square concrete frustums (a 4-sided cylinder) with a yellow-black hazard band; rows of them.
## The heaviest-looking, the most "this is a wall to tanks".
func _traps_teeth(root: Node3D, _open: bool) -> void:
	var concrete := CyberMaterials.surface(CONCRETE, 0.85, 0.05)
	var band := CyberMaterials.neon(CyberMaterials.YELLOW, 2.2, 0.0)
	for p: Vector3 in _field_points():
		var tooth := _cylinder(root, 0.35, 0.95, 1.2, p + Vector3(0, 0.6, 0), concrete, 4)
		tooth.rotation.y = PI / 4.0
		var ring := _cylinder(root, 0.47, 0.5, 0.12, p + Vector3(0, 0.95, 0), band, 4)
		ring.rotation.y = PI / 4.0
	_dozer(root, Vector3(0.0, 0, 9.0), 180.0)


## C: NEON BOLLARDS. Steel posts with glowing cyan crowns: city furniture first, a barrier second. The tidiest; reads
## as "kerb" rather than "war".
func _traps_bollards(root: Node3D, _open: bool) -> void:
	var steel := CyberMaterials.surface(GUNMETAL, 0.35, 0.8)
	var crown := CyberMaterials.neon(CyberMaterials.CYAN, 3.5, 0.0)
	for p: Vector3 in _field_points():
		_cylinder(root, 0.42, 0.48, 1.05, p + Vector3(0, 0.525, 0), steel, 12)
		_cylinder(root, 0.43, 0.43, 0.14, p + Vector3(0, 0.88, 0), crown, 12)
	_dozer(root, Vector3(0.0, 0, 9.0), 180.0)


# --- stretch: pipe racks and the gantry crane (arenas.md backlog items 4 and 5) ----------------------------------------

## PIPES A: RACK. Hull-height pipe bundle on H-frames with glowing joint collars; a 14 m crossing where the run steps
## up onto a tall bridge frame (drive under). `low`: stops hulls, not fire.
func _pipes_rack(root: Node3D, _open: bool) -> void:
	var steel := CyberMaterials.surface(GUNMETAL, 0.45, 0.7)
	var pipe := CyberMaterials.surface(Color(0.5, 0.3, 0.18), 0.4, 0.8)
	var collar := CyberMaterials.neon(CyberMaterials.GREEN, 3.0, 0.0)
	for side in [-1.0, 1.0]:
		var run_center: float = side * 18.0
		for i in 5:
			_box(root, Vector3(0.25, 1.0, 1.8), Vector3(run_center - 10.0 + 5.0 * i, 0.5, 0.0), steel)
		for k in 3:
			var p := _cylinder(root, 0.22, 0.22, 22.0, Vector3(run_center, 0.55 + 0.12 * (k % 2), -0.55 + 0.55 * k), pipe, 10)
			p.rotation.z = PI / 2.0
		for i in 4:
			var c := _cylinder(root, 0.3, 0.3, 0.2, Vector3(run_center - 7.5 + 5.0 * i, 0.55, 0.0), collar, 10)
			c.rotation.z = PI / 2.0
	# The bridge frame over the crossing.
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.4, 8.0, 1.8), Vector3(side * 7.2, 4.0, 0.0), steel)
	for k in 3:
		var p := _cylinder(root, 0.22, 0.22, 15.0, Vector3(0.0, 7.6, -0.55 + 0.55 * k), pipe, 10)
		p.rotation.z = PI / 2.0
	_dozer(root, Vector3(0.0, 0, 6.0), 180.0)


## PIPES B: GROUND PIPELINE. One fat pipe on low saddles, a glowing flow band, stepped over by a lit crossing ramp
## frame. Reads cleaner, one cylinder per run.
func _pipes_ground(root: Node3D, _open: bool) -> void:
	var saddle := CyberMaterials.surface(CONCRETE, 0.85, 0.05)
	var pipe := CyberMaterials.surface(Color(0.62, 0.64, 0.66), 0.3, 0.9)
	for side in [-1.0, 1.0]:
		var run_center: float = side * 18.0
		var p := _cylinder(root, 0.55, 0.55, 22.0, Vector3(run_center, 0.75, 0.0), pipe, 14)
		p.rotation.z = PI / 2.0
		_box(root, Vector3(22.0, 0.06, 0.3), Vector3(run_center, 1.3, 0.0), CyberMaterials.neon(CyberMaterials.CYAN, 2.0, 0.0))
		for i in 5:
			_box(root, Vector3(0.6, 0.5, 1.6), Vector3(run_center - 10.0 + 5.0 * i, 0.25, 0.0), saddle)
	var p2 := _cylinder(root, 0.55, 0.55, 15.0, Vector3(0.0, 8.0, 0.0), pipe, 14)
	p2.rotation.z = PI / 2.0
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.6, 8.0, 0.6), Vector3(side * 7.2, 4.0, 0.0), saddle)
		_box(root, Vector3(0.6, 0.1, 0.1), Vector3(side * 7.2, 7.0, 0.32), CyberMaterials.neon(CyberMaterials.YELLOW, 3.0, 0.0))
	_dozer(root, Vector3(0.0, 0, 6.0), 180.0)


## CRANE A: GANTRY. Two legged frames straddling a container row, a lit beam across with a trolley; red aircraft
## lights on top. Legs are `hard` posts; everything above is skyline.
func _crane_gantry(root: Node3D, _open: bool) -> void:
	var yellow := CyberMaterials.surface(Color(0.62, 0.48, 0.1), 0.5, 0.6)
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			_box(root, Vector3(1.2, 14.0, 1.2), Vector3(side * 11.0, 7.0, end * 6.0 - 8.0), yellow)
		_box(root, Vector3(1.0, 1.0, 13.0), Vector3(side * 11.0, 3.0, -8.0), yellow)
		_cylinder(root, 0.35, 0.35, 0.4, Vector3(side * 11.0, 15.4, -2.0), CyberMaterials.neon(CyberMaterials.RED, 4.0, 0.3), 8)
	_box(root, Vector3(26.0, 2.0, 2.2), Vector3(0.0, 14.0, -2.0), yellow)
	_box(root, Vector3(26.0, 2.0, 2.2), Vector3(0.0, 14.0, -14.0), yellow)
	_box(root, Vector3(26.0, 0.12, 0.12), Vector3(0.0, 13.0, -0.85), CyberMaterials.neon(CyberMaterials.ORANGE, 3.0, 0.0))
	_box(root, Vector3(4.0, 3.0, 14.0), Vector3(-3.0, 16.0, -8.0), CyberMaterials.surface(GUNMETAL, 0.4, 0.5))
	_box(root, Vector3(0.1, 7.0, 0.1), Vector3(-3.0, 11.0, -8.0), CyberMaterials.surface(STEEL, 0.4, 0.8))
	var stack := ["container_40", "container_40", "container_20"]
	for i in stack.size():
		var body := Node3D.new()
		body.position = Vector3(-5.0 + 7.0 * i, 0.0, -8.0)
		body.rotation.y = PI / 2.0
		root.add_child(body)
		var visual := VisualSlot.new()
		visual.slot = "prop." + String(stack[i])
		body.add_child(visual)
		visual.invoke("setup", [{"type": stack[i], "position": [-5.0 + 7.0 * i, 0.0], "rotation_deg": 90.0, "stack": 2 - i % 2}])
	_dozer(root, Vector3(14.0, 0, 9.0), 200.0)


# --- P4: the built props through their slots ---------------------------------------------------------------------

func _slot(root: Node3D, type: String, at: Vector3, yaw_deg: float, extra := {}) -> void:
	var body := Node3D.new()
	body.position = at
	body.rotation.y = deg_to_rad(yaw_deg)
	root.add_child(body)
	var visual := VisualSlot.new()
	visual.slot = "prop." + type
	body.add_child(visual)
	var prop := {"type": type, "position": [at.x, at.z], "rotation_deg": yaw_deg}
	prop.merge(extra)
	visual.invoke("setup", [prop])


func _built_traps(root: Node3D, _open: bool) -> void:
	for p: Vector3 in _field_points():
		_slot(root, "tank_trap", p, fmod(p.x * 37.0, 90.0))
	_dozer(root, Vector3(0.0, 0, 9.0), 180.0)


func _built_monorail(root: Node3D, _open: bool) -> void:
	for i in 9:
		_slot(root, "monorail", Vector3(-40.0 + 10.0 * i, 0.0, -4.0), 90.0, {"car": i == 3})
	_dozer(root, Vector3(-5.0, 0, 6.0), 180.0)
	_dozer(root, Vector3(5.0, 0, -12.0), 200.0)


func _built_screen(root: Node3D, _open: bool) -> void:
	_slot(root, "sight_screen", Vector3.ZERO, 0.0)
	_dozer(root, Vector3(4.0, 0, 7.5), 200.0)
	_dozer(root, Vector3(-4.0, 0, -6.0), 20.0, 1)


func _built_door(root: Node3D, open: bool) -> void:
	_gate_walls(root)
	var body := Node3D.new()
	root.add_child(body)
	var look := VisualSlot.new()
	look.slot = "prop.blast_door"
	body.add_child(look)
	look.invoke("setup", [{"width": GATE_WIDTH, "height": GATE_HEIGHT, "depth": 1.6}])
	look.invoke("set_state", ["closing" if open else "shut"])
	_dozer(root, Vector3(-3.0, 0, 9.0), 160.0)
