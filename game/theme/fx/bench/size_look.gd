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
## ROUND 9 (scale, contract S1) added `--size-look-lineup`: the whole roster at real relative scale, in one frame,
## for the lead to look at before CP2 merges. It reuses this file's camera, parking and on-screen measuring rather
## than standing up a second renderer, and it calls `box_at_length` for nothing -- the catalog IS the boxes now.
## Three frames, because one pose cannot answer both questions:
##   lineup_factions.png  four rows, one per faction, each sorted by length -- "is my faction's roster sensible?"
##   (a single row of all 21 was tried and dropped: 183.8 m of span is unreadable at 1080p)
##   lineup_pose.png      HIS pose (21 deg, 49 m, FOV 35), the same one round 8 shot the rig at, over the size
##                        spread -- the frame that is directly comparable with round 8's rig_14_0.png
## Each vehicle is labelled with its name and its hull length. Visual only; nothing here simulates.
##
## Flags: --size-look=<abs dir>  --size-look-lengths=5.6,10,12  --size-look-warmup=S (4)  --size-look-lineup

const PITCH_DEG := 21.0
const DISTANCE_M := 49.0
const FOV_DEG := 35.0
const RIG := "gang_tank"
const LINEUP := ["scout", "gang_scout", "gang_support", RIG, "tank"]
const GAP_M := 4.0

## S1: the size spread, smallest to largest, for the frame shot at the lead's own pose.
const SPREAD := ["gang_scout", "law_scout", "gang_ifv", "syn_tank", "tank", RIG]
## R6: the Condemned trucks the bus is ruled against: the fire engine, the garbage truck, the bus.
const BUS_ROW := ["burner", "ifv", "tank"]
## Gap between vehicles in a lineup row, and between rows. The gap is wide because the LABELS need the room, not
## the vehicles: at 3 m the four longest names in the Syndicate row overprinted each other.
const LINEUP_GAP_M := 7.0
const LINEUP_ROW_GAP_M := 7.0
## A wide pose still looks down from above, but not so steeply that lengths foreshorten away. Raised from 26 for
## the multi-row frame: at 26 the near row hid the row behind it.
const LINEUP_PITCH_DEG := 34.0
## Margin around a framed lineup, as a fraction of what it has to fit.
const LINEUP_MARGIN := 1.12
## How far outward of the camera's focus the lineup is parked. The first run put it inside the player's own
## deployment: forty vehicles, arena props, selection rings and order beams behind and across every label, and the
## frame answered a different question (feel hit the same thing with the rig-hinge frames). The lineup now stands
## on open ground beside the army, with the HUD and the order markers hidden for the capture -- these frames ask
## whether the roster reads at the right relative size, and a command card over the bottom third does not.
const LINEUP_OFFSET_M := 120.0
## Labels sit ON THE GROUND in front of their vehicle, toward the camera, at these multiples of the row gap.
##
## They used to float ABOVE the hull, and no number of tiers fixed the overprinting: within a row, tiers help; but
## a near row's labels rise into the row BEHIND it, and vertical tiers cannot separate things that are separated in
## DEPTH. On the ground in front, a label can only ever collide with its own row's neighbours, which alternating
## two offsets does solve.
const LABEL_AHEAD := [0.40, 0.72]

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
		# DRIVING bounds, not the model's authored pose: `hull_size` is the collider and a unit is shot at while it
		# moves. Almost every part answers with the model's own bounds; the artillery answers with its outriggers
		# stowed (X4, round 9 -- authored down, it measured 4.74 m against the 2.90 m it drives at).
		result = (part.driving_bounds(model) if part.has_method("driving_bounds") \
				else FactionArt.natural_bounds(model)).size
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
	if LaunchFlags.from_environment().has("size-look-lineup"):
		await _lineup(scene, focus, heading)
		print("SIZE_LOOK_DONE")
		get_tree().quit()
		return
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


# ------------------------------------------------------------------------------------------------------------------
# S1 (round 9, scale): the roster at real relative scale, for the lead to look at. The numbers are derived and need
# no approval; the LOOK is the one subjective check that counts (game_design.md *Round 9 direction*).
# ------------------------------------------------------------------------------------------------------------------

