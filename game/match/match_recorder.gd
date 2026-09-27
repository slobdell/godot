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
##   {"t":"order",  tick, units, verb, source, to, target, formation, error}   every command, WITH its refusal
##   {"t":"task",   tick, element, verb, to, formation}                        every squad task the leader took
##   {"t":"hit",    tick, shooter, target, weapon, face, weak, shield, hull, killed}
##   {"t":"census", tick, units:[{name, id, team, pos, hp, hp_max, shield, order, phase, blocked}]}  every CENSUS_S
##   {"t":"dead",   tick, unit, killer, cause}
##   {"t":"end",    tick, result}
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
	_write({"t": "match", "path": path, "arena": String(Arena.active.get("name", "")),
			"seed": seed_value,
			"tick_rate": SimClock.TICK_RATE, "tuning": Units.tuning.duplicate(),
			"units": _roster()})
	if game_match.has_signal("projectile_impact"):
		game_match.projectile_impact.connect(_on_impact)
	if game_match.has_signal("unit_destroyed"):
		game_match.unit_destroyed.connect(_on_destroyed)
	if game_match.has_signal("finished"):
		game_match.finished.connect(func(result: Dictionary) -> void:
			_write({"t": "end", "tick": game_match.tick, "result": result}))
	if controls != null and controls.has_signal("command_issued"):
		controls.command_issued.connect(_on_command)
	print("MATCH_RECORDING %s" % path)


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
	_write(row)


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
		var order: Dictionary = orders.call("current", String(tank.name)) if orders != null else {}
		var mover: Dictionary = Movement.state(tank)
		units.append({"n": String(tank.name), "team": tank.team,
				"pos": [snappedf(tank.global_position.x, 0.1), snappedf(tank.global_position.z, 0.1)],
				"hp": snappedf(tank.health, 0.1), "shield": snappedf(tank.shield if "shield" in tank else 0.0, 0.1),
				"order": String(order.get("verb", "")), "src": String(order.get("source", "")),
				"phase": String(mover.get("phase", "")), "blocked": String(mover.get("blocked_by", ""))})
	_write({"t": "census", "tick": game_match.tick, "units": units})


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
