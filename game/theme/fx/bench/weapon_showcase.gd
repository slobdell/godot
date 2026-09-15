extends Node3D
## Weapon FX showcase (`make fx-shots`): close-up captures of each weapon's fire, flight, and impact, staged with a real
## Match and real Tanks (so the shots go through the same rules, K2 events, and effect families as a game) in
## the night arena's lighting. For each scene a shooter fires at a target, and the camera jumps to the muzzle, the
## round in flight, and the impact at scripted times after the shot, saving a PNG each time. Visual only; needs a display.
## Flags: --shots=<abs dir> (required to save) --showcase=tank_hit,tank_kill,... (default: all) --theme=NAME

const SCENES := {
	# The tank cannon hitting a tank broadside: the muzzle blast, the glowing shell, the devastating hit.
	"tank_hit": {"shooter": "tank", "target": "tank", "distance": 34.0, "aim_offset": 0.0, "kill": false, "hold": 0.0,
			"shots": [["muzzle", 0.05, "shooter"], ["smoke", 0.45, "shooter"], ["flight", 0.22, "mid"], ["impact", 0.5, "target"],
					["aftermath", 1.1, "target"], ["rts_flight", 0.3, "rts"]]},
	"tank_kill": {"shooter": "tank", "target": "ifv", "distance": 34.0, "aim_offset": 0.0, "kill": true, "hold": 0.0,
			"shots": [["impact", 0.52, "target"], ["cook_off", 0.85, "target"], ["burning", 2.6, "target_wide"], ["rts_cook_off", 0.95, "rts"],
					["wreck", 7.0, "target_wide"]]},
	# Feel X4: a weak-spot hit (forced on: a staged shot hits the flank, not the engine deck) and rounds splashing on a
	# shield that holds.
	"tank_weak_spot": {"shooter": "tank", "target": "tank", "distance": 34.0, "aim_offset": 0.0, "kill": false, "hold": 0.0,
			"weak_spot": true, "shots": [["flare", 0.52, "target"], ["flare_late", 0.7, "target"], ["rts", 0.56, "rts"]]},
	"ifv_on_shield": {"shooter": "ifv", "target": "tank", "distance": 30.0, "aim_offset": 0.0, "kill": false, "hold": 1.5,
			"keep_shield": true, "shots": [["splash", 0.5, "target"], ["splash_2", 1.0, "target"]]},
	"tank_miss": {"shooter": "tank", "target": "tank", "distance": 34.0, "aim_offset": 7.0, "kill": false, "hold": 0.0,
			"shots": [["passing", 0.42, "target_wide"], ["dirt", 1.2, "far"], ["dust", 1.9, "far"]]},
	"ifv_burst": {"shooter": "ifv", "target": "scout", "distance": 30.0, "aim_offset": 0.0, "kill": false, "hold": 1.6,
			"shots": [["muzzle", 0.3, "shooter"], ["tracers", 0.75, "mid"], ["hits", 1.2, "target"], ["rts", 1.4, "rts"]]},
	"scout_stream": {"shooter": "scout", "target": "ifv", "distance": 26.0, "aim_offset": 0.0, "kill": false, "hold": 2.0,
			"shots": [["muzzle", 0.65, "shooter"], ["stream", 1.07, "mid"], ["hits", 1.5, "target"], ["rts", 1.91, "rts"]]},
}
const SHOOTER_Z := 18.0
## Feel X5: the controls stand-in (team and selection) for the orders scene.
const CONTROLS_STANDIN := """extends Node
var team := 0
var selection := Picked.new()
class Picked:
	var units: Array[String] = []
"""

var camera := Camera3D.new()
var _flags: LaunchFlags
var _dir := ""
var _match: Match


func _ready() -> void:
	_flags = LaunchFlags.from_environment()
	if not _flags.has("theme"):
		GameTheme.use("cyberpunk")
	_dir = _flags.text("shots")
	# A remote desktop's hidden window gets no vsync frame callbacks, which would stall the capture loop.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 90
	for slot_name in ["arena.environment", "arena.dressing"]:
		var slot := VisualSlot.new()
		slot.slot = slot_name
		add_child(slot)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	ground.add_child(shape)
	add_child(ground)
	camera.fov = 55.0
	add_child(camera)
	camera.current = true
	_run.call_deferred()


func _run() -> void:
	var names: Array = SCENES.keys()
	if _flags.text("showcase") != "":
		names = Array(_flags.text("showcase").split(","))
	# Let FxWorld exist and pre-warm its shaders before the first capture.
	FxWorld.get_instance()
	await _seconds(1.0)
	for scene_name in names:
		if SCENES.has(scene_name):
			await _stage(String(scene_name), SCENES[scene_name])
		elif scene_name == "orders":
			await _stage_orders()
		elif scene_name == "motion":
			await _stage_motion()
	if _flags.text("showcase") == "":
		await _stage_orders()  # every scene by default
		await _stage_motion()
	print("FX_SHOTS_DONE")
	var fx := FxWorld.existing()
	if fx != null:
		fx.sfx.stop_all()
	for i in 3:
		await get_tree().process_frame
	get_tree().quit()


