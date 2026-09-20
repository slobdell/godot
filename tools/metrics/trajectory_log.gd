extends Node
## The reference emitter for the trajectory log (contract S3; the format is `tools/metrics/FORMAT.md`).
##
## Round 8's probes kept a per-unit position trail in memory and threw it away, so every published number was a
## per-run aggregate and "reproduce it from the same replays" was not possible -- there were no replays. This node
## is the replay: one JSON line per living unit per tick.
##
## **A producer adds two lines and nothing else.** `install()` finds Orders, Elements and Movement from the match
## itself, samples on its own `_physics_process`, and closes the file when it leaves the tree. It is OFF unless a
## path is passed, so nothing about a normal run changes.
##
##     const TRAJECTORY := preload("res://tools/metrics/trajectory_log.gd")
##     TRAJECTORY.install(game_match, path, "nav-fight", {"time_limit": time_limit})
##
## Everything here is measurement, not game behaviour: this node never touches a TankCommand.

## Lines buffered before a write. One write a tick would be ~1800 syscalls a second at 60 units.
const FLUSH_EVERY := 512
## |speed| below this reports gear 0 (`fight_probe.gd` GEAR_SPEED, kept so the two agree).
const GEAR_SPEED := 0.5

var game_match: Match = null
var orders: Orders = null
var elements: Elements = null
var team_filter := -1

var _file: FileAccess = null
var _buffer := PackedStringArray()
var _heading := {}       # unit name -> accumulated, UNWRAPPED heading in radians
var _last_raw := {}      # unit name -> last wrapped heading, to unwrap against
var _lines := 0


## Start logging `p_match` to `path`. Returns the node, or null when `path` is empty (the off switch) or the file
## cannot be opened -- which is reported with push_error and never silently swallowed, because a measurement run
## that produced no log must not look like a measurement run that found nothing.
static func install(p_match: Match, path: String, producer: String, knobs: Dictionary = {},
		p_team: int = -1) -> Node:
	if path == "":
		return null
	var node := new()
	node.name = "TrajectoryLog"
	node.game_match = p_match
	node.team_filter = p_team
	if not node._open(path, producer, knobs):
		return null
	p_match.add_child(node)
	return node


func _open(path: String, producer: String, knobs: Dictionary) -> bool:
	var directory := path.get_base_dir()
	if directory != "":
		DirAccess.make_dir_recursive_absolute(directory)
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_error("trajectory log: cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	var header := {
		"kind": "header", "format": "tank-squad-trajectory", "version": 1,
		"commit": _shell("git", ["rev-parse", "--short", "HEAD"], "unknown"),
		"machine": _shell("hostname", [], "unknown"),
		"tick_rate": SimClock.TICK_RATE,
		"arena": Arena.active.get("name", null) if Arena.active != null else null,
		"seed": knobs.get("seed", null),
		"producer": producer,
		"command": " ".join(PackedStringArray(OS.get_cmdline_args()) + PackedStringArray(OS.get_cmdline_user_args())),
		# Lesson 44: every knob with the value it RESOLVED to, not the value that was passed.
		"knobs": knobs,
	}
	_file.store_line(JSON.stringify(header))
	print("TRAJECTORY_LOG %s producer=%s commit=%s" % [path, producer, header["commit"]])
	return true


static func _shell(command: String, arguments: Array, fallback: String) -> String:
	var out: Array = []
	if OS.execute(command, arguments, out, false) != 0 or out.is_empty():
		return fallback
	var text := String(out[0]).strip_edges()
	return text if text != "" else fallback


func _physics_process(_delta: float) -> void:
	if _file == null or game_match == null or not is_instance_valid(game_match):
		return
	if orders == null:
		orders = Orders.of(game_match)
	if elements == null:
		elements = Elements.of_match(game_match)
	var tick := game_match.tick
	for tank: Tank in game_match.tanks.get_children():
		if not tank.is_alive() or (team_filter >= 0 and tank.team != team_filter):
			continue
		_write(tank, tick)


func _write(tank: Tank, tick: int) -> void:
	var key := String(tank.name)
	var speed := tank.speed()
	# The goal and the verb travel together or not at all: a goal we cannot attribute to an order is a goal we
	# would measure progress against without knowing what was asked (FORMAT.md).
	var goal_x := "null"
	var goal_z := "null"
	var verb := "null"
	if orders != null:
		var goal: Variant = orders.goal_position(key)
		var current := orders.current(key)
		if goal != null and not current.is_empty():
			goal_x = "%.3f" % (goal as Vector3).x
			goal_z = "%.3f" % (goal as Vector3).z
			verb = JSON.stringify(String(current.get("verb", "?")))
	var element := "null"
	var slot_x := "null"
	var slot_z := "null"
	if elements != null:
		var found: Element = elements.of(key)
		if found != null:
			element = str(found.id)
			var slot: Variant = found.slots.get(key)
			if slot is Vector3:
				slot_x = "%.3f" % (slot as Vector3).x
				slot_z = "%.3f" % (slot as Vector3).z
	var reading := Movement.state(tank)
	var brain := game_match.brains.get_node_or_null(NodePath("Brain_" + key)) as TankBrain
	var move: Dictionary = brain.move_order if brain != null else {}
	var motion: Variant = tank.get("_motion")
	var creeping := motion is Dictionary and int((motion as Dictionary).get("creep_dir", 0)) != 0
	_buffer.append(
		'{"tick":%d,"unit":%s,"unit_id":%s,"team":%d,"x":%.3f,"z":%.3f,"heading_rad":%.5f,"speed_mps":%.4f,' \
		% [tick, JSON.stringify(key), JSON.stringify(String(tank.unit_id)), tank.team,
			tank.global_position.x, tank.global_position.z, _unwrapped(tank, key), speed]
		+ '"gear":%d,"goal_x":%s,"goal_z":%s,"order_verb":%s,"element":%s,"slot_x":%s,"slot_z":%s,' \
		% [signi(int(signf(speed))) if absf(speed) >= GEAR_SPEED else 0, goal_x, goal_z, verb, element, slot_x, slot_z]
		+ '"order_reverse":%s,"phase":%s,"creeping":%s}' \
		% ["true" if bool(move.get("reverse", false)) else "false",
			JSON.stringify(String(reading.get("phase", "none"))), "true" if creeping else "false"]
	)
	_lines += 1
	if _buffer.size() >= FLUSH_EVERY:
		_flush()


## The heading, ACCUMULATED and never re-wrapped. Round 8's 20.7 degree "overshoot" was a wrap bug
## (`_agents/streams/archive/round8/nav.md` item 8): a consumer that wants an angle wraps it itself, but a
## consumer that wants to know how far a hull turned cannot un-wrap what we threw away.
func _unwrapped(tank: Tank, key: String) -> float:
	var forward := -tank.global_basis.z
	var raw := atan2(-forward.x, -forward.z)
	if not _last_raw.has(key):
		_last_raw[key] = raw
		_heading[key] = raw
		return raw
	var total := float(_heading[key]) + wrapf(raw - float(_last_raw[key]), -PI, PI)
	_last_raw[key] = raw
	_heading[key] = total
	return total


func _flush() -> void:
	if _file == null or _buffer.is_empty():
		return
	_file.store_string("\n".join(_buffer) + "\n")
	_buffer = PackedStringArray()


func close() -> void:
	if _file == null:
		return
	_flush()
	_file.close()
	_file = null
	print("TRAJECTORY_LOG_DONE %d samples" % _lines)


func _exit_tree() -> void:
	close()
