class_name SizeLook
extends Node
## `make size-look` (feel, round 8; the lead, the third time: "the gang tanks are still tiny (the intent for the semi
## trucks is that they're huge)"). Round 6 set the War Rig's box to 4.4 m tall, 3.14x the scout, inside the "3 or 4
## times the height" he named, and it still read as tiny: the number was met and the intent missed. So this answers
## with his own frame, not a gallery: it rides a real skirmish (FxWorld adds it on `--size-look=<abs dir>`), parks a
## lineup on the player's side of the arena and shoots it with his camera (pitch 21, 49 m, FOV 35).
##
## First `army.png`: his pose over the player's own army as it deployed (run it with --player-faction=gangs: does the
## rig dominate its squad, or does everything else look small?). Then the lineup, left to right: the Condemned scout, the
## gang scout, the Resupply Tanker, the War Rig, the Condemned tank. The War Rig is
## shot once per candidate length (`--size-look-lengths=5.6,10,12`): the catalog's box when the length is the
## catalog's, else a box with the model's own proportions at that length (Units.tuning, this process only), so the box
## always matches what is drawn. Per shot it prints `SIZE_LOOK {json}` with each unit's on-screen extent in pixels
## (its drawn meshes' bounds projected) and its box; `rig_<length>.png` is the frame. Then `SIZE_LOOK_DONE` and quit.
## Visual only: the lineup's tanks don't simulate.
##
## Flags: --size-look=<abs dir>  --size-look-lengths=5.6,10,12  --size-look-warmup=S (4)

const PITCH_DEG := 21.0
const DISTANCE_M := 49.0
const FOV_DEG := 35.0
const RIG := "gang_tank"
const LINEUP := ["scout", "gang_scout", "gang_support", RIG, "tank"]
const GAP_M := 4.0

var out_dir := ""
var lengths: Array = [5.6, 10.0, 12.0]
var warmup := 4.0
var _camera := Camera3D.new()


func _init() -> void:
	name = "SizeLook"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var flags := LaunchFlags.from_environment()
	out_dir = flags.text("size-look")
	warmup = float(flags.text("size-look-warmup", str(warmup)))
	if flags.text("size-look-lengths") != "":
		lengths = Array(flags.text("size-look-lengths").split(",", false)).map(func(v: String) -> float: return float(v))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_camera.name = "SizeLookCamera"
	_camera.fov = FOV_DEG
	_camera.far = 1200.0
	add_child(_camera)
	_run.call_deferred()


## The box a model fills at `length` metres long, in its own proportions: [w, h, l].
static func box_at_length(unit_id: String, length: float) -> Array:
	var natural := SizeLook.natural_size(unit_id)
	if natural.z <= 0.01:
		return Units.stat(unit_id, "hull_size")
	var k := length / natural.z
	return [snappedf(natural.x * k, 0.01), snappedf(natural.y * k, 0.01), snappedf(length, 0.01)]


## A unit's hull model at its authored size (its approved proportions), or zero when it has no art of its own.
static func natural_size(unit_id: String) -> Vector3:
	var slot := "unit.%s.hull" % unit_id
	if not GameTheme.slots.has(slot):
		return Vector3.ZERO
	var part := GameTheme.scene(slot).instantiate()
	var packed: PackedScene = part.get("model_scene")
	var result := Vector3.ZERO
	if packed != null:
		var model := packed.instantiate() as Node3D
		result = FactionArt.natural_bounds(model).size
		model.free()
	part.free()
	return result


