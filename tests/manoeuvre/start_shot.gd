extends SceneTree
## Round 44 (manoeuvre M2): HIS RECORDED START REPLAYED IN A WINDOW, THE CAMERA ON ONE CREW, A PNG PER TICK ASKED FOR. The
## faithful replay's setup (tests/replay_orders.gd, CP43.0: the match's own switches on the real command line, the recorded
## spawn, the planning-pause orders issued in the pause) with the RTS camera following `--follow` instead of his camera, so a
## before / after pair of the same crew can be looked at.
##   godot --fixed-fps 30 --resolution 1920x1080 --path . --script res://tests/manoeuvre/start_shot.gd -- --orders=<abs .jsonl> \
##         --follow=Green_Guns_2 --shots=30,60,90,120 --out=<abs dir> --name=base [any game switch, e.g. --traffic-on=backout]
## Needs a display (make remote T=manoeuvre-start-shots). Prints SHOT_SAVED <tick> <path> per PNG, SHOT_DONE at the end.

const MAIN := "res://game/main.tscn"
const ReplaySetup := preload("res://tests/replay/replay_setup.gd")

var _controls: RtsControls
var _match: Match
var _orders: Array = []
var _spawn := {}
var _next := 0
var _shots: Array = []
var _out := ""
var _name := "base"
var _follow := ""
var _following := false


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var path := _flag("orders", "")
	var header := {}
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.strip_edges() == "":
			continue
		var row: Variant = JSON.parse_string(line)
		if not (row is Dictionary):
			continue
		if row["t"] == "match":
			header = row
		elif row["t"] == "order":
			_orders.append(row)
	_orders = ReplaySetup.merge_clicks(_orders)
	if header.has("spawn"):
		_spawn = header["spawn"]
	var setup := ReplaySetup.from_header(header)
	var flags := LaunchFlags.from_environment()
	var wanted: Array[String] = []
	for extra: String in ["--skirmish", "--enemy=cpu", "--seed=%d" % int(header.get("seed", 0)),
			"--arena=%s" % String(header.get("arena", "locks")), "--no-pick-faction", "--hints=off",
			"--player-faction=%s" % _flag("player-faction", setup["player_faction"]),
			"--enemy-faction=%s" % _flag("enemy-faction", setup["enemy_faction"]),
			"--squad-cap=%s" % _flag("squad-cap", str(setup["squad_cap"]))]:
		var parts := extra.trim_prefix("--").split("=", true, 1)
		if not flags.values.has(parts[0]):
			wanted.append(extra)
	for key: String in ReplaySetup.match_switches(header):
		if not flags.values.has(key) and not wanted.any(func(w: String) -> bool: return w.begins_with("--%s=" % key) or w == "--" + key):
			var value := String(header["flags"][key])
			wanted.append("--%s=%s" % [key, value] if value != "" else "--" + key)
	if not wanted.is_empty():
		var args := ReplaySetup.reexec_args(OS.get_cmdline_args(), OS.get_cmdline_user_args(), wanted,
				DisplayServer.get_name() == "headless", ProjectSettings.globalize_path("res://"))
		print("SHOT_REEXEC " + " ".join(wanted))
		var output: Array = []
		var code := OS.execute(OS.get_executable_path(), args, output, true)
		for chunk: String in output:
			printraw(chunk)
		quit(code)
		return
	for part in _flag("shots", "30,60,90,120").split(",", false):
		_shots.append(int(part))
	_out = _flag("out", ProjectSettings.globalize_path("res://build/manoeuvre/shots"))
	_name = _flag("name", "base")
	_follow = _flag("follow", "Green_Guns_2")
	DirAccess.make_dir_recursive_absolute(_out)
	Main.next_flags = flags
	change_scene_to_file(MAIN)
	for i in 40:
		await physics_frame
	_controls = current_scene.find_child("TacticalMap", true, false) as RtsControls
	if _controls == null:
		print("SHOT_DONE {\"error\": \"no RtsControls\"}")
		quit(2)
		return
	_match = _controls.game_match
	var placed: int = ReplaySetup.place(_match, _spawn)
	print("SHOT_SETUP " + JSON.stringify({"orders": _orders.size(), "placed": placed, "arena": String(Arena.active.get("name", "")),
			"native": BrainSwitches.native, "shots": _shots, "follow": _follow}))
	_issue()
	_controls.set_paused(false, "")
	physics_frame.connect(_step)


func _issue() -> void:
	while _next < _orders.size() and int(_orders[_next]["tick"]) <= _match.tick:
		var o: Dictionary = _orders[_next]
		_next += 1
		var names: Array = []
		for n in o["units"]:
			var tank := _match.tanks.get_node_or_null(NodePath(String(n))) as Tank
			if tank != null and tank.is_alive():
				names.append(String(n))
		if names.is_empty() or String(o["verb"]) == "formation":
			continue
		_controls.selection.set_units(names)
		var extra := {"queue": bool(o.get("queue", false))}
		if o.has("to"):
			extra["to"] = o["to"]
		if o.has("target"):
			extra["target"] = o["target"]
		_controls.order_selection(String(o["verb"]), extra)


func _step() -> void:
	if _match == null:
		return
	_issue()
	# The camera on the crew every tick (follow() is overridden by the skirmish's own framing; a manual focus is not).
	var rig := current_scene.find_child("RtsCamera", true, false) as RtsCamera
	var tank := _match.tanks.get_node_or_null(NodePath(_follow)) as Tank
	if rig != null and tank != null:
		rig.focus_on(tank.global_position)
		if not _following:
			rig.zoom = minf(rig.zoom, 0.35)
			_following = true
	if _shots.has(_match.tick):
		_shots.erase(_match.tick)
		var tick := _match.tick
		await RenderingServer.frame_post_draw
		var file := "%s/%s-t%d.png" % [_out, _name, tick]
		var err := root.get_viewport().get_texture().get_image().save_png(file)
		print("SHOT_SAVED %d %s%s" % [tick, file, "" if err == OK else " FAILED " + error_string(err)])
	if _shots.is_empty():
		print("SHOT_DONE " + JSON.stringify({"tick": _match.tick}))
		quit(0)
