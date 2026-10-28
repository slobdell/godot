extends SceneTree
## Replays the player's orders from a match recording (build/recordings/*.jsonl) into a headless skirmish with the same
## seed, arena and factions, so a playtest can be re-run under other switches. Prints REPLAY_ORDER per order issued and
## REPLAY_DONE with the new recording's path (MatchRecorder writes the census as in play).
##   godot --headless --fixed-fps 30 --path . --script res://tests/replay_orders.gd -- --orders=build/recordings/X.jsonl \
##         --seconds=50 [--player-faction=gangs --enemy-faction=syndicate] [any game switch, e.g. --attack-shot=off]

const MAIN := "res://game/main.tscn"

var _controls: RtsControls
var _match: Match
var _orders: Array = []
var _next := 0
var _until := 0


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


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
	var flags := LaunchFlags.from_environment()
	for extra: String in ["--skirmish", "--enemy=cpu", "--seed=%d" % int(header.get("seed", 0)),
			"--arena=%s" % String(header.get("arena", "locks")), "--no-control", "--no-pick-faction", "--hints=off",
			"--player-faction=%s" % _flag("player-faction", "gangs"), "--enemy-faction=%s" % _flag("enemy-faction", "syndicate")]:
		var parts := extra.trim_prefix("--").split("=", true, 1)
		flags.values[parts[0]] = parts[1] if parts.size() > 1 else ""
	Main.next_flags = flags
	change_scene_to_file(MAIN)
	for i in 40:
		await physics_frame
	_controls = current_scene.find_child("TacticalMap", true, false) as RtsControls
	if _controls == null:
		print("REPLAY_DONE {\"error\": \"no RtsControls\"}")
		quit(2)
		return
	_match = _controls.game_match
	print("REPLAY_SETUP " + JSON.stringify({"orders": _orders.size(), "seed": header.get("seed"), "arena": header.get("arena"),
			"tick": _match.tick, "units": _match.tanks.get_child_count()}))
	if paused:
		_controls.set_paused(false, "")
	_until = int(float(_flag("seconds", "50")) * 30.0)
	physics_frame.connect(_step)


func _step() -> void:
	if _match == null:
		return
	while _next < _orders.size() and int(_orders[_next]["tick"]) <= _match.tick:
		var o: Dictionary = _orders[_next]
		_next += 1
		var names: Array = []
		for n in o["units"]:
			var tank := _match.tanks.get_node_or_null(NodePath(String(n))) as Tank
			if tank != null and tank.is_alive():
				names.append(String(n))
		if names.is_empty():
			print("REPLAY_ORDER " + JSON.stringify({"tick": _match.tick, "skipped": o}))
			continue
		_controls.selection.set_units(names)
		var extra := {"queue": bool(o.get("queue", false))}
		if o.has("to"):
			extra["to"] = o["to"]
		if o.has("target"):
			extra["target"] = o["target"]
		var said: String = _controls.order_selection(String(o["verb"]), extra)
		print("REPLAY_ORDER " + JSON.stringify({"tick": _match.tick, "at": o["tick"], "verb": o["verb"], "n": names.size(), "said": said}))
	if _match.tick >= _until:
		print("REPLAY_DONE " + JSON.stringify({"tick": _match.tick}))
		quit(0)
