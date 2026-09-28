extends SceneTree
## `make rig-vanish` (airship stream, round 14, A0): the lead's *"I have 2 war rigs for the game that turned invisible
## during gameplay"*, reproduced in the REAL skirmish rather than reasoned about (lesson 219).
##
## His recording (`build/recordings/2026-09-27T23-20-40-locks.jsonl`, seed 76424, Gangs v Condemned) ends with his last
## two units, `Green_Guns_7` at (-91.5, 12.9) and `Green_Guns_9` at (94.9, 13.6), alive and arrived at the north ends of
## the two swing bridges. This builds that match through `main.tscn` (so the cutaway, the fog, the airship, the FX and
## the controls are all the live ones), puts two War Rigs there, and for each rig frames it from his pose at a ring of
## camera yaws. Per frame it logs what the NODES say (the tank's `visible`, each mesh's `is_visible_in_tree`, whether
## its box is in the frustum, which blocks the cutaway has cut) and what the SCREEN says: the frame is rendered with
## the rig and again without it, and the pixels that differ are the pixels the rig actually contributes. A rig whose
## box is on screen and that contributes no pixels is invisible, whatever the nodes claim.
##
## The lead's correction (2026-09-27): *"the trucks just became completely invisible when I was moving them around.
## Their graphic was gone and instead it was just a blue circle"* -- IN MOTION, so `--rig-vanish-replay=<recording>`
## replays his match instead: every Green order in the recording is issued through the controls at its tick, the
## camera frames what he last ordered, and EVERY TICK each War Rig's height, its art's transforms (NaN, degenerate) and
## visibility are logged; every RENDER_EVERY ticks each rig on screen is rendered with and without it (pixels).
##
## Flags (after `--`): --rig-vanish=<abs dir>  --rig-vanish-yaws=12  --rig-vanish-drive (drive them there instead of
## placing them, then measure)  --rig-vanish-replay=<abs recording>  --rig-vanish-until=TICK, plus any skirmish flag.
## Prints RIG_VANISH lines and RIG_VANISH_DONE.

const MAIN := "res://game/main.tscn"
const SIZE := Vector2i(960, 540)
## His recording's last positions (census, ticks 3480-4320).
const SPOTS := {"Green_Guns_7": Vector2(-91.5, 12.9), "Green_Guns_9": Vector2(94.9, 13.6)}
## A pixel counts as the rig's when any channel moves by more than this between the two renders.
const PIXEL_DELTA := 0.03