func _stage(scene_name: String, scene: Dictionary) -> void:
	if _match != null:
		_match.queue_free()
		await get_tree().process_frame
	_match = preload("res://game/match/match.tscn").instantiate()
	_match.name = "Match"
	add_child(_match)
	_match.elimination = true  # the dead stay dead, so a wreck keeps burning where it fell
	var fx := FxWorld.get_instance()
	if fx != null:
		fx.link.attach(_match)
		fx.weapons.showcase_weak_spots = bool(scene.get("weak_spot", false))
	var shooter := _match.spawn_tank("Shooter", 0, Match.Team.GREEN, String(scene["shooter"]))
	var target := _match.spawn_tank("Target", 0, Match.Team.RUST, String(scene["target"]))
	await get_tree().physics_frame
	shooter.global_position = Vector3(0, 0, SHOOTER_Z)
	shooter.rotation.y = 0.0
	target.global_position = Vector3(0, 0, SHOOTER_Z - float(scene["distance"]))
	target.rotation.y = PI / 2.0
	if not scene.get("keep_shield", false):
		target.shield = 0.0
	if scene["kill"]:
		target.health = 1
	await _seconds(1.2)
	var aim := target.global_position + Vector3(float(scene["aim_offset"]), 1.0, 0.0)
	shooter.command.aim_point = aim
	await _seconds(0.4)
	# Shields recharge while the scene settles: strip them again right before the shot (unless the scene shows shields).
	if not scene.get("keep_shield", false):
		target.shield = 0.0
		target.ticks_since_hit = 0
	var fired_at := [-1.0]
	var clock := [0.0]
	shooter.fired.connect(func(_muzzle: Vector3, _direction: Vector3) -> void:
		if fired_at[0] < 0.0:
			fired_at[0] = clock[0])
	shooter.command.fire = true
	var hold := float(scene["hold"])
	var shots: Array = scene["shots"].duplicate()
	shots.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	var last_time := float(shots[-1][1])
	while fired_at[0] < 0.0 or clock[0] - fired_at[0] <= last_time + 0.05:
		await get_tree().process_frame
		clock[0] += get_process_delta_time()
		if fired_at[0] >= 0.0:
			var since: float = clock[0] - fired_at[0]
			shooter.command.fire = since < hold
			if not shots.is_empty() and since >= float(shots[0][1]):
				var shot: Array = shots.pop_front()
				_frame(String(shot[2]), shooter, target, aim)
				# Two frames later the viewport texture holds the new view. (Awaiting RenderingServer.frame_post_draw a
				# second time never returned on builder0's hidden Wayland window.)
				for i in 2:
					await get_tree().process_frame
					clock[0] += get_process_delta_time()
				_save("%s_%s" % [scene_name, shot[0]])
		elif clock[0] > 3.0:
			push_error("showcase %s: the shooter never fired" % scene_name)
			return


func _stage_orders() -> void:
	if _match != null:
		_match.queue_free()
		await get_tree().process_frame
	_match = preload("res://game/match/match.tscn").instantiate()
	_match.name = "Match"
	_match.elimination = true
	add_child(_match)
	var fx := FxWorld.get_instance()
	# Control's real K1 Orders (CP1); the controls stand-in only supplies the team and the selection.
	var orders := Orders.new(_match)
	Orders.attach(_match, orders)
	var controls_script := GDScript.new()
	controls_script.source_code = CONTROLS_STANDIN
	controls_script.reload()
	var controls: Node = controls_script.new()
	add_child(controls)
	fx.link.attach(_match)
	fx.order_feedback.attach(orders, _match, controls)
	var units: Array[String] = []
	for i in 4:
		var tank := _match.spawn_tank("Green%d" % i, 0, Match.Team.GREEN, ["tank", "ifv", "scout", "ifv"][i])
		units.append(String(tank.name))
	var enemy := _match.spawn_tank("Enemy", 0, Match.Team.RUST, "tank")
	await get_tree().physics_frame
	for i in 4:
		(_match.tanks.get_node(units[i]) as Node3D).global_position = Vector3(-9.0 + i * 6.0, 0, 20)
	enemy.global_position = Vector3(18, 0, -14)
	await _seconds(1.0)
	camera.global_position = Vector3(0, 38, 42)
	camera.look_at(Vector3(0, 0, 2), Vector3.UP)
	controls.selection.units.assign(units)
	await _seconds(0.12)
	_save("orders_select")
	orders.issue({"units": units, "verb": "move", "to": [-12.0, -6.0]}, Match.Team.GREEN)
	await _seconds(0.15)
	_save("orders_move")
	orders.issue({"units": units, "verb": "attack", "target": "Enemy"}, Match.Team.GREEN)
	await _seconds(0.15)
	_save("orders_attack")
	orders.issue({"units": units, "verb": "attack_move", "to": [4.0, -20.0]}, Match.Team.GREEN)
	orders.issue({"units": units, "verb": "move", "to": [22.0, 4.0], "queue": true}, Match.Team.GREEN)
	orders.issue({"units": units, "verb": "move", "to": [-20.0, 12.0], "queue": true}, Match.Team.GREEN)
	await _seconds(0.2)
	_save("orders_queue")
	controls.queue_free()


