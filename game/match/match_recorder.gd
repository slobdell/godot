class_name MatchRecorder
extends Node
## THE BLACK BOX. Every skirmish writes one, by default, so that "I had several squads attacking a single IFV and it
## would not die" can be answered by reading what happened instead of by guessing at it.
##
## The lead, 2026-09-25: *"we should make it the default while we debug and develop such that make skirmish records
## the match to a file that you can easily play back to see the behaviors I might describe."*
##
## It records the three things his reports are always about — **what he ordered, what the units then carried, and what
## the guns actually did** — as one JSONL file per match:
##
##   {"t":"match",  ...}                          once: seed, arena, factions, the roster with every unit's stats
##                                                (+ C43.2: squad_cap, factions, preset, native, flags, spawn, frame)
##   {"t":"order",  tick, units, verb, source, to, target, formation, error}   every command, WITH its refusal
##                                                (+ C43.2: frame, paused; verb "formation" = a formation pick)
##   {"t":"task",   tick, element, verb, to, formation}                        every squad task the leader took
##   {"t":"hit",    tick, shooter, target, weapon, face, weak, shield, hull, killed}
##   {"t":"census", tick, units:[{name, id, team, pos, hp, hp_max, shield, order, phase, blocked}]}  every CENSUS_S
##   {"t":"dead",   tick, unit, killer, cause}
##   {"t":"end",    tick, result}
##   {"t":"cam",    tick, yaw, want, pitch, dist, target:[x,z], mode, turn}  every CENSUS_S and at each automatic turn's start
##                  (round 43, camera K5.1, C43.2: the camera's own row, RtsCamera.record_row; none without a camera)
##
## `hit` is the row that answers the unkillable-IFV class of report on its own: it separates SHIELD damage from HULL
## damage, so "everyone is shooting it and its health bar never moves" is visibly either shots that never land, or
## shots landing entirely on a shield that recharges faster than they arrive.
##
## Cost: a handful of dictionary writes per event and one census a second, appended to an open file. Nothing here is
## read by the simulation, so a recording can never change a match.

## How often the census is written (seconds of match time).
const CENSUS_S := 1.0
## Keep this many recordings; older ones are deleted on start so a week of play cannot fill the disk.
const KEEP := 40

var game_match: Match
var orders: Object
var controls: Object
var elements: Object
var path := ""
## The match's seed, so a recording names the fight it came from and I can rebuild the same start.
var seed_value := -1

var _file: FileAccess
var _next_census := 0.0
var _seen_tasks := {}
var _next_cam := 0.0
var _cam_turns := 0


static func start(p_match: Match, p_orders: Object, p_controls: Object, p_elements: Object,
		dir: String, label := "", p_seed := -1) -> MatchRecorder:
	var recorder := MatchRecorder.new()
	recorder.name = "MatchRecorder"
	recorder.game_match = p_match
	recorder.orders = p_orders
	recorder.controls = p_controls
	recorder.elements = p_elements
	recorder.seed_value = p_seed
	recorder.path = dir.path_join("%s%s.jsonl" % [Time.get_datetime_string_from_system().replace(":", "-"),
			("-" + label) if label != "" else ""])
	p_match.add_child(recorder)
	return recorder


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_prune(path.get_base_dir())
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_warning("MatchRecorder: cannot write %s" % path)
		return
	# A stable name for the newest recording, so "read the last match" never needs a timestamp.
	var latest := FileAccess.open(path.get_base_dir().path_join("latest.txt"), FileAccess.WRITE)
	if latest != null:
		latest.store_string(path)
	var row := {"t": "match", "path": path, "arena": String(Arena.active.get("name", "")),
			"seed": seed_value,
			"tick_rate": SimClock.TICK_RATE, "tuning": Units.tuning.duplicate(),
			"units": _roster()}
	row.merge(replay_keys(game_match, _launch_flags()))
	_write(row)
	if game_match.has_signal("projectile_impact"):
		game_match.projectile_impact.connect(_on_impact)
	if game_match.has_signal("unit_destroyed"):
		game_match.unit_destroyed.connect(_on_destroyed)
	if game_match.has_signal("finished"):
		game_match.finished.connect(func(result: Dictionary) -> void:
			_write({"t": "end", "tick": game_match.tick, "result": result}))
	if controls != null and controls.has_signal("command_issued"):
		controls.command_issued.connect(_on_command)
	# C43.2 (round 43): a formation pick (G, Shift+G, the panel) re-tasks the selected squads WITHOUT a command, so it
	# was never recorded and his round-41 match could not be replayed (three squads in column from tick 0). It is an
	# `order` row with verb "formation" (an added verb; no `to`, so tools/recording_arrivals.py skips it).
	if controls != null and controls.has_signal("formation_changed"):
		controls.formation_changed.connect(_on_formation)
	print("MATCH_RECORDING %s" % path)


