extends SceneTree
## Round 42 (engage, the player smoke): HIS CASE IN PICTURES. The replay's stage (Locks, seed 49326, his Rat Rod at 17 hp
## behind the 20-ft container, its squadmate, the Missile Ring) from his camera pose (21 deg pitch, FOV 35, 49 m, behind the
## crew looking at the target), a frame at each of SHOTS seconds after the attack order, in one arm. Needs a display.
##   godot --path . --resolution 1920x1080 --script res://tests/engage/engage_shots.gd -- --attack-shot=on|off [--tag=desktop]
## Frames: build/engage/shots/<tag>_<arm>_<NN>s.png; one ENGAGE_SHOT line per frame with the crew's state.

const OUT := "res://build/engage/shots"
const SHOTS := [0.0, 1.0, 3.0, 8.0, 20.0]
const HIS_PITCH_DEG := 21.0
const HIS_FOV_DEG := 35.0
const HIS_DISTANCE_M := 49.0
const CREW_AT := Vector3(44.3, 0.0, -74.4)
const SECOND_AT := Vector3(46.4, 0.0, -95.1)
const TARGET_AT := Vector3(24.3, 0.0, -91.7)

var case: TestCase
var camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	var tag := _flag("tag", "desktop")
	var arm := "on" if ElementPlan.ATTACK_SHOT else "off"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var lab := TacticsLab.create(case, 49326, "locks")
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var toward := TacticsFormation.flat(TARGET_AT - CREW_AT)
	var yaw := atan2(-toward.x, -toward.z)
	var crew := lab.unit(Match.Team.GREEN, "Green_Spears2_3", CREW_AT, yaw, "gang_scout")
	crew.health = 17
	var second := lab.unit(Match.Team.GREEN, "Green_Spears2_4", SECOND_AT, yaw, "gang_scout")
	var target := lab.gun(Match.Team.RUST, "Rust_Battery_1", TARGET_AT, yaw + PI, "syn_artillery")
	target.max_health = 1_000_000
	target.health = 1_000_000
	camera = Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	camera.fov = HIS_FOV_DEG
	await lab.start()
	var element := lab.elements.form([String(crew.name), String(second.name)], "Spears2")
	element.assign({"verb": "attack", "target": String(target.name), "formation": "echelon_right"})
	var brain := game_match.brains.get_node("Brain_" + String(crew.name)) as TankBrain
	RenderingServer.render_loop_enabled = false
	var next_shot := 0
	for tick in roundi(float(SHOTS[SHOTS.size() - 1]) * SimClock.TICK_RATE) + 1:
		if next_shot < SHOTS.size() and tick >= roundi(float(SHOTS[next_shot]) * SimClock.TICK_RATE):
			_his_pose(crew.global_position, toward)
			RenderingServer.render_loop_enabled = true
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			RenderingServer.render_loop_enabled = false
			var path := "%s/%s_%s_%02ds.png" % [OUT, tag, arm, int(SHOTS[next_shot])]
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			var pos := crew.global_position
			print("ENGAGE_SHOT %s t=%02ds crew (%.1f, %.1f) %.1f m from the target, gun on '%s', ray %s, choice %s, why '%s', order %s -> %s" % [
					path, int(SHOTS[next_shot]), pos.x, pos.z, Vector3(pos.x, 0, pos.z).distance_to(TARGET_AT), brain.engaged_target,
					Perception.has_line_of_sight(crew, target), brain.choice.get("option", ""), brain.why,
					(lab.orders.call("current", String(crew.name)) as Dictionary).get("verb", ""), 1_000_000 - target.health])
			next_shot += 1
		await lab.step()
	print("ENGAGE_SHOTS_DONE")
	lab.dispose()
	quit(0)


func _his_pose(focus: Vector3, heading: Vector3) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = HIS_FOV_DEG
	var look := Vector3(focus.x, 0.0, focus.z) + heading * 8.0
	camera.global_position = look - heading * HIS_DISTANCE_M * cos(deg_to_rad(HIS_PITCH_DEG)) \
			+ Vector3.UP * HIS_DISTANCE_M * sin(deg_to_rad(HIS_PITCH_DEG))
	camera.look_at(look, Vector3.UP)