var out := ""
var yaws := 12
var drive := false
var replay := ""
var deploy_only := false
var until := 3400
## Ticks between the with/without renders in a replay.
const RENDER_EVERY := 15
var main: Node
var controls: RtsControls
var rig: RtsCamera
var rows: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rig-vanish="):
			out = arg.trim_prefix("--rig-vanish=")
		elif arg.begins_with("--rig-vanish-yaws="):
			yaws = maxi(1, int(arg.trim_prefix("--rig-vanish-yaws=")))
		elif arg == "--rig-vanish-drive":
			drive = true
		elif arg.begins_with("--rig-vanish-replay="):
			replay = arg.trim_prefix("--rig-vanish-replay=")
		elif arg == "--rig-vanish-deploy":
			deploy_only = true
		elif arg.begins_with("--rig-vanish-until="):
			until = int(arg.trim_prefix("--rig-vanish-until="))
	if out == "":
		push_error("rig-vanish: --rig-vanish=<dir> is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	main = (load(MAIN) as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for i in 600:
		controls = main.find_child("TacticalMap", true, false) as RtsControls
		rig = main.find_child("RtsCamera", true, false) as RtsCamera
		if controls != null and rig != null and controls.game_match != null:
			break
		await process_frame
	if controls == null or rig == null:
		print("RIG_VANISH_FAILED no skirmish controls or camera (is this a skirmish?)")
		quit(1)
		return
	var game_match: Match = controls.game_match
	if replay != "":
		await _replay(game_match)
		return
	if deploy_only:
		await _deploy_frames(game_match)
		return
	for i in 3:
		await _seconds(0.7)
		if paused:
			controls.set_paused(false, "")
	var rigs: Array[Tank] = []
	for unit_name: String in SPOTS:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank == null or String(tank.unit_id) != "gang_tank":
			print("RIG_VANISH_FAILED %s is not a War Rig in this army (need --player-faction=gangs --seed=76424)" % unit_name)
			quit(1)
			return
		rigs.append(tank)
	if drive:
		await _drive(rigs)
	else:
		for tank in rigs:
			var spot: Vector2 = SPOTS[String(tank.name)]
			# Yaw 0 faces -Z: nose toward the canal (z = 0) and onto the bridge, as his rigs drove there.
			tank.place(Vector3(spot.x, 0.0, spot.y), 0.0)
		await _seconds(1.0)
	paused = true  # freeze the world; the camera, the cutaway and the renderer run while paused
	rig.follow_target = null
	rig.vision = Callable()
	rig.auto_frame = false
	for tank in rigs:
		for i in yaws:
			await _measure(tank, TAU * i / yaws)
	var file := FileAccess.open(out.path_join("rig_vanish.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(rows, "  "))
	var hidden := rows.filter(func(r: Dictionary) -> bool: return bool(r["on_screen"]) and int(r["pixels"]) == 0)
	print("RIG_VANISH_SUMMARY frames=%d on_screen=%d invisible_on_screen=%d" % [rows.size(),
			rows.filter(func(r: Dictionary) -> bool: return bool(r["on_screen"])).size(), hidden.size()])
	print("RIG_VANISH_DONE %s" % out)
	quit(0)


## Give each rig a player move to its recorded spot, from wherever it stands, and let the match run until both arrive.
func _drive(rigs: Array[Tank]) -> void:
	for tank in rigs:
		controls.selection.set_units([String(tank.name)])
		var spot: Vector2 = SPOTS[String(tank.name)]
		controls.world_order(Vector3(spot.x, 0.0, spot.y))
		await process_frame
	for i in 240:
		await _seconds(0.5)
		var far := rigs.filter(func(t: Tank) -> bool:
			var spot: Vector2 = SPOTS[String(t.name)]
			return not t.is_alive() or Vector2(t.global_position.x, t.global_position.z).distance_to(spot) > 6.0)
		if far.is_empty():
			break
	for tank in rigs:
		print("RIG_VANISH_DROVE %s alive=%s at (%.1f, %.1f)" % [tank.name, tank.is_alive(), tank.global_position.x,
				tank.global_position.z])


func _measure(tank: Tank, yaw: float) -> void:
	rig.focus = Vector3(tank.global_position.x, 0.0, tank.global_position.z)
	rig.yaw = yaw
	rig.pitch = RtsCamera.DEFAULT_PITCH_DEG
	rig.zoom = SkirmishMode.START_ZOOM
	rig.snap()
	for i in 4:
		await process_frame
	var with := root.get_texture().get_image()
	var state := _nodes(tank)
	var was := tank.visible
	tank.visible = false
	for i in 2:
		await process_frame
	var without := root.get_texture().get_image()
	tank.visible = was
	var pixels := _differ(with, without)
	var label := "%s_yaw%03d" % [tank.name, roundi(rad_to_deg(yaw))]
	with.save_png(out.path_join(label + ".png"))
	var row := {"rig": String(tank.name), "yaw_deg": roundi(rad_to_deg(yaw)), "pixels": pixels,
			"at": [snappedf(tank.global_position.x, 0.1), snappedf(tank.global_position.z, 0.1)],
			"camera": [snappedf(rig.camera.global_position.x, 0.1), snappedf(rig.camera.global_position.y, 0.1),
					snappedf(rig.camera.global_position.z, 0.1)]}
	row.merge(state)
	rows.append(row)
	print("RIG_VANISH %-14s yaw=%3d pixels=%6d on_screen=%s visible=%s meshes=%d/%d in_frustum=%d cut=%s" % [
			tank.name, row["yaw_deg"], pixels, row["on_screen"], row["visible"], row["meshes_visible"],
			row["meshes"], row["meshes_in_frustum"], row["cut"]])


## What the scene graph says about this tank's art right now.
func _nodes(tank: Tank) -> Dictionary:
	var meshes := 0
	var shown := 0
	var in_frustum := 0
	var planes := rig.camera.get_frustum()
	var box := AABB()
	var first := true
	for node in tank.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if geometry is MeshInstance3D and (geometry as MeshInstance3D).mesh == null:
			continue
		meshes += 1
		if not geometry.is_visible_in_tree():
			continue
		shown += 1
		var world := geometry.global_transform * geometry.get_aabb()
		if _aabb_in(world, planes):
			in_frustum += 1
		box = world if first else box.merge(world)
		first = false
	var cutaway := main.find_child("BlockCutaway", true, false)
	return {"visible": tank.visible, "in_tree": tank.is_visible_in_tree(), "meshes": meshes, "meshes_visible": shown,
			"meshes_in_frustum": in_frustum, "on_screen": in_frustum > 0,
			"cut": cutaway.call("cut_blocks") if cutaway != null else []}


static func _aabb_in(box: AABB, planes: Array[Plane]) -> bool:
	for plane: Plane in planes:
		var outside := true
		for i in 8:
			if not plane.is_point_over(box.get_endpoint(i)):
				outside = false
				break
		if outside:
			return false
	return true


static func _differ(a: Image, b: Image) -> int:
	if a.get_size() != b.get_size():
		return -1
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), absf(p.b - q.b))) > PIXEL_DELTA:
				count += 1
	return count


