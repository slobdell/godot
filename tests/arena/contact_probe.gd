extends SceneTree
## Yard (round 17, CP1's question from brains): do turned containers give a long hull's planned k-turn something to
## plant into? Boots the real match (main.tscn with the flags after `--`, headless, fixed fps) and reads every hull's
## `Movement.state()` on every physics tick -- the same reading tests/nav/test_nav_back_and_fill.gd counts -- and
## splits the wall-contact ticks by cause x driver, by whether the hull is long (>= 9 m: the Condemned tank, the War
## Rig) and by whether the thing touched is a container. One line per match:
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/arena/contact_probe.gd -- --match --arena=yard \
##       --green-faction=gangs --rust-faction=condemned --budget=5200 --time-limit=180 --seed=1 --probe-tag=turned
##
## CONTACT_PROBE {"arena", "tag", "seed", "ticks", "long_plant_kturn", "long_steer", "long_container", ...}

const LONG_M := 9.0

var _match: Node = null
var _counts := {}
var _ticks := 0
var _tag := ""
var _seed := ""
var _arena := ""
var _limit_ticks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var flags := LaunchFlags.from_environment()
	_tag = flags.text("probe-tag", "")
	_seed = flags.text("seed", "1")
	# A few ticks before the match's own time limit, which ends the run (no --elimination: the fight runs its length).
	_limit_ticks = int(float(flags.text("time-limit", "180")) * SimClock.TICK_RATE) - 10
	var main: Node = load("res://game/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(_tick)


func _tick() -> void:
	if _match == null:
		var found := _all(root, func(n: Node) -> bool: return n is Match)
		if found.is_empty():
			return
		_match = found[0]
		_arena = String(Arena.active.get("name", ""))
	_ticks += 1
	var tanks: Node = _match.get("tanks")
	if tanks != null:
		for tank: Node in tanks.get_children():
			if not tank is Tank or not is_instance_valid(tank):
				continue
			var reading := Movement.state(tank)
			if not bool(reading.get("wall_contact", false)):
				continue
			var long := float(Movement.hull_box((tank as Tank).unit_id)[2]) >= LONG_M
			var cause := String(reading.get("wall_contact_cause", "?"))
			var driver := String(reading.get("wall_contact_driver", "?"))
			var what := "container" if String(reading.get("wall_contact_collider", "")).begins_with("Container") else "other"
			_add("%s|%s|%s|%s" % ["long" if long else "short", cause, driver, what])
	if _ticks >= _limit_ticks:
		_report()


func _add(key: String) -> void:
	_counts[key] = int(_counts.get(key, 0)) + 1


func _sum(keep: Callable) -> int:
	var total := 0
	for key: String in _counts:
		if keep.call(key.split("|")):
			total += int(_counts[key])
	return total


## The match ends the run itself (a side eliminated, or its time limit): report on the way out, whichever comes first.
func _finalize() -> void:
	if not _reported:
		_report()


var _reported := false


func _report() -> void:
	_reported = true
	if physics_frame.is_connected(_tick):
		physics_frame.disconnect(_tick)
	var out := {"arena": _arena, "tag": _tag, "seed": _seed, "ticks": _ticks,
		"long_plant_kturn": _sum(func(k: PackedStringArray) -> bool: return k[0] == "long" and k[1] == "plant" and k[2] == "kturn"),
		"long_plant_kturn_container": _sum(func(k: PackedStringArray) -> bool: return k[0] == "long" and k[1] == "plant" and k[2] == "kturn" and k[3] == "container"),
		"long_kturn_any": _sum(func(k: PackedStringArray) -> bool: return k[0] == "long" and k[2] == "kturn"),
		"long_steer": _sum(func(k: PackedStringArray) -> bool: return k[0] == "long" and k[1] == "steer"),
		"long_container": _sum(func(k: PackedStringArray) -> bool: return k[0] == "long" and k[3] == "container"),
		"all": _sum(func(_k: PackedStringArray) -> bool: return true),
		"by_key": _counts}
	print("CONTACT_PROBE " + JSON.stringify(out))
	quit(0)  # harmless from _finalize


func _all(node: Node, keep: Callable) -> Array:
	var out: Array = []
	if keep.call(node):
		out.append(node)
	for child in node.get_children():
		out.append_array(_all(child, keep))
	return out
