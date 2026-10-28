extends SceneTree
## Replays the player's orders from a match recording (build/recordings/*.jsonl) into a headless skirmish with the same
## seed, arena and factions, so a playtest can be re-run under other switches. Prints REPLAY_ORDER per order issued and
## REPLAY_DONE with the new recording's path (MatchRecorder writes the census as in play).
##   godot --headless --fixed-fps 30 --path . --script res://tests/replay_orders.gd -- --orders=build/recordings/X.jsonl \
##         --seconds=50 [--player-faction=gangs --enemy-faction=syndicate] [any game switch, e.g. --attack-shot=off]
##         [--click=TICK:X,Z: the click of the group order at TICK, for a recording made before C44.2 recorded it]
## CP43.0 (round 43, native): what the recording holds is replayed as he played it, not as a headless start would deal it.
##   - the squad cap and the factions: his laptop preset fields four squads (a headless run is the desktop's five, and the
##     CPU's counter-lineup is dealt against the army it meets), read from the `match` row (`squad_cap`, `factions`) or,
##     on an older recording, from its roster (squads per side, Units.faction_of);
##   - the spawn: the army layout checks slots against the navmesh only once it is baked, which an interactive start and a
##     headless one reach at different moments (ARMY_LAYOUT_UNCHECKED), so every unit is placed where his match had it
##     (the `spawn` key, else the tick-0 census at 0.1 m);
##   - the orders he gave in the planning pause land in the pause, before the CPU's first plan (tick 1), as his did.

const MAIN := "res://game/main.tscn"
const ReplaySetup := preload("res://tests/replay/replay_setup.gd")

var _controls: RtsControls
var _match: Match
var _orders: Array = []
var _next := 0
var _until := 0
## Where each unit stood at his match's start: name -> [x, z] or [x, z, yaw].
var _spawn := {}


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
	var all_rows: Array = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.strip_edges() == "":
			continue
		var row: Variant = JSON.parse_string(line)
		if not (row is Dictionary):
			continue
		all_rows.append(row)
		if row["t"] == "match":
			header = row
		elif row["t"] == "order":
			_orders.append(row)
		elif row["t"] == "census" and _spawn.is_empty():
			for unit: Dictionary in row["units"]:
				_spawn[String(unit["n"])] = unit["pos"]
	var merged := _orders.size()
	_orders = ReplaySetup.merge_clicks(ReplaySetup.with_click(_orders, _flag("click", "")))
	if _orders.size() < merged:
		print("REPLAY_CLICKS_MERGED %d rows -> %d orders" % [merged, _orders.size()])
	var picks := ReplaySetup.inferred_formations(all_rows)
	if not picks.is_empty():
		print("REPLAY_FORMATIONS_INFERRED %d" % picks.size())
		# Each pick just before the first order of its tick that names its squad (else after that tick's orders): a pick
		# FORMS an idle squad's element, and elements plan in the order they were formed, so his Guns (ordered first,
		# formed first: the first task row) stay first.
		for pick: Dictionary in picks:
			var at := 0
			while at < _orders.size() and int(_orders[at]["tick"]) < int(pick["tick"]):
				at += 1
			while at < _orders.size() and int(_orders[at]["tick"]) == int(pick["tick"]) \
					and not (_orders[at]["units"] as Array).has(pick["units"][0]):
				at += 1
			_orders.insert(at, pick)
	if header.has("spawn"):
		_spawn = header["spawn"]
	var setup := ReplaySetup.from_header(header)
	var flags := LaunchFlags.from_environment()
	var wanted: Array[String] = []
	# Round 44: his seed as he typed it (ReplaySetup.seed_text) and his render preset (the laptop rolls armies of at most 20).
	var extras: Array = ["--skirmish", "--enemy=cpu", "--seed=%s" % ReplaySetup.seed_text(header),
			"--arena=%s" % String(header.get("arena", "locks")), "--no-pick-faction", "--hints=off",
			"--player-faction=%s" % _flag("player-faction", setup["player_faction"]),
			"--enemy-faction=%s" % _flag("enemy-faction", setup["enemy_faction"]),
			"--squad-cap=%s" % _flag("squad-cap", str(setup["squad_cap"]))]
	if header.has("preset"):
		extras.append("--render-preset=%s" % String(header["preset"]))
	for extra: String in extras:
		var parts := extra.trim_prefix("--").split("=", true, 1)
		if not flags.values.has(parts[0]):  # a switch on the command line wins (an A/B of the replay)
			wanted.append(extra)
	for key: String in ReplaySetup.match_switches(header):
		if not flags.values.has(key) and not wanted.any(func(w: String) -> bool: return w.begins_with("--%s=" % key) or w == "--" + key):
			var value := String(header["flags"][key])
			wanted.append("--%s=%s" % [key, value] if value != "" else "--" + key)
	# CP43.0: the match's own switches go on the PROCESS's command line, not only into Main.next_flags. Arena._ready, the
	# planner seam and every `--<switch>=off` read LaunchFlags.from_environment(), so a flag that is only in next_flags
	# never reaches them: until round 43 every replay of his Locks match ran on the default layout (foundry: the same
	# spawn spots, other streets) with no objectives. Missing ones re-run this script once with them appended.
	var shim := ""
	if not ReplaySetup.trig_is_correctly_rounded():
		shim = ReplaySetup.trig_shim()
		if shim == "" or OS.get_environment("LD_PRELOAD").contains(shim):
			print("REPLAY_TRIG_MISMATCH this process's atan2f is not correctly rounded and no shim helps: the replay will leave"
					+ " his match within a second (run it through make: make replay-match)")
			shim = ""
	if not wanted.is_empty() or shim != "":
		if shim != "":
			# The re-run inherits the environment: the same LD_PRELOAD make gives every Godot it starts.
			OS.set_environment("LD_PRELOAD", shim)
			print("REPLAY_TRIG_SHIM " + shim)
		var args := ReplaySetup.reexec_args(OS.get_cmdline_args(), OS.get_cmdline_user_args(), wanted,
				DisplayServer.get_name() == "headless", ProjectSettings.globalize_path("res://"))
		print("REPLAY_REEXEC " + " ".join(wanted))
		var output: Array = []
		var code := OS.execute(OS.get_executable_path(), args, output, true)
		for chunk: String in output:
			printraw(chunk)
		quit(code)
		return
	# Round 44 (native N2): a match whose seed was not recorded (seed -1: his `--seed=56416.`) rolled its armies from the
	# clock. The army seed that fields his exact roster goes to the skirmish only (Main.next_flags); the process command line
	# keeps his seed text, so Match's fire RNG falls back as his did. A `--seed` given to the replay by hand is left alone.
	if int(header.get("seed", 0)) < 0 and flags.text("seed") == ReplaySetup.seed_text(header):
		var found := ReplaySetup.army_seed(header, setup, flags.integer("budget", 0),
				ReplaySetup.clock_seeds(String(header.get("path", "")), int(Time.get_time_zone_from_system().get("bias", 0))))
		if found >= 0:
			flags.values["seed"] = str(found)
			print("REPLAY_SEED_RECOVERED " + JSON.stringify({"army_seed": found, "typed": ReplaySetup.seed_text(header)}))
		else:
			print("REPLAY_SEED_UNKNOWN his seed was not recorded and no clock seed near the recorder's start fields his roster")
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
	var roster := ReplaySetup.roster_difference(header, _match)
	if roster != "":
		print("REPLAY_ROSTER_MISMATCH " + roster)
	if header.has("native") and bool(header["native"]) != BrainSwitches.native:
		# His seed 56416: the GDScript path leaves his native match at tick ~300 (round 43). Said, never silent.
		print("REPLAY_NATIVE_MISMATCH recorded=%s replay=%s: expect a different match (make native, or NATIVE=off)"
				% [header["native"], BrainSwitches.native])
	print("REPLAY_SETUP " + JSON.stringify({"orders": _orders.size(), "seed": header.get("seed"), "arena": header.get("arena"),
			"layout": String(Arena.active.get("name", "")), "objectives": _match.objectives.map(func(o: Dictionary) -> String: return String(o["name"])),
			"tick": _match.tick, "units": _match.tanks.get_child_count()}))
	var placed := 0
	if _flag("spawn", "on") != "off":
		placed = ReplaySetup.place(_match, _spawn)
	print("REPLAY_SPAWN " + JSON.stringify({"placed": placed, "recorded": _spawn.size()}))
	_issue()  # the orders of the planning pause, before the CPU's first plan
	if paused:
		_controls.set_paused(false, "")
	_until = int(float(_flag("seconds", "50")) * 30.0)
	physics_frame.connect(_step)


