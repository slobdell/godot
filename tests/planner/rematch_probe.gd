extends SceneTree
## Round 34 (planner, C34.6 (1); measurement only): does a rematch in ONE process replay the first match? The real
## game's path: Main.next_flags + a scene change to main.tscn, as ArmyLoop.restart's reload_current_scene does, run
## `--rematch-runs=N` times. Every match tick's Match.state_hash() up to `--rematch-ticks=T` is kept per run, and each
## later run is compared with run 0: REMATCH {"run", "first_diff_tick", "hash_at_T"}. Every other user argument is
## the match's own (the sim-baseline match by default: tools/sim_baseline.py's SIM_MATCH_ARGS), read by main.gd and
## Match exactly as on the command line.
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/planner/rematch_probe.gd -- --match --elimination \
##     --green-doctrine=res://doctrines/sim_baseline_green.json --rust-doctrine=res://doctrines/sim_baseline_rust.json \
##     --time-limit=40 --seed=3 --rematch-runs=3 --rematch-ticks=600
##
## `--rematch-phase=K`: each rematch starts K frames past a multiple of 60 after run 0 (an engine-frame phase shift).
## `--rematch-world=new`: the root viewport gets a new World3D (physics space + navigation map) before each rematch.
## `--rematch-load=fresh`: the rematch's main.tscn and every resource it uses are loaded again (CACHE_MODE_IGNORE_DEEP),
## not shared with the first match through the resource cache.
## `--rematch-detail=on` also compares every tank's full pose, velocities and command each tick (finer than the hash: a
## velocity differs before a position does), and prints every tank that differs at the first such tick (REMATCH_UNIT).

const MAIN := "res://game/main.tscn"

var _hashes: Array = []  # per run: tick -> state_hash
var _detail: Array = []  # per run: tick -> {unit: fields} (only with --rematch-detail=on)
var _run := 0
var _done := false
var _start_frame := -1  # the physics frame run 0's scene change was asked on
var _statics := {}  # "path:name" -> [script, name, value at start] (only with --rematch-statics)


func _initialize() -> void:
	physics_frame.connect(_sample)
	if _flag("rematch-statics", "off") != "off":
		_snapshot_statics()
	_idle_then_start.call_deferred()


## `--rematch-idle=N`: N physics frames pass before the first match (the engine's frame counters start at N, not 0).
func _idle_then_start() -> void:
	for i in int(_flag("rematch-idle", "0")):
		await physics_frame
	_next()


## `--rematch-statics=diff|restore`: every global class is loaded first and every static variable kept (deep copy);
## before each rematch the statics that differ from that start are printed (REMATCH_STATIC), and with `restore` set
## back. Diagnosis only: it loads scripts in a different order from the game.
func _snapshot_statics() -> void:
	for entry in ProjectSettings.get_global_class_list():
		var path := String(entry["path"])
		if not path.ends_with(".gd") or path.begins_with("res://tests/"):
			continue
		var script := load(path) as GDScript
		if script == null:
			continue
		for property in script.get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var value: Variant = script.get(property["name"])
				_statics["%s:%s" % [path, property["name"]]] = [script, property["name"], _copy(value)]


static func _copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Object or b is Object:
		return a == b
	return var_to_bytes(a) == var_to_bytes(b)


func _check_statics() -> void:
	var restore := _flag("rematch-statics", "off") == "restore"
	var changed := 0
	var keys := _statics.keys()
	keys.sort()
	for key: String in keys:
		var row: Array = _statics[key]
		var now: Variant = (row[0] as GDScript).get(row[1])
		if _same(now, row[2]):
			continue
		changed += 1
		var shown := str(now)
		print("REMATCH_STATIC run=%d %s %s" % [_run, key, shown.left(160) + ("... (%d chars)" % shown.length() if shown.length() > 160 else "")])
		if restore:
			(row[0] as GDScript).set(row[1], _copy(row[2]))
	print("REMATCH_STATICS run=%d changed=%d of %d%s" % [_run, changed, _statics.size(), " (restored)" if restore else ""])


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _match() -> Match:
	var scene := current_scene
	if scene == null or not scene.is_inside_tree():
		return null
	return scene.get_node_or_null("Match") as Match


func _next() -> void:
	if _run == 0:
		_start_frame = Engine.get_physics_frames()
	elif _flag("rematch-phase", "") != "":
		# Every rematch starts on a frame `--rematch-phase=K` past a multiple of 60 frames after run 0's start: a decision
		# keyed to the engine's frame counter with any period dividing 60 (2, 3, 4, 5, 6, ... 30) then sees another phase.
		var phase := int(_flag("rematch-phase", "1"))
		while (Engine.get_physics_frames() - _start_frame) % 60 != phase:
			await physics_frame
	_hashes.append({})
	_detail.append({})
	_done = false
	if _run > 0 and not _statics.is_empty():
		_check_statics()
	if _run > 0 and _flag("rematch-world", "same") == "new":
		root.world_3d = World3D.new()  # a fresh physics space and navigation map for the rematch
	Main.next_flags = LaunchFlags.from_environment()
	if _run > 0 and _flag("rematch-load", "cached") == "fresh":
		change_scene_to_packed(ResourceLoader.load(MAIN, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene)
		return
	change_scene_to_file(MAIN)


func _sample() -> void:
	if _done:
		return
	var game_match := _match()
	if game_match == null or game_match.tick <= 0:
		return
	var ticks := int(_flag("rematch-ticks", "600"))
	(_hashes[_run] as Dictionary)[game_match.tick] = game_match.state_hash()
	if _flag("rematch-detail", "off") == "on":
		var rows := {}
		for tank in game_match._sorted_tanks():
			rows[String(tank.name)] = [tank.global_position, tank.rotation, tank.turret.rotation.y, tank.health,
					tank.velocity, tank.real_velocity, tank.estimated_velocity, tank.command.throttle, tank.command.turn,
					tank.command.fire, tank.command.aim_point, String(tank.intent)]
		(_detail[_run] as Dictionary)[game_match.tick] = rows
	if game_match.tick >= ticks:
		_done = true
		_finish_run.call_deferred(ticks)


func _finish_run(ticks: int) -> void:
	var mine: Dictionary = _hashes[_run]
	var first: Dictionary = _hashes[0]
	var diff := -1
	var detailed := _flag("rematch-detail", "off") == "on"
	for tick in range(1, ticks + 1):
		if mine.get(tick, "") != first.get(tick, ""):
			diff = tick
			break
		if detailed and var_to_bytes((_detail[_run] as Dictionary).get(tick, {})) != var_to_bytes((_detail[0] as Dictionary).get(tick, {})):
			diff = tick
			break
	print("REMATCH " + JSON.stringify({"run": _run, "first_diff_tick": diff, "hash_at_T": mine.get(ticks, ""),
			"ticks": ticks, "process_frames": Engine.get_process_frames(), "physics_frames": Engine.get_physics_frames()}))
	if diff > 0 and _flag("rematch-detail", "off") == "on":
		var was: Dictionary = (_detail[0] as Dictionary).get(diff, {})
		var now: Dictionary = (_detail[_run] as Dictionary).get(diff, {})
		for unit: String in now.keys():
			if var_to_bytes(was.get(unit, [])) != var_to_bytes(now[unit]):
				print("REMATCH_UNIT run=%d tick=%d %s run0=%s now=%s" % [_run, diff, unit, str(was.get(unit, [])),
						str(now[unit])])
	_run += 1
	if _run >= int(_flag("rematch-runs", "2")):
		quit(0)
		return
	_next()