## Hide everything that is answering a different question: the HUD (command card, task palette, radar, tooltips,
## the skirmish banner) and the order feedback's ground markers, waypoint beams and selection pulses. Returns the
## callables that put them back, so a run that renders a lineup does not leave a headless match blind.
func _quieten(scene: Node) -> Array:
	var restore: Array = []
	if scene == null:
		return restore
	# EVERY CanvasLayer under the scene, found by CLASS rather than by name or by a property on Main. The first
	# attempt read `Main.hud` and tested `hud is CanvasItem`; `Hud extends CanvasLayer`, and **a CanvasLayer is not
	# a CanvasItem**, so the test was quietly false and the whole HUD -- command card, task palette, radar,
	# tooltips, banner -- sat over the frame anyway. A capability test that silently means "no" is the same shape as
	# every mirror this stream has found this round.
	var layers: Array = scene.find_children("*", "CanvasLayer", true, false)
	if scene is CanvasLayer:
		layers.append(scene)
	for node: Node in layers:
		var layer := node as CanvasLayer
		if layer.visible:
			layer.visible = false
			restore.append(func() -> void: layer.visible = true)
	# And the 3D order and selection feedback: ground markers, waypoint beams, selection rings. Two separate
	# drawers -- feel's `FxWorld.order_feedback` and control's `SelectionMarkers` -- so both are looked for.
	var marked: Array = scene.find_children("*", "SelectionMarkers", true, false)
	var fx := FxWorld.get_instance()
	if fx != null and fx.order_feedback != null:
		marked.append(fx.order_feedback)
	for node: Node in marked:
		var drawn := node as Node3D
		if drawn != null and drawn.visible:
			drawn.visible = false
			restore.append(func() -> void: drawn.visible = true)
	print("SIZE_LOOK_QUIET %d canvas layers, %d marker layers" % [layers.size(), marked.size()])
	return restore


## Every unit, faction by faction, each faction's vehicles shortest first.
func _roster_by_faction() -> Array:
	var rows: Array = []
	for faction: String in Units.FACTIONS:
		var ids: Array = Array(Units.roster(faction))
		ids.sort_custom(func(a: String, b: String) -> bool:
			return float(Units.stat(a, "hull_size")[2]) < float(Units.stat(b, "hull_size")[2]))
		if not ids.is_empty():
			rows.append(ids)
	return rows


func _lineup(scene: Node, focus: Vector3, heading: float) -> void:
	var by_faction := _roster_by_faction()
	var restore := _quieten(scene)
	# Out on open ground beside the deployment, across the camera's view.
	var stage := focus + Vector3.RIGHT.rotated(Vector3.UP, heading) * 0.0 \
			+ Vector3.FORWARD.rotated(Vector3.UP, heading) * -LINEUP_OFFSET_M
	stage.y = focus.y

	# 1. Four rows, one per faction: is each faction's own roster sensible?
	await _shoot_rows(scene, stage, heading, by_faction, "lineup_factions.png", "factions")

	# A single row of all 21 was tried and dropped: at 183.8 m of span it is unreadable at 1080p, which is a fact
	# about the frame rather than about the roster (the orchestrator looked at it and said so).

	# 3. His own pose, over the size spread. Directly comparable with round 8's rig frames.
	# HIS pose is a FIXED 49 m, so the lineup has to fit the frame rather than the frame the lineup: at the wide
	# gap the six-vehicle spread spans 73 m against about 55 m of visible width and the Rat Rod falls off the edge.
	await _shoot_rows(scene, stage, heading, [SPREAD], "lineup_pose.png", "pose", DISTANCE_M, PITCH_DEG, 3.0)

	# 4. R6 (round 10): the bus beside the garbage truck (and the fire engine) at HIS pose -- the frame his ruling
	# "longer than the garbage truck and heightened proportionally" is judged on.
	await _shoot_rows(scene, stage, heading, [BUS_ROW], "lineup_bus.png", "bus", DISTANCE_M, PITCH_DEG, 3.0)
	for restorer: Callable in restore:
		restorer.call()