## C43.2 (round 43, native): what a replay of this match needs that the rest of the header does not hold (CP43.0:
## tests/replay_orders.gd). ADDITIVE keys; nothing above changes meaning.
##   squad_cap  the squads a side fields (his laptop preset: 4; a headless replay would otherwise field 5)
##   factions   {green, rust}, from each side's first unit
##   preset     RenderLevers' preset (the cap and the planner slice are read from it)
##   native     whether the C++ library ran the crews: the GDScript path is a different match after ~10 s on his seed
##   flags      the match's launch switches (`--attack-shot=off`, ...), as Main read them
##   spawn      {name: [x, z, yaw]} at full precision, where the army layout put every unit
##   frame      the physics frame the match started on (an order row's `frame` is counted from the same clock)
static func replay_keys(p_match: Match, flags: LaunchFlags) -> Dictionary:
	var faction := {"green": "", "rust": ""}
	var spawn := {}
	if p_match.tanks != null:
		for child in p_match.tanks.get_children():
			var tank := child as Tank
			if tank == null:
				continue
			var side := "green" if tank.team == Match.Team.GREEN else "rust"
			if String(faction[side]) == "":
				faction[side] = Units.faction_of(String(tank.unit_id))
			spawn[String(tank.name)] = [tank.global_position.x, tank.global_position.z, tank.rotation.y]
	return {"squad_cap": SkirmishMode.squad_cap_for(flags), "factions": faction, "preset": RenderLevers.preset(),
			"native": BrainSwitches.native, "flags": flags.values.duplicate(), "spawn": spawn,
			"frame": Engine.get_physics_frames()}


## The switches this match was launched with: Main's (a garage FIGHT hands them over in Main.next_flags), else the
## process's command line.
func _launch_flags() -> LaunchFlags:
	var main := get_tree().current_scene if is_inside_tree() else null
	if main != null and "flags" in main and main.flags is LaunchFlags:
		return main.flags
	return LaunchFlags.from_environment()


## Every unit in the match with the numbers a report is usually about: what it is, how much health and shield it has,
## and what its armour is. Without this a census row's `hp` has no scale.
func _roster() -> Array:
	var out: Array = []
	if game_match.tanks == null:
		return out
	for child in game_match.tanks.get_children():
		var tank := child as Tank
		if tank == null:
			continue
		var id := String(tank.unit_id)
		out.append({"name": String(tank.name), "id": id, "team": tank.team,
				"display": String(Units.stat(id, "display_name", id)),
				"hp_max": float(Units.stat(id, "max_health", 0.0)),
				"shield": float(Units.stat(id, "max_shield", 0.0)),
				# The two numbers that decide whether sustained fire can ever kill this thing: a shield that comes
				# back at `rate` per second after `delay` seconds without a hit sets a FLOOR on the damage per
				# second an attacker needs. Below that floor the hull never drops and the unit reads as invincible.
				"shield_rate": float(Units.stat(id, "shield_recharge_rate", 0.0)),
				"shield_delay": float(Units.stat(id, "shield_recharge_delay", 0.0)),
				"armor": Units.stat(id, "armor", {}), "weapon": String(Units.stat(id, "weapon", "")),
				"hull_size": Units.stat(id, "hull_size", Vector3.ZERO)})
	return out


func _on_command(command: Dictionary, error: String) -> void:
	var row := {"t": "order", "tick": game_match.tick, "verb": String(command.get("verb", "")),
			"units": command.get("units", []), "source": String(command.get("source", ""))}
	for key in ["to", "target", "formation", "queue", "facing"]:
		if command.has(key):
			row[key] = command[key]
	if error != "":
		row["error"] = error  # the refusal the player saw, beside the order he tried to give
	# C43.2: when the order landed: the physics frame (the `match` row's `frame` is the start) and whether the match was
	# paused (the planning pause: such an order is in force before the CPU's first plan).
	row["frame"] = Engine.get_physics_frames()
	row["paused"] = get_tree().paused if is_inside_tree() else false
	_write(row)


func _on_formation(id: String) -> void:
	var units: Array = []
	if "selection" in controls and controls.selection != null:
		units = Array(controls.selection.units).duplicate()
	_on_command({"verb": "formation", "units": units, "source": "player", "formation": id}, "")


func _on_impact(event: Dictionary) -> void:
	if not event.has("target"):
		return  # a round into a wall: not what any of these reports are about
	var row := {"t": "hit", "tick": int(event.get("tick", game_match.tick)),
			"target": String(event.get("target", "")), "face": String(event.get("face", "")),
			"weak": bool(event.get("weak_spot", false)), "damage": float(event.get("damage", 0.0)),
			"killed": bool(event.get("killed", false))}
	if event.has("shooter"):
		row["shooter"] = String(event["shooter"])
	if event.has("weapon"):
		row["weapon"] = String(event["weapon"])
	if event.has("victims"):
		row["victims"] = event["victims"]
	_write(row)