## Feel X6: a scout drifting around a curve, an IFV braking hard, a tank rolling past, moved by script (so the frames are
## repeatable), so dust, drift marks, and the lurch show.
func _stage_motion() -> void:
	if _match != null:
		_match.queue_free()
		await get_tree().process_frame
	_match = preload("res://game/match/match.tscn").instantiate()
	_match.name = "Match"
	_match.elimination = true
	add_child(_match)
	FxWorld.get_instance().link.attach(_match)
	var scout := _match.spawn_tank("Drifter", 0, Match.Team.GREEN, "scout")
	var ifv := _match.spawn_tank("Braker", 0, Match.Team.GREEN, "ifv")
	var tank := _match.spawn_tank("Roller", 0, Match.Team.RUST, "tank")
	await get_tree().physics_frame
	# The script moves them; with no commands the Tanks don't drive themselves. (simulate = false would make each one
	# glide back toward its replicated spawn position every frame.)
	var clock := 0.0
	var ifv_speed := 13.0
	var shots := [[1.6, "motion_drift"], [2.2, "motion_brake"], [2.9, "motion_rts"]]
	while not shots.is_empty():
		await get_tree().process_frame
		var dt := get_process_delta_time()
		clock += dt
		# The scout: a 14 m radius curve at 12 m/s, its nose turned into the curve so it slides outward.
		var angle := clock * 12.0 / 14.0
		scout.global_position = Vector3(cos(angle) * 14.0 - 14.0, 0.0, sin(angle) * 14.0)
		scout.rotation.y = -angle - 0.45
		tank.global_position = Vector3(18.0, 0.0, 22.0 - clock * 8.0)
		tank.rotation.y = 0.0
		if clock > 1.4:
			ifv_speed = maxf(0.0, ifv_speed - 32.0 * dt)
		ifv.global_position += Vector3.FORWARD.rotated(Vector3.UP, 0.3) * ifv_speed * dt
		ifv.rotation.y = 0.3
		if clock >= float(shots[0][0]):
			var shot: Array = shots.pop_front()
			match String(shot[1]):
				"motion_drift":
					camera.global_position = scout.global_position + Vector3(12.0, 9.0, 12.0)
					camera.look_at(scout.global_position, Vector3.UP)
				"motion_brake":
					camera.global_position = ifv.global_position + Vector3(9.0, 3.5, 2.0)
					camera.look_at(ifv.global_position + Vector3.UP, Vector3.UP)
				_:
					camera.global_position = Vector3(0.0, 40.0, 38.0)
					camera.look_at(Vector3(0.0, 0.0, 4.0), Vector3.UP)
			for i in 2:
				await get_tree().process_frame
			_save(String(shot[1]))


func _frame(view: String, shooter: Tank, target: Tank, aim: Vector3) -> void:
	var muzzle := shooter.muzzle_position()
	match view:
		"shooter":
			camera.global_position = muzzle + Vector3(6.5, 2.2, -5.0)
			camera.look_at(muzzle + Vector3(0, -0.3, -3.0), Vector3.UP)
		"mid":
			var middle := muzzle.lerp(aim, 0.5)
			camera.global_position = middle + Vector3(15.0, 7.0, 4.0)
			camera.look_at(middle, Vector3.UP)
		"target":
			camera.global_position = target.global_position + Vector3(7.0, 3.2, 6.5)
			camera.look_at(target.global_position + Vector3(0, 1.2, 0), Vector3.UP)
		"target_wide":
			camera.global_position = target.global_position + Vector3(14.0, 7.0, 13.0)
			camera.look_at(target.global_position + Vector3(0, 1.0, -3.0), Vector3.UP)
		"rts":
			# The skirmish's perspective RTS camera: ~45 m up and back, looking down at the fight.
			var middle := muzzle.lerp(aim, 0.5)
			camera.global_position = middle + Vector3(0.0, 42.0, 30.0)
			camera.look_at(middle, Vector3.UP)
		"far":
			var beyond := muzzle + (aim - muzzle).normalized() * 76.0
			camera.global_position = beyond + Vector3(12.0, 6.0, 12.0)
			camera.look_at(Vector3(beyond.x, 0.5, beyond.z), Vector3.UP)


func _save(file_name: String) -> void:
	if _dir == "":
		return
	var path := _dir.path_join(file_name + ".png")
	var err := get_viewport().get_texture().get_image().save_png(path)
	var fx := FxWorld.existing()
	var stats := ""
	if fx != null:
		stats = " tracers=%d bursts=%d events=%d lights=%d last=%s:%s" % [fx.tracers.active_count(), fx.bursts.started,
				fx.weapons.events, fx.lights.lit_count, fx.weapons.last_family, ",".join(fx.weapons.last_pieces)]
	print("FX_SHOT %s %s%s" % [file_name, error_string(err), stats])


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
