extends SceneTree
## `make nav-flow-look` (nav, round 8): what a five-squad move LOOKS like with flow fields on and off, from the lead's
## own camera (pitch 21, 49 m, FOV 35). This is condition 7 of the flow-field pre-registration in
## _agents/streams/nav.md, and it is the only one with no threshold: flow fields make units share a congestion
## gradient, which is how a formation turns into a herd, and the lead has already paid 4 seconds of arrival time for a
## tidier march. A number cannot see that. A person looking at build/nav-flow-look/*.png can.
##
## One army, no enemy, a plain move across the map: the question is the SHAPE of the group on the way, not the fight.
## The arm is printed from the live code (NAV_FLOW_LOOK_ARM), not from the flag passed, so two runs that captured the
## same treatment cannot look like a comparison.
## Needs a display (builder0's, via `make remote T=nav-flow-look`).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const SIZE := Vector2i(1280, 720)
const PITCH := 21.0
const DISTANCE := 49.0
const FOV := 35.0

var out := "/tmp/nav-flow-look"
var game_match: Match
var orders: Orders


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	out = _flag("out", out)
	var tag := _flag("tag", "flow" if FlowField.on() else "astar")
	var seconds := float(_flag("seconds", "30"))
	DirAccess.make_dir_recursive_absolute(out)
	GameTheme.use("cyberpunk")
	root.size = SIZE
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = _flag("arena", "terminus")
	root.add_child(arena)
	game_match = MATCH.instantiate()
	root.add_child(game_match)
	game_match.seed_spawns(1, 0.0)
	game_match.set_meta("player_team", Match.Team.GREEN)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	root.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = FOV
	camera.far = 900.0
	root.add_child(camera)
	camera.current = true
	await physics_frame
	for frame in 600:
		if Pathing.is_ready(arena):
			break
		await physics_frame
	var loaded := Army.load_army("cpu", 1, int(_flag("budget", "6500")), _flag("faction", ""))
	var error: String = loaded.get("error", "")
	if error == "":
		error = game_match.load_doctrine(Match.Team.GREEN, loaded["doctrine"])
	if error != "":
		push_error("nav-flow-look: " + error)
		quit(1)
		return
	orders = Orders.new()
	Orders.attach(game_match, orders)
	Elements.install(game_match, orders)
	var squads := {}
	for tank: Tank in game_match.tanks.get_children():
		if tank.team != Match.Team.GREEN or not tank.is_alive():
			continue
		var parts := String(tank.name).split("_")
		var squad: String = parts[1] if parts.size() >= 3 else "?"
		var names: Array = squads.get(squad, [])
		names.append(String(tank.name))
		squads[squad] = names
	var keys := squads.keys()
	keys.sort()
	print("NAV_FLOW_LOOK_ARM flow=%s arena=%s squads=%d" % [FlowField.on(), Arena.active.get("name", "?"), keys.size()])
	if keys.size() < 2:
		push_error("nav-flow-look control FAILED: %d squads" % keys.size())
		quit(1)
		return
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	var away := Match.spawn_position(Match.Team.RUST, 0)
	for i in keys.size():
		var lane := (float(i) - (keys.size() - 1) / 2.0) * 28.0
		orders.issue(UnitCommand.make(squads[keys[i]], "move", {"to": [away.x + lane, away.z]}))
	# A frame every two seconds, from a camera that keeps the whole moving army in shot by looking at its middle.
	var ticks := int(seconds * SimClock.TICK_RATE)
	for tick in ticks:
		if tick % (SimClock.TICK_RATE * 2) == 0:
			camera.global_transform = RtsCamera.pose_at(_middle(), deg_to_rad(150.0), DISTANCE * 2.5, PITCH)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("%s_%03d.png" % [tag, tick / SimClock.TICK_RATE]))
		await physics_frame
	print("NAV_FLOW_LOOK_DONE %s %s" % [tag, out])
	quit()


## The middle of the living green army, flattened (the camera follows the march rather than a fixed spot).
func _middle() -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for tank: Tank in game_match.tanks.get_children():
		if tank.team == Match.Team.GREEN and tank.is_alive():
			sum += tank.global_position
			count += 1
	return Vector3(sum.x / maxf(count, 1), 0.0, sum.z / maxf(count, 1))