func _on_destroyed(event: Dictionary) -> void:
	_write({"t": "dead", "tick": int(event.get("tick", game_match.tick)), "unit": String(event.get("unit", "")),
			"id": String(event.get("unit_id", "")), "team": int(event.get("team", -1)),
			"killer": String(event.get("killer", "")), "cause": String(event.get("cause", ""))})


func _physics_process(_delta: float) -> void:
	_record_camera()
	if NativeRecorder.usable():  # round 28 (native N7.6): the task scan, the census and their rows natively
		NativeBridge.impl.recorder_tick(self)
		return
	if _file == null or game_match == null:
		return
	_record_tasks()
	var now := float(game_match.tick) / float(SimClock.TICK_RATE)
	if now < _next_census:
		return
	_next_census = now + CENSUS_S
	var units: Array = []
	for child in game_match.tanks.get_children():
		var tank := child as Tank
		if tank == null or not tank.is_alive():
			continue
		units.append(census_row(tank, orders))
	_write({"t": "census", "tick": game_match.tick, "units": units})


## One unit's census row. S7 (round 16): `phase` and `blocked` are read straight off the unit's Movement instead of
## through `Movement.state()`, which builds a ~25-key reading per unit (legibility, corridor, clearance, ...) of which
## the census keeps two -- 2.3 of the census's 3.3 ms (laptop, his armies, 60 units). Same values, same row, same
## bytes: `reading()` gives "phase" = phase and "blocked_by" = blocked_by only while blocked or yielding
## (`tests/test_match_recorder_census.gd` pins it against the reading).
static func census_row(tank: Tank, p_orders: Object) -> Dictionary:
	var order: Dictionary = p_orders.call("current", String(tank.name)) if p_orders != null else {}
	var mover := Movement.of(tank)
	var phase := ""
	var blocked := ""
	if mover != null:
		phase = String(mover.phase)
		if phase == "blocked" or phase == "yielding":
			blocked = String(mover.blocked_by)
	return {"n": String(tank.name), "team": tank.team,
			"pos": [snappedf(tank.global_position.x, 0.1), snappedf(tank.global_position.z, 0.1)],
			"hp": snappedf(tank.health, 0.1), "shield": snappedf(tank.shield if "shield" in tank else 0.0, 0.1),
			"order": String(order.get("verb", "")), "src": String(order.get("source", "")),
			"phase": phase, "blocked": blocked}


## Round 43 (camera K5.1, C43.2): where the camera looked, so "the camera was still angled toward the building" can be
## scrubbed. The rig is the controls' (`controls.rig`); a match without one (headless harnesses) writes no `cam` rows.
func _record_camera() -> void:
	if _file == null or game_match == null or controls == null:
		return
	var rig: Variant = controls.get("rig")
	if rig == null or not is_instance_valid(rig) or not (rig as Object).has_method("record_row"):
		return
	var turned := int(rig.turns) != _cam_turns
	var now := float(game_match.tick) / float(SimClock.TICK_RATE)
	if not turned and now < _next_cam:
		return
	var row := {"t": "cam", "tick": game_match.tick}
	row.merge(rig.record_row())
	if turned:
		_cam_turns = int(rig.turns)
		row["mode"] = String(rig.turn_mode)
		row["turn"] = true
	else:
		_next_cam = now + CENSUS_S
	_write(row)


## A squad's task, written when it CHANGES: the bridge between "what he clicked" and "what the crews carried".
func _record_tasks() -> void:
	if elements == null or not elements.has_method("of_team"):
		return
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		for element: Variant in elements.call("of_team", team):
			var task: Dictionary = element.get("task")
			var key := "%s|%s" % [element.get("id"), JSON.stringify(task)]
			if _seen_tasks.has(key):
				continue
			_seen_tasks[key] = true
			_write({"t": "task", "tick": game_match.tick, "element": String(element.get("element_name")),
					"team": team, "task": task, "formation": String(element.get("formation")),
					"why": String(element.get("reason"))})


## Flushed on EVERY row, deliberately. A black box that loses its contents when the process dies is worse than no
## black box: the first smoke test of this file was killed by a timeout and left a truncated header and nothing else,
## which is exactly how a real session would end (the player closes the window, or the game crashes — the two cases
## a recording is most wanted for). A line of JSON per event is nothing beside a frame.
func _write(row: Dictionary) -> void:
	if _file == null:
		return
	_file.store_line(JSON.stringify(row))
	_file.flush()


func _exit_tree() -> void:
	if _file != null:
		_file.flush()
		_file = null


## Keep the newest KEEP recordings in `dir`.
static func _prune(dir: String) -> void:
	var names := DirAccess.get_files_at(dir)
	if names.size() <= KEEP:
		return
	var recordings: Array = []
	for name in names:
		if name.ends_with(".jsonl"):
			recordings.append(name)
	recordings.sort()
	for i in maxi(0, recordings.size() - KEEP):
		DirAccess.remove_absolute(dir.path_join(String(recordings[i])))
