class_name FeedbackShots
extends Node
## `make feedback-shots` (round 37, feedback): his picked looks staged in the real game, close stills and clips (the
## directions page's pictures came from this, when every slot had three looks). A skirmish runs as he
## plays it (his arena, the HUD, the RTS camera, `--render-preset=laptop` when the Makefile asks), and in a quiet corner
## of the map this stages each slot's situation with real vehicles, then shoots it with the look on at his pose
## (21 deg, FOV 35, 49 m) and close in, a short clip at his pose, and one still with it off:
##
##   hit     three enemy crews in a row, struck at the same instant on the front, the flank and the rear (the events
##           are staged, the effects are the game's, exactly as Match.projectile_impact drives them)
##   pinned  four enemy crews at suppression 0, 0.45, 0.7 and 1.0, held there
##   repair  a Resupply Tanker with two hurt friends inside its 18 m (it really mends them) and one hurt friend outside
##   cone    a Sonic Emitter really blowing at two enemy crews (its cone, its suppression)
##
## Flags: --feedback-shots=<abs dir>  --feedback-shots-slots=hit,pinned  --feedback-shots-clip-frames=N (0: stills only)
## Prints FEEDBACK_SHOT <file> and FEEDBACK_SHOTS_DONE files=<n>.

const PITCH_DEG := 21.0
const DISTANCE_M := 49.0
const CLOSE_M := 26.0
const CLIP_FPS := 12.0
const SETTLE_S := 0.35

var out_dir := ""
var slots: Array = ["hit", "pinned", "repair", "cone"]
var clip_frames := 24
var _match: Match
var _rig: RtsCamera
var _written := 0
var _staged: Array = []
## name -> suppression held every physics frame (the pinned slot), name -> health held (the repair slot).
var _hold_suppression := {}
var _hold_health := {}
var _emitter: Tank
var _emitter_target := Vector3.ZERO
var _site := Vector3.ZERO
var _yaw := 0.0


static func wanted() -> bool:
	return LaunchFlags.from_environment().has("feedback-shots")


func _init() -> void:
	name = "FeedbackShots"
	process_mode = Node.PROCESS_MODE_ALWAYS
	# After the controllers (-10) write their commands, before the tanks (0) act on them.
	process_physics_priority = -5


func _ready() -> void:
	var flags := LaunchFlags.from_environment()
	out_dir = flags.text("feedback-shots")
	if flags.text("feedback-shots-slots") != "":
		slots = Array(flags.text("feedback-shots-slots").split(","))
	clip_frames = flags.integer("feedback-shots-clip-frames", clip_frames)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	if _match == null or not is_instance_valid(_match):
		return
	_hold_army()
	for node: Variant in _staged:
		if not is_instance_valid(node):
			continue
		var tank: Tank = node
		tank.shield = 0.0
		if _hold_suppression.has(tank.name):
			tank.suppression = float(_hold_suppression[tank.name])
		if _hold_health.has(tank.name) and tank.health > int(_hold_health[tank.name]) + 20:
			tank.health = int(_hold_health[tank.name])
		# Staged targets are not there to die: the Emitter's 18 dps and the hit scene's rounds would wreck them mid-shot.
		if not _hold_health.has(tank.name) and tank.health < tank.max_health * 0.6:
			tank.health = tank.max_health
	if _emitter != null and is_instance_valid(_emitter):
		_emitter.command.aim_point = _emitter_target
		_emitter.command.fire = true


func _run() -> void:
	while _find() == false:
		await get_tree().process_frame
	_army = _match.tanks.get_children()
	await _seconds(2.0)
	var sites := _open_sites(slots.size())
	for i in slots.size():
		_site = sites[i]
		_yaw = 0.0
		print("FEEDBACK_SITE %s %s arena=%s" % [slots[i], _site, Arena.active.get("name", "?")])
		match String(slots[i]):
			"hit": await _hits()
			"pinned": await _pinned()
			"repair": await _repair()
			"cone": await _cone()
		_settle_slot()
	print("FEEDBACK_SHOTS_DONE files=%d" % _written)
	get_tree().quit()


## The armies that were on the map when the shots began: held still and silent every tick (after their controllers write
## the command, before the tank acts on it), so the staged scenes are the only fight. A live battle drove through the
## first capture's close-ups and killed the staged crews.
var _army: Array = []


func _hold_army() -> void:
	for node: Variant in _army:
		if is_instance_valid(node):
			var tank: Tank = node
			tank.command.throttle = 0.0
			tank.command.turn = 0.0
			tank.command.fire = false


func _find() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	_match = scene.get_node_or_null("Match") as Match
	_rig = scene.find_child("RtsCamera", true, false) as RtsCamera
	return _match != null and _rig != null and _match.tanks != null and _match.tanks.get_child_count() > 0