func _step() -> void:
	if _match == null:
		return
	_issue()
	_trace()
	if _match.tick >= _until:
		print("REPLAY_DONE " + JSON.stringify({"tick": _match.tick}))
		quit(0)


func _issue() -> void:
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
		if String(o["verb"]) == "formation":
			var picked := _controls.set_formation(String(o["formation"]))
			print("REPLAY_ORDER " + JSON.stringify({"tick": _match.tick, "at": o["tick"], "verb": "formation",
					"formation": o["formation"], "n": names.size(), "said": picked}))
			continue
		var extra := {"queue": bool(o.get("queue", false))}
		if o.has("to"):
			extra["to"] = o["to"]
		if o.has("target"):
			extra["target"] = o["target"]
		var said: String = _controls.order_selection(String(o["verb"]), extra)
		print("REPLAY_ORDER " + JSON.stringify({"tick": _match.tick, "at": o["tick"], "verb": o["verb"], "n": names.size(), "said": said}))


## `--trace=FROM-TO` (ticks): every unit's pose at full precision each tick of the window, one REPLAY_TRACE line per
## unit, so two arms (e.g. native v `--brains-off=native`) can be diffed for the first tick and crew that part.
func _trace() -> void:
	var window := _flag("trace", "")
	if window == "":
		return
	var bounds := window.split("-")
	if _match.tick < int(bounds[0]) or _match.tick > int(bounds[bounds.size() - 1]):
		return
	for tank: Tank in _match.sorted_team_tanks(0) + _match.sorted_team_tanks(1):
		if tank.is_alive():
			print("REPLAY_TRACE %d %s %.6f %.6f %.6f %.6f cmd %.9f %.9f" % [_match.tick, tank.name, tank.global_position.x,
					tank.global_position.z, tank.rotation.y, tank.velocity.length(), tank.command.throttle, tank.command.turn])