## The deployed army, 10 ticks in, frozen: every Green hull's height, and frames at his pose (49 m) and wide (110 m)
## looking up the arena over it. `ARMY_LAYOUT` and `TANK_OFF_FLOOR` lines in the log say the rest.
func _deploy_frames(game_match: Match) -> void:
	while game_match.tick < 10:
		if paused:
			controls.set_paused(false, "")
		await process_frame
	paused = true
	var centre := Vector3.ZERO
	var green: Array = []
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank != null and tank.team == Match.Team.GREEN:
			green.append(tank)
			centre += tank.global_position
	centre /= maxf(1.0, green.size())
	var off := green.filter(func(t: Tank) -> bool: return absf(t.global_position.y) > 0.5)
	for t: Tank in off:
		print("RIG_VANISH_OFF_FLOOR %s y=%.2f at (%.1f, %.1f)" % [t.name, t.global_position.y, t.global_position.x, t.global_position.z])
	rig.follow_target = null
	rig.vision = Callable()
	rig.auto_frame = false
	for shot: Array in [["his_pose", SkirmishMode.START_ZOOM, Vector3(-30.0, 0.0, 60.0)], ["his_pose_centre", SkirmishMode.START_ZOOM, centre],
			["wide", 0.75, centre]]:
		rig.focus = Vector3((shot[2] as Vector3).x, 0.0, (shot[2] as Vector3).z)
		rig.yaw = 0.0
		rig.pitch = RtsCamera.DEFAULT_PITCH_DEG
		rig.zoom = float(shot[1])
		rig.snap()
		for i in 4:
			await process_frame
		root.get_texture().get_image().save_png(out.path_join("deploy_%s.png" % shot[0]))
	print("RIG_VANISH_SUMMARY deploy green=%d off_floor=%d" % [green.size(), off.size()])
	print("RIG_VANISH_DONE %s" % out)
	quit(0)