## `count` open patches of ground (nothing solid within CLEAR_M), away from both bases and from each other, nearest the
## middle first: each slot is staged on its own patch, so no vehicle has to be removed mid-match (the HUD and the effects
## expect vehicles to die, not to vanish).
const CLEAR_M := 14.0
const APART_M := 55.0


func _open_sites(count: int) -> Array:
	var half := float(Arena.active.get("half_size", 120.0))
	var open: Array = []
	var step := 6.0
	var x := -half * 0.8
	while x <= half * 0.8:
		var z := -half * 0.8
		while z <= half * 0.8:
			var point := Vector3(x, 0, z)
			if _clear(point) and point.distance_to(Match.resupply_center(0)) > 45.0 and point.distance_to(Match.resupply_center(1)) > 45.0 \
					and not _on_objective(point):
				open.append(point)
			z += step
		x += step
	open.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.length() < b.length())
	var picked: Array = []
	for point: Vector3 in open:
		var far := true
		for other: Vector3 in picked:
			far = far and point.distance_to(other) >= APART_M
		for node: Variant in _army:
			if is_instance_valid(node) and (node as Tank).global_position.distance_to(point) <= 30.0:
				far = false
		if far:
			picked.append(point)
		if picked.size() == count:
			break
	while picked.size() < count:
		picked.append(Vector3(0, 0, -half * 0.3 + picked.size() * APART_M))
	return picked


## Staged crews on a scoring zone would take it (the first capture's pinned crews scored the East Ring).
func _on_objective(point: Vector3) -> bool:
	for objective: Dictionary in _match.objectives:
		var at: Variant = objective.get("position")
		var centre := Vector3(float(at.x), 0.0, float(at.z)) if at is Vector3 else Vector3(float(at[0]), 0.0, float(at[1]))
		if centre.distance_to(point) <= float(objective.get("radius", 15.0)) + 20.0:
			return true
	return false


func _clear(point: Vector3) -> bool:
	var reach := int(CLEAR_M)
	for dx in range(-reach, reach + 1, 4):
		for dz in range(-reach, reach + 1, 4):
			if not RtsCamera.solid_at(point + Vector3(dx, 0, dz)).is_empty():
				return false
	return true


func _spawn(tank_name: String, team: int, unit_id: String, offset: Vector3, facing: Vector3) -> Tank:
	var tank := _match.spawn_tank(tank_name, 0, team, unit_id)
	tank.global_position = _site + offset.rotated(Vector3.UP, _yaw)
	tank.rotation.y = atan2(-facing.rotated(Vector3.UP, _yaw).x, -facing.rotated(Vector3.UP, _yaw).z)
	_staged.append(tank)
	return tank


## A slot is done: its vehicles stay where they are, held still and quiet like the armies.
func _settle_slot() -> void:
	_emitter = null
	_hold_suppression.clear()
	for node: Variant in _staged:
		_army.append(node)
	_staged.clear()


## Look at the site at his pose (or close in), framed on `centre` (a site offset).
func _pose(distance: float, centre := Vector3.ZERO) -> void:
	_rig.stop_tracking("feedback-shots")
	_rig.auto_frame = false
	_rig.vision = Callable()
	_rig.vision_region = null
	_rig.follow_target = null
	_rig.yaw_follow = false
	_rig.edge_pan = false
	_rig.focus = _site + centre.rotated(Vector3.UP, _yaw)
	_rig.yaw = _yaw
	_rig.zoom = RtsCamera.level_for(distance)
	_rig.pitch = PITCH_DEG
	_rig.snap()


func _hits() -> void:
	var targets: Array = []
	for i in 3:
		targets.append(_spawn("FbTarget%d" % i, Match.Team.RUST, "gang_ifv", Vector3(-9.0 + i * 9.0, 0, 0), Vector3.LEFT))
	_spawn("FbEyes", Match.Team.GREEN, "scout", Vector3(0, 0, 26), Vector3.FORWARD)
	await _seconds(1.0)
	FeedbackLook.use("hit:on")
	for distance: float in [DISTANCE_M, CLOSE_M]:
		_pose(distance)
		await _seconds(SETTLE_S)
		_strike(targets)
		await _seconds(0.12)
		await _frames(2)
		_save("hit_on_%s" % ("rts" if distance == DISTANCE_M else "close"))
		await _seconds(1.4)
	if clip_frames > 0:
		_pose(DISTANCE_M)
		await _seconds(SETTLE_S)
		await _clip("hit_on", func(frame: int) -> void:
			if frame % roundi(CLIP_FPS * 1.2) == 2:
				_strike(targets))