## Park `rows` (a list of rows of unit ids) on the ground around `focus`, frame them, shoot one PNG, tidy up.
## `distance`/`pitch` default to a pose computed to FIT what was parked; pass them to force the lead's own pose.
func _shoot_rows(scene: Node, focus: Vector3, heading: float, rows: Array, file: String, tag: String,
		distance := -1.0, pitch := LINEUP_PITCH_DEG, gap := LINEUP_GAP_M) -> void:
	var across := Vector3.RIGHT.rotated(Vector3.UP, heading)
	var deeper := Vector3.FORWARD.rotated(Vector3.UP, heading)
	var widths: Array = []
	var depths: Array = []
	for row: Array in rows:
		var width := 0.0
		var deepest := 0.0
		for unit_id: String in row:
			var box: Array = Units.stat(unit_id, "hull_size")
			width += float(box[2]) + gap
			deepest = maxf(deepest, float(box[0]))
		widths.append(width - gap)
		depths.append(deepest)
	var total_width: float = widths.max()
	var total_depth := 0.0
	for depth: float in depths:
		total_depth += depth + LINEUP_ROW_GAP_M
	total_depth -= LINEUP_ROW_GAP_M

	# The rows are centred on `focus` in both axes, so the camera can simply look at it.
	var parked: Array = []
	var at_depth := -total_depth / 2.0
	for r in rows.size():
		var row: Array = rows[r]
		var at := -float(widths[r]) / 2.0
		for unit_id: String in row:
			var box: Array = Units.stat(unit_id, "hull_size")
			var centre: Vector3 = focus + across * (at + float(box[2]) / 2.0) + deeper * (at_depth + float(depths[r]) / 2.0)
			centre.y = focus.y
			parked.append(_park_one(scene, unit_id, centre, heading))
			at += float(box[2]) + gap
		at_depth += float(depths[r]) + LINEUP_ROW_GAP_M

	if distance < 0.0:
		distance = _distance_to_fit(total_width, total_depth, pitch)
	# The camera FIRST: the labels are placed toward it, so it has to be where it will be when they are created.
	_camera.global_transform = RtsCamera.pose_at(focus, heading, distance, pitch)
	for i in parked.size():
		_label(parked[i] as Node3D, distance, i)
	get_tree().paused = true
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	var report := {"frame": file, "pitch_deg": pitch, "distance_m": snappedf(distance, 0.1),
			"span_m": snappedf(total_width, 0.1), "units": {}}
	for tank: Node3D in parked:
		report["units"][String(tank.get("unit_id"))] = _on_screen(tank)
	print("SIZE_LOOK_LINEUP " + JSON.stringify(report))
	get_tree().paused = false
	for tank: Node3D in parked:
		tank.queue_free()
	await get_tree().process_frame


## One vehicle, side-on to the camera (nose along `across`, as `_park` does), not simulating.
func _park_one(scene: Node, unit_id: String, centre: Vector3, heading: float) -> Node3D:
	var tank := (load("res://game/tank/tank.tscn") as PackedScene).instantiate() as Node3D
	tank.set("unit_id", unit_id)
	tank.set("simulate", false)
	scene.add_child(tank)
	tank.global_transform = Transform3D(Basis(Vector3.UP, heading - PI / 2.0), centre)
	for label in tank.find_children("*", "Label3D", true, false):
		(label as Node3D).visible = false
	return tank


## The name and the hull length, over the vehicle, sized for the camera that is about to see it (a label authored in
## metres is invisible from 300 m and fills the frame from 40).
func _label(tank: Node3D, distance: float, index := 0) -> void:
	var unit_id := String(tank.get("unit_id"))
	var box: Array = Units.stat(unit_id, "hull_size")
	var label := Label3D.new()
	label.text = "%s\n%.1f m" % [Units.stat(unit_id, "display_name"), float(box[2])]
	label.font_size = 64
	label.outline_size = 18
	label.modulate = Color(1, 1, 1)
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = (distance / 60.0) / 64.0
	tank.add_child(label)
	# ON THE GROUND, in front of the vehicle, toward the camera -- computed in world space and then expressed in
	# the tank's own, because the tanks are turned side-on and their local axes are not the camera's.
	var toward := _toward_camera(tank.global_position)
	var ahead: float = LINEUP_ROW_GAP_M * LABEL_AHEAD[index % LABEL_AHEAD.size()]
	label.global_position = tank.global_position + toward * ahead + Vector3.UP * 0.35


## A flat unit vector from `at` toward the camera.
func _toward_camera(at: Vector3) -> Vector3:
	var away := _camera.global_position - at
	away.y = 0.0
	return away.normalized() if away.length_squared() > 1e-6 else Vector3.BACK


## How far back the camera has to sit, at `pitch`, for `width` across and `depth` deep to fit in the viewport.
## Godot's `fov` is the VERTICAL field of view, so the horizontal one depends on the aspect the run was given.
func _distance_to_fit(width: float, depth: float, pitch: float) -> float:
	var viewport := get_viewport().get_visible_rect().size
	var aspect: float = maxf(viewport.x, 1.0) / maxf(viewport.y, 1.0)
	var half_v := deg_to_rad(FOV_DEG) / 2.0
	var half_h := atan(tan(half_v) * aspect)
	# Depth is foreshortened by the pitch: what the camera has to fit vertically is the rows' projected extent.
	var projected := depth * sin(deg_to_rad(pitch))
	var for_width := (width * LINEUP_MARGIN / 2.0) / tan(half_h)
	var for_depth := (projected * LINEUP_MARGIN / 2.0) / tan(half_v)
	# THE NEAR ROW IS NEARER THAN THE FOCUS, so it subtends a wider angle than this calculation assumes -- which is
	# why the first multi-row frame clipped the Condemned row (the widest, 55.7 m) at both edges. Push back by the
	# half-depth's projection so the width fits AT THE NEAREST ROW rather than at the middle of the block.
	var near_row_bias := (depth / 2.0) * cos(deg_to_rad(pitch))
	return maxf(maxf(for_width, for_depth) + near_row_bias, DISTANCE_M)