func _run() -> void:
	await get_tree().create_timer(warmup, true, false, true).timeout
	var scene := get_tree().current_scene
	var rig := scene.get_node_or_null("RtsCamera") if scene != null else null
	var focus: Vector3 = rig.get("focus") if rig != null else Vector3.ZERO
	var heading: float = rig.get("yaw") if rig != null else 0.0
	if rig != null:
		rig.process_mode = Node.PROCESS_MODE_DISABLED
	_camera.current = true
	var army := _army(scene)
	if not army.is_empty():
		# Framed on the rigs when the army has any (the question is what they do to their squad), else on the army.
		var rigs := army.filter(func(t: Node) -> bool: return String(t.get("unit_id")) == RIG)
		var framed := rigs if not rigs.is_empty() else army
		var centre := Vector3.ZERO
		for tank: Node3D in framed:
			centre += tank.global_position
		centre /= framed.size()
		_camera.global_transform = RtsCamera.pose_at(centre, heading, DISTANCE_M, PITCH_DEG)
		get_tree().paused = true
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("army.png"))
		var units := {}
		for tank: Node3D in army:
			var id := String(tank.get("unit_id"))
			units[id] = int(units.get(id, 0)) + 1
		print("SIZE_LOOK_ARMY " + JSON.stringify({"units": units, "centre": [snappedf(centre.x, 0.1), snappedf(centre.z, 0.1)]}))
		get_tree().paused = false
	var catalog: Array = Units.stat(RIG, "hull_size")
	for length: float in lengths:
		if is_equal_approx(length, float(catalog[2])):
			Units.tuning.erase(RIG + ".hull_size")
		else:
			Units.tuning[RIG + ".hull_size"] = SizeLook.box_at_length(RIG, length)
		var tanks := _park(scene, focus, heading)
		_camera.global_transform = RtsCamera.pose_at(focus, heading, DISTANCE_M, PITCH_DEG)
		get_tree().paused = true
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var name_len := ("%.1f" % length).replace(".", "_")
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("rig_%s.png" % name_len))
		var report := {"rig_length_m": length, "units": {}}
		for tank: Node3D in tanks:
			report["units"][String(tank.get("unit_id"))] = _on_screen(tank)
		print("SIZE_LOOK " + JSON.stringify(report))
		get_tree().paused = false
		for tank in tanks:
			tank.queue_free()
		await get_tree().process_frame
	Units.tuning.erase(RIG + ".hull_size")
	print("SIZE_LOOK_DONE")
	get_tree().quit()


## The player's (team 0) tanks the match deployed.
func _army(scene: Node) -> Array:
	if scene == null:
		return []
	return scene.find_children("*", "Tank", true, false).filter(
			func(t: Node) -> bool: return int(t.get("team")) == 0 and t.is_inside_tree())


## The lineup side by side across the camera's view, noses toward the camera's right, centred on `focus`.
func _park(scene: Node, focus: Vector3, heading: float) -> Array:
	var across := Vector3.RIGHT.rotated(Vector3.UP, heading)
	var widths := LINEUP.map(func(id: String) -> float: return float(Units.stat(id, "hull_size")[2]))
	var total := 0.0
	for w: float in widths:
		total += w + GAP_M
	var at := -total / 2.0
	var tanks := []
	var tank_scene := load("res://game/tank/tank.tscn") as PackedScene
	for i in LINEUP.size():
		var tank := tank_scene.instantiate() as Node3D
		tank.set("unit_id", LINEUP[i])
		tank.set("simulate", false)
		scene.add_child(tank)
		var centre: Vector3 = focus + across * (at + float(widths[i]) / 2.0)
		centre.y = focus.y
		# Nose (-Z) along `across`: the camera sees every vehicle side-on, length across the frame.
		tank.global_transform = Transform3D(Basis(Vector3.UP, heading - PI / 2.0), centre)
		for label in tank.find_children("*", "Label3D", true, false):
			(label as Node3D).visible = false
		at += float(widths[i]) + GAP_M
		tanks.append(tank)
	return tanks


## The unit's drawn meshes, projected: on-screen width and height in pixels, and its box.
func _on_screen(tank: Node3D) -> Dictionary:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for node in tank.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		for c in 8:
			var corner := box.get_endpoint(c)
			if _camera.is_position_behind(corner):
				continue
			var p := _camera.unproject_position(corner)
			lo = lo.min(p)
			hi = hi.max(p)
	var size := (hi - lo) if hi.x > lo.x else Vector2.ZERO
	return {"px_w": roundi(size.x), "px_h": roundi(size.y), "box": Units.stat(String(tank.get("unit_id")), "hull_size")}