## One cannon round into each target at once: from ahead (front), from its flank, from behind (rear).
func _strike(targets: Array) -> void:
	var fx := FxWorld.existing()
	if fx == null:
		return
	var faces := ["front", "side", "rear"]
	for i in targets.size():
		if not is_instance_valid(targets[i]):
			continue
		var target: Tank = targets[i]
		var forward := -target.global_basis.z
		var from: Vector3
		match faces[i]:
			"front": from = target.global_position + forward * 30.0
			"side": from = target.global_position + target.global_basis.x * 30.0
			_: from = target.global_position - forward * 30.0
		from.y = 1.3
		var toward := (target.global_position + Vector3.UP - from).normalized()
		var at := target.global_position + Vector3.UP * 1.0 - toward * 1.5
		var id := 900000 + _written * 8 + i
		fx.link._on_weapon_fired({"tick": _match.tick, "shooter": "", "weapon": "cannon", "fire_model": "shell",
				"muzzle": [from.x, from.y, from.z], "direction": [toward.x, toward.y, toward.z], "projectile_id": id,
				"speed_mps": 0.0, "range": 60.0, "suppression_applied": 0.0})
		fx.link._on_projectile_impact({"tick": _match.tick, "projectile_id": id, "position": [at.x, at.y, at.z],
				"normal": [-toward.x, 0.0, -toward.z], "target": String(target.name), "face": faces[i], "weak_spot": false,
				"damage": 40.0, "killed": false})


func _pinned() -> void:
	var levels := [0.0, 0.45, 0.7, 1.0]
	for i in levels.size():
		var tank := _spawn("FbPinned%d" % i, Match.Team.RUST, "gang_ifv", Vector3(-12.0 + i * 8.0, 0, 0), Vector3.BACK)
		_hold_suppression[tank.name] = levels[i]
	_spawn("FbEyes", Match.Team.GREEN, "scout", Vector3(0, 0, 26), Vector3.FORWARD)
	await _shoot_held("pinned")


func _repair() -> void:
	_spawn("FbTanker", Match.Team.GREEN, "gang_support", Vector3(0, 0, 0), Vector3.FORWARD)
	for spec: Array in [["FbMend0", Vector3(-9, 0, -5)], ["FbMend1", Vector3(10, 0, 6)], ["FbFar", Vector3(24, 0, -6)]]:
		var tank := _spawn(String(spec[0]), Match.Team.GREEN, "gang_scout", spec[1], Vector3.FORWARD)
		tank.health = tank.max_health / 2
		tank.ticks_since_hit = 1_000_000
		_hold_health[tank.name] = tank.health
	await _shoot_held("repair", Vector3(4, 0, 0))


func _cone() -> void:
	_emitter = _spawn("FbEmitter", Match.Team.GREEN, "law_suppressor", Vector3(0, 0, 14), Vector3.FORWARD)
	_spawn("FbVictim0", Match.Team.RUST, "gang_ifv", Vector3(-4, 0, -6), Vector3.BACK)
	_spawn("FbVictim1", Match.Team.RUST, "gang_scout", Vector3(5, 0, -10), Vector3.BACK)
	_emitter_target = _site + Vector3(0, 1, -8).rotated(Vector3.UP, _yaw)
	await _shoot_held("cone", Vector3(0, 0, 2))


## A held situation with its look on at his pose and close in, a clip at his pose, then one still with it off.
func _shoot_held(slot: String, centre := Vector3.ZERO) -> void:
	await _seconds(2.5)
	FeedbackLook.use("%s:on" % slot)
	for distance: float in [DISTANCE_M, CLOSE_M]:
		_pose(distance, centre)
		await _seconds(SETTLE_S + 0.3)
		await _frames(2)
		_save("%s_on_%s" % [slot, "rts" if distance == DISTANCE_M else "close"])
	if clip_frames > 0:
		_pose(DISTANCE_M, centre)
		await _seconds(SETTLE_S)
		await _clip("%s_on" % slot, Callable())
	FeedbackLook.use("%s:off" % slot)
	_pose(DISTANCE_M, centre)
	await _seconds(SETTLE_S + 0.3)
	await _frames(2)
	_save("%s_off_rts" % slot)


## `clip_frames` frames at CLIP_FPS into <dir>/<name>/frame_NNN.png (the Makefile joins them with ffmpeg).
func _clip(clip_name: String, each: Callable) -> void:
	var folder := out_dir.path_join(clip_name)
	DirAccess.make_dir_recursive_absolute(folder)
	for frame in clip_frames:
		if each.is_valid():
			each.call(frame)
		await _seconds(1.0 / CLIP_FPS)
		await _frames(1)
		get_viewport().get_texture().get_image().save_png(folder.path_join("frame_%03d.png" % frame))
	print("FEEDBACK_CLIP %s frames=%d" % [clip_name, clip_frames])


## Call after `await _frames(2)`: two frames after a change the viewport texture holds it (a second
## RenderingServer.frame_post_draw never returned on builder0's hidden window, weapon_showcase's note).
func _save(file_name: String) -> void:
	var path := out_dir.path_join(file_name + ".png")
	var err := get_viewport().get_texture().get_image().save_png(path)
	_written += 1
	var fx := FxWorld.existing()
	print("FEEDBACK_SHOT %s %s look=%s counts=%s" % [file_name, error_string(err), FeedbackLook._on,
			fx.feedback.last_counts if fx != null else {}])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