## Replay his orders at their ticks and log every rig, every tick (the lead's correction: it vanished in motion).
func _replay(game_match: Match) -> void:
	var orders: Array = []
	var file := FileAccess.open(replay, FileAccess.READ)
	if file == null:
		print("RIG_VANISH_FAILED cannot read %s" % replay)
		quit(1)
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var row: Variant = JSON.parse_string(line)
		if row is Dictionary and String(row.get("t", "")) == "order" and (row["units"] as Array).all(
				func(n: String) -> bool: return n.begins_with("Green_")):
			orders.append(row)
	print("RIG_VANISH_REPLAY %d Green orders from %s" % [orders.size(), replay])
	var log := FileAccess.open(out.path_join("replay_ticks.csv"), FileAccess.WRITE)
	log.store_line("tick,unit,x,y,z,yaw,visible,meshes,meshes_visible,bad_transforms,in_frustum,pixels,blocked")
	var next := 0
	var last := -1
	var worst_y := {}
	var first_low := {}
	var vanished: Array = []
	while game_match.tick < until:
		if paused:
			controls.set_paused(false, "")
		await process_frame
		var tick := game_match.tick
		if tick == last:
			continue
		last = tick
		while next < orders.size() and int(orders[next]["tick"]) <= tick:
			_issue(orders[next])
			next += 1
		var render := tick % RENDER_EVERY == 0
		for node in game_match.tanks.get_children():
			var tank := node as Tank
			if tank == null or tank.team != Match.Team.GREEN or String(tank.unit_id) != "gang_tank" or not tank.is_alive():
				continue
			var state := _nodes(tank)
			var bad := _bad_transforms(tank)
			var pixels := -1
			if render and bool(state["on_screen"]):
				pixels = await _pixels(tank)
			var at := tank.global_position
			var unit := String(tank.name)
			worst_y[unit] = minf(float(worst_y.get(unit, 0.0)), at.y)
			if absf(at.y) > 0.05 and not first_low.has(unit):
				first_low[unit] = tick
				print("RIG_VANISH_HEIGHT %s tick=%d y=%.3f at (%.1f, %.1f)" % [unit, tick, at.y, at.x, at.z])
			if pixels == 0 or bad > 0 or not tank.visible or int(state["meshes_visible"]) < int(state["meshes"]):
				vanished.append({"unit": unit, "tick": tick, "y": at.y, "pixels": pixels, "bad": bad})
				if vanished.size() <= 40:
					print("RIG_VANISH_SUSPECT %s tick=%d y=%.3f pixels=%d bad=%d visible=%s meshes=%d/%d in_frustum=%d" % [
							unit, tick, at.y, pixels, bad, tank.visible, state["meshes_visible"], state["meshes"],
							state["meshes_in_frustum"]])
					if pixels == 0:
						root.get_texture().get_image().save_png(out.path_join("suspect_%s_t%05d.png" % [unit, tick]))
			log.store_line("%d,%s,%.3f,%.3f,%.3f,%.1f,%s,%d,%d,%d,%d,%d,%s" % [tick, unit, at.x, at.y, at.z,
					rad_to_deg(tank.rotation.y), tank.visible, state["meshes"], state["meshes_visible"], bad,
					state["meshes_in_frustum"], pixels, str(Movement.state(tank).get("blocked", ""))])
	log.close()
	for unit: String in worst_y:
		print("RIG_VANISH_LOWEST %s y=%.3f first_off_floor_tick=%s" % [unit, worst_y[unit], first_low.get(unit, "-")])
	print("RIG_VANISH_SUMMARY replay suspects=%d" % vanished.size())
	print("RIG_VANISH_DONE %s" % out)
	quit(0)


func _issue(row: Dictionary) -> void:
	var units: Array = row["units"]
	var alive := units.filter(func(n: String) -> bool:
		var tank := controls.game_match.tanks.get_node_or_null(NodePath(n)) as Tank
		return tank != null and tank.is_alive())
	if alive.is_empty():
		return
	controls.selection.set_units(alive)
	var extra := {"queue": bool(row.get("queue", false))}
	if row.has("to"):
		extra["to"] = row["to"]
	if row.has("target"):
		extra["target"] = row["target"]
	var result := controls.order_selection(String(row["verb"]), extra)
	print("RIG_VANISH_ORDER tick=%d %s %s -> %s" % [controls.game_match.tick, row["verb"], alive, result])


## Transforms under the tank's art that are NaN or degenerate (a zero-scale basis draws nothing).
func _bad_transforms(tank: Tank) -> int:
	var bad := 0
	for node in tank.find_children("*", "Node3D", true, false):
		var t := (node as Node3D).global_transform
		if not t.origin.is_finite() or not t.basis.x.is_finite() or not t.basis.y.is_finite() or not t.basis.z.is_finite() \
				or absf(t.basis.determinant()) < 1e-6:
			bad += 1
	return bad


## The pixels this tank draws right now: the world is frozen, the frame rendered with it and again without it.
func _pixels(tank: Tank) -> int:
	var was := paused
	paused = true
	await process_frame
	var with := root.get_texture().get_image()
	tank.visible = false
	await process_frame
	await process_frame
	var without := root.get_texture().get_image()
	tank.visible = true
	paused = was
	return _differ(with, without)


func _seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout
